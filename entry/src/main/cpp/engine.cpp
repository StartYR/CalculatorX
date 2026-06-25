/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file engine.cpp
 * @description AST 树解析与精度控制枢纽
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "napi/native_api.h"
#include "json.hpp"
#include "core/parser.h"
#include "core/formatter.h"
#include "core/string_utils.h"
#include "ErrorHandler.h"
#include <symengine/expression.h>
#include <symengine/printers.h>
#include <symengine/eval_double.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <cmath>

using json = nlohmann::json;
using SymEngine::Expression;

// 核心调度入口 N-API Calculate
static napi_value Calculate(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    napi_valuetype valuetype0;
    if (argc < 1 || napi_typeof(env, args[0], &valuetype0) != napi_ok || valuetype0 != napi_string) {
        napi_value err;
        napi_create_string_utf8(env, "Error", NAPI_AUTO_LENGTH, &err);
        return err;
    }

    size_t str_len;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_len);
    std::string json_str(str_len, '\0');
    napi_get_value_string_utf8(env, args[0], &json_str[0], str_len + 1, &str_len);

    bool isRad = false;
    if (argc >= 2) {
        napi_valuetype valuetype1;
        if (napi_typeof(env, args[1], &valuetype1) == napi_ok && valuetype1 == napi_boolean) {
            napi_get_value_bool(env, args[1], &isRad);
        }
    }

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
            std::string inner_str = ast.get<std::string>();
            if (!inner_str.empty() && (inner_str[0] == '[' || inner_str[0] == '{')) {
                ast = json::parse(inner_str);
            }
        }
        
        // 常规极速计算
        bool isGlobalExact = (precision == -3 || precision == -4);
        bool autoDMS = false; 
        Expression expr = parseAST(ast, isRad, isGlobalExact, autoDMS);
        
        std::string expr_str = expr.get_basic()->__str__();
        if (expr_str.find("MAGICBASETEN") == std::string::npos) {
            expr = Expression(SymEngine::expand(expr.get_basic()));
        }

        if (precision == -5 || (precision == -1 && autoDMS)) {
            try {
                double float_val = SymEngine::eval_double(*expr.get_basic());
                if (std::isinf(float_val) || std::isnan(float_val)) throw std::runtime_error("Inf Evaluated");
                
                double deg_val = float_val;
                if (isRad) {
                    deg_val = float_val * 180.0 / 3.14159265358979323846;
                }
                
                std::string sign = (deg_val < 0) ? "-" : "";
                deg_val = std::abs(deg_val);
                
                long long d = static_cast<long long>(std::floor(deg_val));
                double rem_m = (deg_val - d) * 60.0;
                long long m = static_cast<long long>(std::floor(rem_m));
                double s = (rem_m - m) * 60.0;
                
                if (s >= 59.99995) {
                    s = 0.0;
                    m += 1;
                }
                if (m >= 60) {
                    m = 0;
                    d += 1;
                }
                
                std::ostringstream s_oss;
                s_oss << std::fixed << std::setprecision(4) << s;
                std::string s_str = s_oss.str();
                s_str.erase(s_str.find_last_not_of('0') + 1, std::string::npos);
                if (!s_str.empty() && s_str.back() == '.') s_str.pop_back();
                
                result_msg = sign + std::to_string(d) + "^{\\circ}" + 
                             std::to_string(m) + "^{\\prime}" + 
                             s_str + "^{\\prime\\prime}";
                             
            } catch (...) {
                result_msg = SymEngine::latex(*expr.get_basic());
            }
        }
        else if (precision == -1 || precision == -3) {
            if (SymEngine::is_a<SymEngine::Integer>(*expr.get_basic())) {
                std::string rawStr = expr.get_basic()->__str__();
                if (rawStr.length() > 15) {
                    result_msg = formatLargeIntegerToScientific(rawStr);
                } else {
                    result_msg = SymEngine::latex(*expr.get_basic());
                }
            } else {
                result_msg = SymEngine::latex(*expr.get_basic());
            }
            
        } else if (precision == -4) {
            std::string s = expr.get_basic()->__str__();
            bool is_simple_frac = true;
            for (char c : s) {
                if (!isdigit(c) && c != '/' && c != '-') { is_simple_frac = false; break; }
            }
            size_t slash = s.find('/');
            if (is_simple_frac && slash != std::string::npos) {
                try {
                    long long num = std::stoll(s.substr(0, slash));
                    long long den = std::stoll(s.substr(slash + 1));
                    long long integer_part = num / den;           
                    long long remainder = std::abs(num % den);    
                    
                    if (integer_part != 0 && remainder != 0) {
                        std::string sign = (num < 0) ? "-" : "";
                        result_msg = sign + std::to_string(std::abs(integer_part)) + "\\frac{" + std::to_string(remainder) + "}{" + std::to_string(den) + "}";
                    } else if (remainder == 0) {
                        result_msg = std::to_string(integer_part);
                    } else {
                        if (num < 0) result_msg = "-\\frac{" + std::to_string(std::abs(num)) + "}{" + std::to_string(den) + "}";
                        else result_msg = "\\frac{" + std::to_string(num) + "}{" + std::to_string(den) + "}";
                    }
                } catch (...) { result_msg = SymEngine::latex(*expr.get_basic()); }
            } else { result_msg = SymEngine::latex(*expr.get_basic()); }
            
        } else {
            bool handled = false;
            if (SymEngine::is_a<SymEngine::Integer>(*expr.get_basic())) {
                std::string rawStr = expr.get_basic()->__str__();
                if (rawStr.length() > 15) {
                    result_msg = formatLargeIntegerToScientific(rawStr);
                    handled = true;
                }
            }
            
            if (!handled) {
                try {
                    double float_val = SymEngine::eval_double(*expr.get_basic());
                    if (std::isinf(float_val) || std::isnan(float_val)) {
                        throw std::runtime_error("Inf Evaluated");
                    }
                    
                    if (std::abs(float_val) >= 1e15 || (std::abs(float_val) > 0 && std::abs(float_val) < 1e-5)) {
                        std::ostringstream oss;
                        oss << std::scientific << std::setprecision(10) << float_val;
                        std::string s = oss.str();
                        size_t ePos = s.find('e');
                        if (ePos == std::string::npos) ePos = s.find('E');
                        if (ePos != std::string::npos) {
                            std::string a = s.substr(0, ePos);
                            int b = std::stoi(s.substr(ePos + 1));
                            a.erase(a.find_last_not_of('0') + 1, std::string::npos);
                            if (!a.empty() && a.back() == '.') a.pop_back();
                            result_msg = a + "\\times 10^{" + std::to_string(b) + "}";
                        } else {
                            result_msg = s;
                        }
                    } else {
                        std::ostringstream oss;
                        if (precision == -2) {
                            oss << std::fixed << std::setprecision(12) << float_val;
                            std::string str = oss.str();
                            str.erase(str.find_last_not_of('0') + 1, std::string::npos);
                            if (!str.empty() && str.back() == '.') str.pop_back();
                            result_msg = str;
                        } else {
                            oss << std::fixed << std::setprecision(precision) << float_val;
                            result_msg = oss.str();
                        }
                    }
                } catch (...) {
                    if (SymEngine::is_a<SymEngine::Integer>(*expr.get_basic())) {
                        std::string rawStr = expr.get_basic()->__str__();
                        if (rawStr.length() > 15) result_msg = formatLargeIntegerToScientific(rawStr);
                        else result_msg = SymEngine::latex(*expr.get_basic());
                    } else {
                        result_msg = SymEngine::latex(*expr.get_basic());
                    }
                }
            }
        }
    } catch (const CalcException& e) {
        result_msg = e.getFrontEndMessage();
    } catch (const std::exception& e) {
        result_msg = "Error:Timeout"; 
    } catch (...) {
        result_msg = "Error:Unknown";
    }

    size_t pos = 0;
    while ((pos = result_msg.find("MAGICBASETEN", pos)) != std::string::npos) {
        int check_pos = pos - 1;
        while (check_pos >= 0 && result_msg[check_pos] == ' ') check_pos--;
        if (check_pos >= 0 && (isdigit(result_msg[check_pos]) || result_msg[check_pos] == '.')) {
            result_msg.replace(pos, 12, "\\times 10");
            pos += 10; 
        } else {
            result_msg.replace(pos, 12, "10");
            pos += 2; 
        }
    }
    replaceAll(result_msg, " \\times 10", "\\times 10");
    
    // SymEngine 的 latex() 打印器会自动给变量里的下划线加上转义反斜杠 (\_)
    replaceAll(result_msg, "MAGICGIACRESULT", "");
    // Giac 返回格式的 UI 美化，统一成前端样式
    replaceAll(result_msg, "infinity", "\\infty");
    replaceAll(result_msg, "undef", "\\text{undefined}");
    // 将 \log 翻译为 \ln
    replaceAll(result_msg, "\\log", "\\ln");
    
    replaceAll(result_msg, "j", "i");
    
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