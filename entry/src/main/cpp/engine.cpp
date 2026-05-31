#include "napi/native_api.h"
#include "json.hpp"
#include <symengine/expression.h>
#include <symengine/functions.h>
#include <symengine/printers.h> // SymEngine 的 LaTeX 排版打印机
#include <symengine/constants.h>
#include <string>
#include <sstream>

using json = nlohmann::json;
using SymEngine::Expression;

// 将前端的 MathJSON 转化为 SymEngine 符号树
Expression parseAST(const json& ast) {
    // 1. 处理数字
    if (ast.is_number()) {
        double val = ast.get<double>();
        if (std::floor(val) == val) {
            return Expression(static_cast<long>(val));
        }
        return Expression(val);
    }
    
    // 2. 处理变量和内置常数 (Pi, e)
    if (ast.is_string()) {
        std::string s = ast.get<std::string>();
        if (s == "Pi") return Expression(SymEngine::pi);                // 识别圆周率 π
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E); // 识别自然常数 e
        return Expression(SymEngine::symbol(s));            // 其他当做未知数 x, y
    }
    
    // 3. 处理函数和操作符
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        std::string op = ast[0].get<std::string>();

        // -- 基础运算 --
        if (op == "Add") {
            Expression sum(0);
            for (size_t i = 1; i < ast.size(); ++i) sum += parseAST(ast[i]);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -parseAST(ast[1]);
            return parseAST(ast[1]) - parseAST(ast[2]);
        }
        if (op == "Multiply") {
            Expression prod(1);
            for (size_t i = 1; i < ast.size(); ++i) prod *= parseAST(ast[i]);
            return prod;
        }
        // MathJSON 里普通除法叫 Divide，分数叫 Rational
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1]) / parseAST(ast[2]);
        }
        
        // -- 根号与绝对值 --
        if (op == "Sqrt") {
            return SymEngine::sqrt(parseAST(ast[1]));
        }
        if (op == "Root") { // 处理 n 次根号 (比如 ["Root", 8, 3] 就是 8 的 3 次方根)
            return SymEngine::pow(parseAST(ast[1]), Expression(1) / parseAST(ast[2]));
        }
        if (op == "Power") {
            return SymEngine::pow(parseAST(ast[1]), parseAST(ast[2]));
        }
        if (op == "Abs") { // 绝对值
            return SymEngine::abs(parseAST(ast[1]));
        }

        // -- 三角函数 --
        if (op == "Sin") return SymEngine::sin(parseAST(ast[1]));
        if (op == "Cos") return SymEngine::cos(parseAST(ast[1]));
        if (op == "Tan") return SymEngine::tan(parseAST(ast[1]));
        
        // -- 对数与指数 --
        if (op == "Ln") return SymEngine::log(parseAST(ast[1])); // 自然对数
        if (op == "Log") { // 有底数的对数 ["Log", x, base]
            if (ast.size() == 3) {
                return SymEngine::log(parseAST(ast[1]), parseAST(ast[2]));
            }
            return SymEngine::log(parseAST(ast[1]), Expression(10)); // 默认以10为底
        }
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}

// N-API 通信接口
static napi_value Calculate(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t str_len;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_len);
    std::string json_str(str_len, '\0');
    napi_get_value_string_utf8(env, args[0], &json_str[0], str_len + 1, &str_len);

    std::string result_msg;

    try {
        json ast = json::parse(json_str);
        if (ast.is_string()) {
            ast = json::parse(ast.get<std::string>()); 
        }
        
        Expression expr = parseAST(ast);
        
        // 🌟 魔法 1：让引擎尝试在代数层面展开多项式
        expr = Expression(SymEngine::expand(expr.get_basic()));
        
        // 🌟 魔法 2：不再输出丑陋的 ASCII，直接导出完美的 LaTeX 公式！
        result_msg = SymEngine::latex(*expr.get_basic());

    } catch (std::exception& e) {
        result_msg = "Error";
    }

    napi_value result;
    napi_create_string_utf8(env, result_msg.c_str(), NAPI_AUTO_LENGTH, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "calculate", nullptr, Calculate, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&demoModule);
}