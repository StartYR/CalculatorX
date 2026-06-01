#include "napi/native_api.h"
#include "json.hpp"
#include <symengine/expression.h>
#include <symengine/functions.h>
#include <symengine/printers.h>
#include <symengine/constants.h>
#include <string>
#include <sstream>

using json = nlohmann::json;
using SymEngine::Expression;

// 🌟 修改点 1：增加 bool isRad 参数，并在所有递归调用中传递
Expression parseAST(const json& ast, bool isRad) {
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
        if (s == "Pi") return Expression(SymEngine::pi);
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E);
        return Expression(SymEngine::symbol(s));
    }
    
    // 3. 处理函数和操作符
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        std::string op = ast[0].get<std::string>();

        // -- 基础运算 --
        if (op == "Add") {
            Expression sum(0);
            for (size_t i = 1; i < ast.size(); ++i) sum += parseAST(ast[i], isRad);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -parseAST(ast[1], isRad);
            return parseAST(ast[1], isRad) - parseAST(ast[2], isRad);
        }
        if (op == "Multiply") {
            Expression prod(1);
            for (size_t i = 1; i < ast.size(); ++i) prod *= parseAST(ast[i], isRad);
            return prod;
        }
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1], isRad) / parseAST(ast[2], isRad);
        }
        
        // -- 根号与绝对值 --
        if (op == "Sqrt") {
            return SymEngine::sqrt(parseAST(ast[1], isRad));
        }
        if (op == "Root") {
            return SymEngine::pow(parseAST(ast[1], isRad), Expression(1) / parseAST(ast[2], isRad));
        }
        if (op == "Power") {
            return SymEngine::pow(parseAST(ast[1], isRad), parseAST(ast[2], isRad));
        }
        if (op == "Abs") {
            return SymEngine::abs(parseAST(ast[1], isRad));
        }

        // -- 🌟 修改点 2：三角函数底层的弧度/角度拦截 --
        if (op == "Sin" || op == "Cos" || op == "Tan") {
            Expression arg = parseAST(ast[1], isRad);
            // 如果是角度制 (isRad == false)，则将参数乘以 (pi / 180)
            if (!isRad) {
                arg = arg * Expression(SymEngine::pi) / Expression(180);
            }
            if (op == "Sin") return SymEngine::sin(arg);
            if (op == "Cos") return SymEngine::cos(arg);
            if (op == "Tan") return SymEngine::tan(arg);
        }
        
        // -- 对数与指数 --
        if (op == "Ln") return SymEngine::log(parseAST(ast[1], isRad));
        if (op == "Log") {
            if (ast.size() == 3) {
                return SymEngine::log(parseAST(ast[1], isRad), parseAST(ast[2], isRad));
            }
            return SymEngine::log(parseAST(ast[1], isRad), Expression(10));
        }
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}

// N-API 通信接口
static napi_value Calculate(napi_env env, napi_callback_info info) {
    // 🌟 修改点 3：将接收的参数个数改为 2
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // 解析第一个参数：MathJSON 字符串
    size_t str_len;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_len);
    std::string json_str(str_len, '\0');
    napi_get_value_string_utf8(env, args[0], &json_str[0], str_len + 1, &str_len);

    // 🌟 解析第二个参数：isRad 布尔值 (默认给 false)
    bool isRad = false;
    if (argc >= 2) {
        napi_get_value_bool(env, args[1], &isRad);
    }

    std::string result_msg;

    try {
        json ast = json::parse(json_str);
        if (ast.is_string()) {
            ast = json::parse(ast.get<std::string>()); 
        }
        
        // 🌟 传入 isRad 状态
        Expression expr = parseAST(ast, isRad);
        
        expr = Expression(SymEngine::expand(expr.get_basic()));
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