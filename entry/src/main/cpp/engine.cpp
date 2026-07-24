/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file engine.cpp
 * @description AST 树解析与精度控制枢纽 (指挥官全局路由版)
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "napi/native_api.h"
#include "json.hpp"
#include "core/parser.h"
#include "core/giac_bridge.h"
#include "core/ErrorHandler.h"
#include "utils/FormatUtils.h"
#include <symengine/expression.h>
#include <symengine/printers.h>
#include <symengine/eval_double.h>
#include <string>

using json = nlohmann::json;
using SymEngine::Expression;

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
        
        bool isGlobalExact = (precision == -3 || precision == -4);
        bool autoDMS = false; 
        Expression expr = parseAST(ast, isRad, isGlobalExact, autoDMS);
        std::string expr_str = expr.get_basic()->__str__();
        
        // 全局接管需要调用 Giac 的计算
        bool isGlobalGiacOp = (expr_str.find("MAGICMAT") != std::string::npos || 
                           expr_str.find("tran(") != std::string::npos || expr_str.find("trn(") != std::string::npos ||
                           expr_str.find("det(") != std::string::npos || expr_str.find("trace(") != std::string::npos ||
                           expr_str.find("cross(") != std::string::npos || expr_str.find("dot(") != std::string::npos ||
                           expr_str.find("eigenvals(") != std::string::npos || expr_str.find("rank(") != std::string::npos ||
                           expr_str.find("rref(") != std::string::npos ||
                           expr_str.find("integrate(") != std::string::npos ||
                           expr_str.find("limit(") != std::string::npos ||
                           expr_str.find("sum(") != std::string::npos ||
                           expr_str.find("product(") != std::string::npos ||
                           expr_str.find("gcd(") != std::string::npos ||
                           expr_str.find("lcm(") != std::string::npos ||
                           expr_str.find("irem(") != std::string::npos);

        if (isGlobalGiacOp) {
            replaceAll(expr_str, "MAGICMAT", "");
            replaceAll(expr_str, "**", "^");
            
            // 判断是否为不定积分
            bool isIndefinite = (expr_str.find("MAGICINDEFintegrate") != std::string::npos);
            replaceAll(expr_str, "MAGICINDEFintegrate", "integrate");
            
            std::string giacCmd = "latex(simplify(" + expr_str + "))";
            std::string rawResult = evaluateWithGiac(giacCmd);
            
            if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                rawResult = rawResult.substr(1, rawResult.size() - 2);
            }
            
            // Romberg 数值积分全局降级兜底
            if (expr_str.find("integrate(") != std::string::npos && 
                (rawResult.find("undef") != std::string::npos || 
                 rawResult.find("\\int") != std::string::npos || 
                 rawResult.find("integrate") != std::string::npos ||
                 rawResult.find("?") != std::string::npos ||
                 rawResult.find("Ci") != std::string::npos || 
                 rawResult.find("Si") != std::string::npos || 
                 rawResult.find("igamma") != std::string::npos || 
                 rawResult.find("erf") != std::string::npos || 
                 rawResult.empty())) {
                
                std::string fallback_str = expr_str;
                // 全局将所有的 integrate( 替换为 romberg(，依然保留外层的结构
                replaceAll(fallback_str, "integrate(", "romberg(");
                std::string fallbackCmd = "latex(" + fallback_str + ")"; 
                rawResult = evaluateWithGiac(fallbackCmd);
                
                if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                    rawResult = rawResult.substr(1, rawResult.size() - 2);
                }
                
                // 清洗 Romberg 返回的误差区间 [min, max]
                if (rawResult.find(',') != std::string::npos && 
                   (rawResult.find('[') != std::string::npos || rawResult.find("left[") != std::string::npos)) {
                    std::string cleanStr = rawResult;
                    replaceAll(cleanStr, "\\left", ""); replaceAll(cleanStr, "\\right", "");
                    replaceAll(cleanStr, "[", ""); replaceAll(cleanStr, "]", "");
                    replaceAll(cleanStr, " ", "");
                    size_t commaPos = cleanStr.find(',');
                    if (commaPos != std::string::npos) {
                        try {
                            double num1 = std::stod(cleanStr.substr(0, commaPos));
                            double num2 = std::stod(cleanStr.substr(commaPos + 1));
                            double mid = (num1 + num2) / 2.0; 
                            rawResult = std::to_string(mid);
                        } catch (...) {}
                    }
                }
            }
            
            // 拼接积分常数
            if (isIndefinite) {
                rawResult += " + \\mathbf{C}";
            }
            
            result_msg = rawResult;
        } else {
            if (expr_str.find("MAGICBASETEN") == std::string::npos) {
                expr = Expression(SymEngine::expand(expr.get_basic()));
            }

            if (precision == -5 || (precision == -1 && autoDMS)) {
                try {
                    double float_val = SymEngine::eval_double(*expr.get_basic());
                    if (std::isinf(float_val) || std::isnan(float_val)) throw std::runtime_error("Inf Evaluated");
                    result_msg = formatDMS(float_val, isRad);
                } catch (...) { result_msg = SymEngine::latex(*expr.get_basic()); }
            }
            else if (precision == -1 || precision == -3) {
                if (SymEngine::is_a<SymEngine::Integer>(*expr.get_basic())) {
                    std::string rawStr = expr.get_basic()->__str__();
                    result_msg = (rawStr.length() > 15) ? formatLargeIntegerToScientific(rawStr) : SymEngine::latex(*expr.get_basic());
                } else {
                    result_msg = SymEngine::latex(*expr.get_basic());
                }
            }
            else if (precision == -4) {
                std::string s = expr.get_basic()->__str__();
                std::string fracStr = formatFraction(s);
                result_msg = fracStr.empty() ? SymEngine::latex(*expr.get_basic()) : fracStr;
            } 
            else {
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
                        if (std::isinf(float_val) || std::isnan(float_val)) throw std::runtime_error("Inf Evaluated");
                        result_msg = formatFloat(float_val, precision);
                    } catch (...) {
                        if (SymEngine::is_a<SymEngine::Integer>(*expr.get_basic())) {
                            std::string rawStr = expr.get_basic()->__str__();
                            result_msg = (rawStr.length() > 15) ? formatLargeIntegerToScientific(rawStr) : SymEngine::latex(*expr.get_basic());
                        } else {
                            result_msg = SymEngine::latex(*expr.get_basic());
                        }
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

    applyGlobalUIFormatting(result_msg);
    
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