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
#include <vector>
#include "utils/Logger.h"
#include "core/GraphingEngine.h"
#include <unordered_map>

// 定义全局静态缓存字典，记住编译好的 RPN 虚拟机
static std::unordered_map<std::string, GraphingEngine> graphing_cache;

using json = nlohmann::json;
using SymEngine::Expression;

static napi_value Calculate(napi_env env, napi_callback_info info) {
    size_t argc = 2; // 0：算式，1：配置
    napi_value args[2] = {nullptr};
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

    LOGI("[engine.cpp][输入通信] 成功接收原始 JSON 负载: %{public}s", json_str.c_str());
//    LOGI("[IPC_RX] Received raw JSON payload: %{public}s", json_str.c_str());
    
    // 获取对象属性
    bool isRad = false;
    int32_t precision = 13; 
    uint32_t mode = 0; // 默认 STANDARD
    
    // 新增：供函数图像 (mode=3) 专用的采样参数
    double xMin = -10.0;
    double xMax = 10.0;
    int32_t pointsCount = 1000;

    if (argc >= 2) {
        napi_valuetype valuetype1;
        if (napi_typeof(env, args[1], &valuetype1) == napi_ok && valuetype1 == napi_object) {
            napi_value prop;
            if (napi_get_named_property(env, args[1], "isRad", &prop) == napi_ok)
                napi_get_value_bool(env, prop, &isRad);
                
            if (napi_get_named_property(env, args[1], "precision", &prop) == napi_ok)
                napi_get_value_int32(env, prop, &precision);
                
            if (napi_get_named_property(env, args[1], "mode", &prop) == napi_ok)
                napi_get_value_uint32(env, prop, &mode);
                
            // 新增：提取边界与采样点数量
            if (napi_get_named_property(env, args[1], "xMin", &prop) == napi_ok)
                napi_get_value_double(env, prop, &xMin);
            if (napi_get_named_property(env, args[1], "xMax", &prop) == napi_ok)
                napi_get_value_double(env, prop, &xMax);
            if (napi_get_named_property(env, args[1], "pointsCount", &prop) == napi_ok)
                napi_get_value_int32(env, prop, &pointsCount);
        }
    }

    if (argc >= 2) {
        napi_valuetype valuetype1;
        if (napi_typeof(env, args[1], &valuetype1) == napi_ok && valuetype1 == napi_object) {
            napi_value prop;
            if (napi_get_named_property(env, args[1], "isRad", &prop) == napi_ok)
                napi_get_value_bool(env, prop, &isRad);
                
            if (napi_get_named_property(env, args[1], "precision", &prop) == napi_ok)
                napi_get_value_int32(env, prop, &precision);
                
            if (napi_get_named_property(env, args[1], "mode", &prop) == napi_ok)
                napi_get_value_uint32(env, prop, &mode);
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
        
        LOGI("[engine.cpp][AST构建] JSON 树结构解析完毕: %{public}s", ast.dump().c_str());
//        LOGI("[AST_Parser] Successfully built JSON tree: %{public}s", ast.dump().c_str());
        
        // 打包状态上下文实体
        CalcContext ctx;
        ctx.isRad = isRad;
        ctx.preferExact = (precision == -3 || precision == -4);
        ctx.hasDMS = false;
        ctx.mode = static_cast<CalcMode>(mode);
        
        
        // ---------------- 函数图像专属拦截路由 ----------------
        if (mode == 3) {

            LOGI("[GraphingDebug] [C++ 收货] 原始 json_str: %{public}s", json_str.c_str());

            // 将 isRad 状态拼接入 Key，防止用户切换弧度制时图象不更新
            std::string cache_key = json_str + (isRad ? "_rad" : "_deg");

            // 1. 初步解析前端传来的 GraphFunctionItem 复合 JSON
            nlohmann::json item = nlohmann::json::parse(json_str);
            int func_type = item.value("type", 0); // 默认为普通函数
            double tMin = item.value("tMin", -10.0);
            double tMax = item.value("tMax", 10.0);
            double yMin = item.value("yMin", -10.0);
            double yMax = item.value("yMax", 10.0);

            LOGI("[GraphingDebug] [C++ 解析] func_type: %{public}d, tMin: %f, tMax: %f", func_type, tMin, tMax);

            // 缓存穿透：只有第一次输入新公式时，才会执行昂贵的解析和建树
            if (graphing_cache.find(cache_key) == graphing_cache.end()) {
                GraphingEngine engine;

                // 提取主表达式 (ast)
                std::string ast_str = item.value("ast", "0");
                LOGI("[GraphingDebug] [C++ AST提取] ast_str: %{public}s", ast_str.c_str());
                SymEngine::Expression expr1(0);

                if (!ast_str.empty() && ast_str != "0") {
                    nlohmann::json ast_json = nlohmann::json::parse(ast_str);
                    expr1 = parseAST(ast_json, ctx);
                }
                LOGI("[GraphingDebug] [C++ 建树] expr1: %{public}s", expr1.get_basic()->__str__().c_str());
                // 提取伴生表达式 (ast2)，仅对需要的类型解析，节省性能
                SymEngine::Expression expr2(0);
                if (func_type == 1 || func_type == 4) { // 1=PARAMETRIC, 4=POINT
                    std::string ast2_str = item.value("ast2", "0");
                    if (!ast2_str.empty() && ast2_str != "0") {
                        nlohmann::json ast2_json = nlohmann::json::parse(ast2_str);
                        expr2 = parseAST(ast2_json, ctx);
                    }
                }
                LOGI("[GraphingDebug] [C++ 建树] expr2: %{public}s", expr2.get_basic()->__str__().c_str());

                // 双核编译！
                engine.compile(expr1, expr2);
                graphing_cache[cache_key] = engine; 
                LOGI("[engine.cpp] 缓存未命中，已编译并缓存新函数图像: %{public}s", cache_key.c_str());
            }

            // 2. 取出引擎，根据函数类型分发给不同的采样器
            std::vector<double> y_values;
            auto& engine = graphing_cache[cache_key];

            switch (func_type) {
                case 1: // 参数方程 PARAMETRIC
                    y_values = engine.generateParametric(tMin, tMax, pointsCount);
                    break;
                case 2: // 极坐标 POLAR
                    y_values = engine.generatePolar(tMin, tMax, pointsCount);
                    break;
                case 4: // 独立点 POINT
                    y_values = engine.generatePoint();
                    break;
                case 3: // 隐函数 IMPLICIT
                    y_values = engine.generateImplicit(xMin, xMax, yMin, yMax, 150);
                    break;
                case 0: // 普通函数 NORMAL
                default:
                    y_values = engine.generatePointsFast(xMin, xMax, pointsCount);
                    break;
            }

            // 3. N-API：在内存中创建 ArrayBuffer (保持原有极速传输逻辑)
            size_t byte_length = y_values.size() * sizeof(double);
            napi_value arraybuffer, typedarray;
            void* data_ptr = nullptr;
            napi_create_arraybuffer(env, byte_length, &data_ptr, &arraybuffer);
            memcpy(data_ptr, y_values.data(), byte_length);
            napi_create_typedarray(env, napi_float64_array, y_values.size(), arraybuffer, 0, &typedarray);

            return typedarray;
        }
        
        // ---------------- 方程求解专属拦截路由 (多元升维版) ----------------
        if (mode == 2) {
            std::vector<std::string> expr_strs;
            
            // 1. 拆解 List (方程组) 或 解析单一 Equal (一元方程)
            if (ast.is_array() && !ast.empty() && ast[0] == "List") {
                for (size_t i = 1; i < ast.size(); ++i) {
                    Expression e = parseAST(ast[i], ctx);
                    expr_strs.push_back(e.get_basic()->__str__());
                }
            } else {
                Expression e = parseAST(ast, ctx);
                expr_strs.push_back(e.get_basic()->__str__());
            }

            // 2. “六大金刚”未知数嗅探
            std::vector<std::string> target_vars;
            std::vector<std::string> candidates = {"x", "y", "z", "u", "v", "w"};
            std::string combined_exprs = "";
            for (const auto& s : expr_strs) combined_exprs += s + ",";

            for (const auto& var : candidates) {
                if (combined_exprs.find(var) != std::string::npos) {
                    target_vars.push_back(var);
                }
            }
            if (target_vars.empty()) target_vars.push_back("x"); // 兜底

            // 3. 组装 Giac 专属多元指令 csolve([eq1, eq2], [x, y])
            std::string eqs_str = "[";
            for (size_t i = 0; i < expr_strs.size(); ++i) {
                eqs_str += expr_strs[i];
                if (i < expr_strs.size() - 1) eqs_str += ",";
            }
            eqs_str += "]";

            std::string vars_str = "[";
            for (size_t i = 0; i < target_vars.size(); ++i) {
                vars_str += target_vars[i];
                if (i < target_vars.size() - 1) vars_str += ",";
            }
            vars_str += "]";

            std::string giacCmd = "latex(csolve(" + eqs_str + ", " + vars_str + "))";
            std::string rawResult = evaluateWithGiac(giacCmd);

            // 4. 交给 FormatUtils 进行降维美化
            result_msg = formatEquationResult(rawResult, target_vars);
            applyGlobalUIFormatting(result_msg);

            napi_value result;
            napi_create_string_utf8(env, result_msg.c_str(), NAPI_AUTO_LENGTH, &result);
            return result;
        }

        // 非方程模式，继续原有的标准解析流程
        Expression expr = parseAST(ast, ctx);
        
        // 提取底层的 DMS 标志位以便兼容后续流程
        bool autoDMS = ctx.hasDMS;
        std::string expr_str = expr.get_basic()->__str__();
        
        LOGI("[engine.cpp][引擎路由] 预处理表达式已生成: %{public}s", expr_str.c_str());
//        LOGI("[SymEngine] Expression ready for evaluation: %{public}s", expr_str.c_str());
        
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
                           expr_str.find("irem(") != std::string::npos ||
                           expr_str.find("simplify(") != std::string::npos ||
                           expr_str.find("diff(") != std::string::npos
        );

        if (isGlobalGiacOp) {
            replaceAll(expr_str, "MAGICMAT", "");
            
            // 判断是否为不定积分
            bool isIndefinite = (expr_str.find("MAGICINDEFintegrate") != std::string::npos);
            replaceAll(expr_str, "MAGICINDEFintegrate", "integrate");
            
            adaptSymEngineToGiac(expr_str);
            
            std::string giacCmd = "latex(factor(" + expr_str + "))";
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
                    std::string rawStr = expr.get_basic()->__str__();
                    
                    // 检测到包含根号 (sqrt) 触发 Giac 化简
                    if (rawStr.find("sqrt") != std::string::npos || rawStr.find("** (1/") != std::string::npos) {
                        adaptSymEngineToGiac(expr_str);
                        
                        std::string giacCmd = "latex(simplify(" + rawStr + "))";
                        std::string formattedResult = evaluateWithGiac(giacCmd);
                        
                        if (formattedResult.empty() || formattedResult.find("undef") != std::string::npos || formattedResult.find("Error") != std::string::npos) {
                            result_msg = SymEngine::latex(*expr.get_basic()); 
                        } else {
                            if (formattedResult.size() >= 2 && formattedResult.front() == '"' && formattedResult.back() == '"') {
                                formattedResult = formattedResult.substr(1, formattedResult.size() - 2);
                            }
                            result_msg = formattedResult;
                        }
                    } else {
                        // 没有根号的普通分数、符号计算，直接走极速原生输出！
                        result_msg = SymEngine::latex(*expr.get_basic());
                    }
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