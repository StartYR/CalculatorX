#include "napi/native_api.h"
#include "json.hpp"
#include <symengine/expression.h>
#include <symengine/functions.h>
#include <symengine/printers.h>
#include <symengine/constants.h>
#include <symengine/eval_double.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <cmath>

using json = nlohmann::json;
using SymEngine::Expression;

// AST 树递归解析
Expression parseAST(const json& ast, bool isRad, bool preferExact = false) {
    if (ast.is_number()) {
        double val = ast.get<double>();
        if (std::floor(val) == val) return Expression(static_cast<long>(val));
        
        // 🌟 只有当上下文明确要求精确时（比如在分数、三角函数里），才把小数转分数！
        if (preferExact) {
            std::string s = ast.dump(); 
            size_t dot = s.find('.');
            if (dot != std::string::npos && s.find('e') == std::string::npos && s.find('E') == std::string::npos) {
                int decimals = s.length() - dot - 1;
                if (decimals > 0 && decimals <= 9) { 
                    long long num = 0, den = 1;
                    bool isNeg = (s[0] == '-');
                    size_t start = isNeg ? 1 : 0;
                    for (size_t i = start; i < s.length(); ++i) {
                        if (s[i] == '.') continue;
                        num = num * 10 + (s[i] - '0');
                    }
                    for (int i = 0; i < decimals; ++i) den *= 10;
                    if (isNeg) num = -num;
                    return Expression(num) / Expression(den);
                }
            }
        }
        // 普通情况（如 1.2 * 1），老老实实做浮点数
        return Expression(val);
    }
    
    if (ast.is_string()) {
        std::string s = ast.get<std::string>();
        if (s == "Pi") return Expression(SymEngine::pi);
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E);
        return Expression(SymEngine::symbol(s));
    }
    
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        std::string op = ast[0].get<std::string>();

        // ==================== 不将小数转换为分数 ====================
        if (op == "Add") {
            Expression sum(0);
            for (size_t i = 1; i < ast.size(); ++i) sum += parseAST(ast[i], isRad, preferExact);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -parseAST(ast[1], isRad, preferExact);
            return parseAST(ast[1], isRad, preferExact) - parseAST(ast[2], isRad, preferExact);
        }
        if (op == "Multiply") {
            Expression prod(1);
            for (size_t i = 1; i < ast.size(); ++i) prod *= parseAST(ast[i], isRad, preferExact);
            return prod;
        }
        // 🌟 核心修复：让 Divide（包括 ÷ 和分数线）顺其自然！
        // 整数除以整数(12/36)是精确分数，包含小数(1.2/3.6)就是浮点数！
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1], isRad, preferExact) / parseAST(ast[2], isRad, preferExact);
        }

        // ==================== 强制精确：为了消除圆周率等无理数误差，强制将小数转换为分数 ====================
        if (op == "Sqrt") return SymEngine::sqrt(parseAST(ast[1], isRad, true));
        if (op == "Root") return SymEngine::pow(parseAST(ast[1], isRad, true), Expression(1) / parseAST(ast[2], isRad, true));
        if (op == "Power") return SymEngine::pow(parseAST(ast[1], isRad, true), parseAST(ast[2], isRad, true));
        if (op == "Abs") return SymEngine::abs(parseAST(ast[1], isRad, true));
        
        if (op == "Factorial") {
            if (ast.size() == 2) return Expression(SymEngine::gamma((parseAST(ast[1], isRad, true) + Expression(1)).get_basic()));
            return Expression(SymEngine::symbol("Error"));
        }
        
        if (op == "nCr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true);
                Expression r = parseAST(ast[2], isRad, true);
                Expression num(SymEngine::gamma((n + Expression(1)).get_basic()));
                Expression den1(SymEngine::gamma((r + Expression(1)).get_basic()));
                Expression den2(SymEngine::gamma((n - r + Expression(1)).get_basic()));
                return num / (den1 * den2);
            }
            return Expression(SymEngine::symbol("Error"));
        }

        if (op == "nPr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true);
                Expression r = parseAST(ast[2], isRad, true);
                Expression num(SymEngine::gamma((n + Expression(1)).get_basic()));
                Expression den(SymEngine::gamma((n - r + Expression(1)).get_basic()));
                return num / den;
            }
            return Expression(SymEngine::symbol("Error"));
        }

        if (op == "Sin" || op == "Cos" || op == "Tan") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseAST(ast[1], isRad, true); 
            if (!isRad) arg = arg * Expression(SymEngine::pi) / Expression(180);
            
            if (op == "Sin") return SymEngine::sin(arg);
            if (op == "Cos") return SymEngine::cos(arg);
            if (op == "Tan") return SymEngine::tan(arg);
        }

        if (op == "Arcsin" || op == "Arccos" || op == "Arctan") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseAST(ast[1], isRad, true); 
            Expression res;
            
            if (op == "Arcsin") res = SymEngine::asin(arg);
            else if (op == "Arccos") res = SymEngine::acos(arg);
            else if (op == "Arctan") res = SymEngine::atan(arg);
            
            if (!isRad) res = res * Expression(180) / Expression(SymEngine::pi);
            return res;
        }
        
        if (op == "Ln") return SymEngine::log(parseAST(ast[1], isRad, true));
        if (op == "Log") {
            if (ast.size() == 3) return SymEngine::log(parseAST(ast[1], isRad, true), parseAST(ast[2], isRad, true));
            return SymEngine::log(parseAST(ast[1], isRad, true), Expression(10));
        }
        
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}

// N-API 通信接口 (带有极限防崩溃机制与精度控制)
static napi_value Calculate(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // 防御：检查第一个参数是否真的传了，且必须是 String 类型
    napi_valuetype valuetype0;
    if (argc < 1 || napi_typeof(env, args[0], &valuetype0) != napi_ok || valuetype0 != napi_string) {
        napi_value err;
        napi_create_string_utf8(env, "Error", NAPI_AUTO_LENGTH, &err);
        return err;
    }

    // 防御：安全提取 JSON 字符串
    size_t str_len;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_len);
    std::string json_str(str_len, '\0');
    napi_get_value_string_utf8(env, args[0], &json_str[0], str_len + 1, &str_len);

    // 防御：安全提取布尔值 (角度/弧度，默认 false)
    bool isRad = false;
    if (argc >= 2) {
        napi_valuetype valuetype1;
        if (napi_typeof(env, args[1], &valuetype1) == napi_ok && valuetype1 == napi_boolean) {
            napi_get_value_bool(env, args[1], &isRad);
        }
    }

    // 防御：安全提取精度参数 (默认 13 档，即自动化简)
    int32_t precision = 13; 
    if (argc >= 3) {
        napi_valuetype valuetype2;
        if (napi_typeof(env, args[2], &valuetype2) == napi_ok && valuetype2 == napi_number) {
            napi_get_value_int32(env, args[2], &precision);
        }
    }

    std::string result_msg;
    try {
        json ast = json::parse(json_str);
        if (ast.is_string()) {
            ast = json::parse(ast.get<std::string>()); 
        }
        
        Expression expr = parseAST(ast, isRad);
        expr = Expression(SymEngine::expand(expr.get_basic()));

        // ==================== 精度控制逻辑 ====================
        if (precision == -1) {
            // -1 档：自动模式，直接输出精确的 LaTeX 符号 (例如 \frac{1}{2})
            result_msg = SymEngine::latex(*expr.get_basic());
        } else {
            // 小数模式
            try {
                // 尝试将代数式转化为 double 浮点数
                double float_val = SymEngine::eval_double(*expr.get_basic());
                
                std::ostringstream oss;
                if (precision == -2) {
                    // -2 档：小数精度“自动”
                    // 策略：使用极高精度输出，然后暴力抹除字符串末尾多余的 '0' 和可能遗留的 '.'
                    oss << std::fixed << std::setprecision(12) << float_val;
                    std::string str = oss.str();
                    
                    // 核心去零算法
                    str.erase(str.find_last_not_of('0') + 1, std::string::npos);
                    if (!str.empty() && str.back() == '.') {
                        str.pop_back();
                    }
                    result_msg = str;
                } else {
                    // 0~12 档：强制固定小数位数，位数不够标准库会自动补 0
                    oss << std::fixed << std::setprecision(precision) << float_val;
                    result_msg = oss.str();
                }
            } catch (...) {
                // 退回机制：如果包含未知变量无法转为浮点数，退回到符号输出
                result_msg = SymEngine::latex(*expr.get_basic());
            }
        }
        // ==========================================================

    } catch (...) {
        // 捕获其余所有的 C++ 异常，不让崩溃溢出到 ArkTS 应用层
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