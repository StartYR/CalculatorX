/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file parser.cpp
 * @description MathJSON AST 递归下降解析器，将 JSON AST 转换为 SymEngine 表达式
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

#include "parser.h"
#include "MatrixParser.h"
#include "../utils/FormatUtils.h"
#include "../utils/FastMath.h"
#include "ErrorHandler.h"
#include <symengine/functions.h>
#include <symengine/constants.h>
#include <symengine/eval_double.h>
#include <cmath>
#include <string>

using json = nlohmann::json;
using SymEngine::Expression;

// 矩阵与数组转 Giac 字符串的核心解析器
static std::string parseListToGiacString(const json& listNode, bool isRad, bool preferExact, bool& hasDMS) {
    if (!listNode.is_array() || listNode.empty() || listNode[0] != "List") return "";
    
    std::string result = "[";
    for (size_t i = 1; i < listNode.size(); ++i) {
        if (i > 1) result += ","; // 元素之间用逗号隔开
        
        if (listNode[i].is_array() && listNode[i][0] == "List") {
            // 遇到嵌套数组（比如矩阵的行），递归深扒
            result += parseListToGiacString(listNode[i], isRad, preferExact, hasDMS);
        } else {
            // 遇到具体的数字或公式（叶子节点），交回给 parseAST 解析，然后转成字符串
            Expression elementExpr = parseAST(listNode[i], isRad, preferExact, hasDMS);
            std::string elemStr = elementExpr.get_basic()->__str__();
            replaceAll(elemStr, "**", "^"); // 符号适配
            replaceAll(elemStr, "I", "i");
            result += elemStr;
        }
    }
    result += "]";
    return result;
}


Expression parseAST(const json& ast, bool isRad, bool preferExact, bool& hasDMS) {
    if (ast.is_number()) {
        double val = ast.get<double>();
        if (std::floor(val) == val) return Expression(static_cast<long>(val));
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
        return Expression(val);
    }
    
    if (ast.is_string()) {
        std::string s = ast.get<std::string>();
        if (s.find("I_upright_") == 0) {
            try {
                int n = std::stoi(s.substr(10));
                return Expression(SymEngine::symbol("MAGICMATidn(" + std::to_string(n) + ")"));
            } catch (...) {}
        }
        if (s == "Pi") return Expression(SymEngine::pi);
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E);
        if (s == "NaN") throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Frontend folded to NaN");
        if (s == "PositiveInfinity" || s == "Infinity" || s == "infty" || s == "\\infty") return Expression(SymEngine::symbol("inf"));
        if (s == "NegativeInfinity" || s == "-infty" || s == "-\\infty") return -Expression(SymEngine::symbol("inf"));
        return Expression(SymEngine::symbol(s));
    }
    
    if (ast.is_object() && ast.contains("num")) {
        std::string s = ast["num"].get<std::string>();
        try {
            size_t ePos = s.find('e');
            if (ePos == std::string::npos) ePos = s.find('E');
            if (ePos != std::string::npos) {
                std::string baseStr = s.substr(0, ePos);
                std::string expStr = s.substr(ePos + 1);
                long long expVal = std::stoll(expStr);
                if (std::abs(expVal) > 10000) {
                    double baseVal = std::stod(baseStr);
                    double magnitude = expVal + (baseVal == 0 ? 0 : std::log10(std::abs(baseVal)));
                    FastMath::checkOverflow(magnitude);
                    SymEngine::Expression node = FastMath::buildBigScientificNode(std::abs(baseVal), expVal);
                    return baseVal < 0 ? -node : node; 
                }
                size_t dotPos = baseStr.find('.');
                if (dotPos != std::string::npos) {
                    int decimals = baseStr.length() - dotPos - 1;
                    baseStr.erase(dotPos, 1); 
                    long long baseVal = std::stoll(baseStr);
                    expVal -= decimals;       
                    return Expression(baseVal) * SymEngine::pow(Expression(10), Expression(expVal));
                } else {
                    long long baseVal = std::stoll(baseStr);
                    return Expression(baseVal) * SymEngine::pow(Expression(10), Expression(expVal));
                }
            }
            if (s.find('.') == std::string::npos) {
                try { return Expression(static_cast<long long>(std::stoll(s))); } 
                catch (...) { return Expression(std::stod(s)); }
            }
            return Expression(std::stod(s));
        } catch (const std::out_of_range&) { throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Astronomical explosion intercepted");
        } catch (...) { throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid num object format"); }
    }
    
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        
        // 检测是否为矩阵
        if (MatrixParser::isMatrixExpression(ast)) {
            return MatrixParser::handle(ast, isRad, preferExact, hasDMS);
        }
        
        std::string op = ast[0].get<std::string>();

        if (op == "dms" || op == "Dms") {
            if (ast.size() == 4) {
                bool dummy = false; 
                Expression d = parseAST(ast[1], isRad, true, dummy);
                Expression m = parseAST(ast[2], isRad, true, dummy);
                Expression s = parseAST(ast[3], isRad, true, dummy);
                try {
                    Expression total_deg = d + m / Expression(60) + s / Expression(3600);
                    hasDMS = true;
                    if (isRad) {
                        return total_deg * Expression(SymEngine::pi) / Expression(180);
                    } else {
                        return total_deg;
                    }
                } catch (...) {
                    throw CalcException(CalcErrorCode::DMS_FORMAT_ERROR, "DMS Calculation Failed");
                }
            }
            throw CalcException(CalcErrorCode::DMS_FORMAT_ERROR, "Invalid DMS Length");
        }

        if (op == "Delimiter") {
            if (ast.size() > 1) return parseAST(ast[1], isRad, preferExact, hasDMS);
            return Expression(0);
        }
        
        
        // 矩阵
        auto getGiacStr = [&](const json& node) {
            bool dummy = false;
            std::string s = parseAST(node, isRad, preferExact, dummy).get_basic()->__str__();
            replaceAll(s, "MAGICMAT", ""); return s;
        };
        // 遇到矩阵，不再立刻计算，而是变成一个带有 MAGICMAT 标记的特殊符号
        if (op == "Matrix" && ast.size() >= 2) {
            std::string giacMatrixStr = parseListToGiacString(ast[1], isRad, preferExact, hasDMS);
            return Expression(SymEngine::symbol("MAGICMAT" + giacMatrixStr));
        }

        // 拦截 Tuple：解决隐式乘法和特殊算子
        if (op == "Tuple") {
            // 隐式乘法 (Matrix1 Matrix2) -> 强制转为星号相乘并保序
            if (ast.size() == 3) {
                return parseAST(ast[1], isRad, preferExact, hasDMS) * parseAST(ast[2], isRad, preferExact, hasDMS);
            }
        }
        
        
        // 复数 (Complex)
        if (op == "Complex") {
            if (ast.size() == 3) {
                bool dummy = false;
                Expression real_part = parseAST(ast[1], isRad, true, dummy);
                Expression imag_part = parseAST(ast[2], isRad, true, dummy);
                // 实部 + 虚部 * i
                return real_part + imag_part * Expression(SymEngine::I);
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Complex format");
        }
        
        if (op == "Add") {
            Expression sum(0);
            for (size_t i = 1; i < ast.size(); ++i) sum += parseAST(ast[i], isRad, preferExact, hasDMS);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -parseAST(ast[1], isRad, preferExact, hasDMS);
            return parseAST(ast[1], isRad, preferExact, hasDMS) - parseAST(ast[2], isRad, preferExact, hasDMS);
        }
        
        if (op == "Multiply") {
            Expression prod(1);
            for (size_t i = 1; i < ast.size(); ++i) prod *= parseAST(ast[i], isRad, preferExact, hasDMS);
            return prod;
        }
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1], isRad, preferExact, hasDMS) / parseAST(ast[2], isRad, preferExact, hasDMS);
        }

        if (op == "Sqrt") return SymEngine::sqrt(parseAST(ast[1], isRad, true, hasDMS));
        if (op == "Root") return SymEngine::pow(parseAST(ast[1], isRad, true, hasDMS), Expression(1) / parseAST(ast[2], isRad, true, hasDMS));
        if (op == "Abs") return SymEngine::abs(parseAST(ast[1], isRad, true, hasDMS));
        if (op == "Power") {
            Expression base = parseAST(ast[1], isRad, true, hasDMS);
            Expression exp = parseAST(ast[2], isRad, true, hasDMS);
            try {
                if (SymEngine::is_a<SymEngine::Integer>(*base.get_basic()) && 
                    SymEngine::is_a<SymEngine::Integer>(*exp.get_basic())) {
                    double b = SymEngine::eval_double(base);
                    double e = SymEngine::eval_double(exp);
                    if (b > 0) {
                        double magnitude = e * std::log10(b);
                        if (std::isinf(magnitude) || std::abs(magnitude) > 9e18) throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Exceeds 64-bit limits");
                        if (std::abs(magnitude) > 10000) return FastMath::buildBigScientificNode(magnitude);
                    }
                }
            } catch (const CalcException& e) { throw; 
            } catch (const std::exception& e) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR, "Calculation payload exceeded engine limits");
            } catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR, "Unknown catastrophic evaluation error"); }
            return SymEngine::pow(base, exp);
        }
        
        // === 代数与数论：最大公约数、最小公倍数、求余数 ===
        if (op == "GCD" || op == "LCM" || op == "Lcm" || op == "lcm" || op == "Mod" || op == "Modulo") {
            if (ast.size() == 3) {
                bool dummy = false;
                Expression a = parseAST(ast[1], isRad, true, dummy);
                Expression b = parseAST(ast[2], isRad, true, dummy);
                
                std::string aStr = a.get_basic()->__str__();
                std::string bStr = b.get_basic()->__str__();
                
                replaceAll(aStr, "**", "^");
                replaceAll(bStr, "**", "^");
                
                std::string giacFunc;
                if (op == "GCD") giacFunc = "gcd";
                else if (op == "LCM" || op == "Lcm" || op == "lcm") giacFunc = "lcm";
                else giacFunc = "irem"; // Giac 的多态求余指令，支持数字和多项式

                // 【重构战役一】：只做翻译，不当场计算。组装为符号节点交由顶层处理。
                return Expression(SymEngine::symbol(giacFunc + "(" + aStr + ", " + bStr + ")"));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid format for GCD/LCM/Mod");
        }
        if (op == "Percent") {
             return parseAST(ast[1], isRad, true, hasDMS) / Expression(100);
        }
        if (op == "Factorial") {
            if (ast.size() == 2) {
                Expression arg = parseAST(ast[1], isRad, true, hasDMS);
                try {
                    double val = SymEngine::eval_double(arg);
                    if (val < 0 && std::floor(val) == val) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Negative Factorial");
                    if (val > 5000 && std::floor(val) == val) {
                        double magnitude = FastMath::getFactorialMagnitude(val);
                        FastMath::checkOverflow(magnitude);
                        return FastMath::buildBigScientificNode(magnitude);
                    }
                } catch (const CalcException&) { throw; } catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                return Expression(SymEngine::gamma((arg + Expression(1)).get_basic()));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Factorial length.");
        }
        if (op == "nCr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true, hasDMS);
                Expression r = parseAST(ast[2], isRad, true, hasDMS);
                try {
                    double n_val = SymEngine::eval_double(n), r_val = SymEngine::eval_double(r);
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid args");
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(r_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        if (mag > 15.0) return FastMath::buildBigScientificNode(mag);
                    }
                } catch (const CalcException&) { throw; } catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                return Expression(SymEngine::gamma((n + Expression(1)).get_basic())) / (Expression(SymEngine::gamma((r + Expression(1)).get_basic())) * Expression(SymEngine::gamma((n - r + Expression(1)).get_basic())));
            }
        }
        if (op == "nPr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true, hasDMS);
                Expression r = parseAST(ast[2], isRad, true, hasDMS);
                try {
                    double n_val = SymEngine::eval_double(n), r_val = SymEngine::eval_double(r);
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid args");
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        if (mag > 15.0) return FastMath::buildBigScientificNode(mag);
                    }
                } catch (const CalcException&) { throw; } catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                return Expression(SymEngine::gamma((n + Expression(1)).get_basic())) / Expression(SymEngine::gamma((n - r + Expression(1)).get_basic()));
            }
        }

        if (op == "Sin" || op == "Cos" || op == "Tan") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            bool childDMS = false; 
            Expression arg = parseAST(ast[1], isRad, true, childDMS); 
            if (!isRad) arg = arg * Expression(SymEngine::pi) / Expression(180);
            if (op == "Sin") return SymEngine::sin(arg);
            if (op == "Cos") return SymEngine::cos(arg);
            if (op == "Tan") return SymEngine::tan(arg);
        }

        if (op == "Arcsin" || op == "Arccos" || op == "Arctan") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            bool childDMS = false; 
            Expression arg = parseAST(ast[1], isRad, true, childDMS); 
            Expression res;
            if (op == "Arcsin") res = SymEngine::asin(arg);
            else if (op == "Arccos") res = SymEngine::acos(arg);
            else if (op == "Arctan") res = SymEngine::atan(arg);
            
            if (!isRad) res = res * Expression(180) / Expression(SymEngine::pi);
            hasDMS = true; 
            return res;
        }
        
        if (op == "Ln") return SymEngine::log(parseAST(ast[1], isRad, true, hasDMS));
        if (op == "Log") {
            if (ast.size() == 3) return SymEngine::log(parseAST(ast[1], isRad, true, hasDMS), parseAST(ast[2], isRad, true, hasDMS));
            return SymEngine::log(parseAST(ast[1], isRad, true, hasDMS), Expression(10));
        }
        if (op == "Log10" || op == "Lg") {
            Expression num(SymEngine::log(parseAST(ast[1], isRad, true, hasDMS).get_basic()));
            Expression den(SymEngine::log(Expression(10).get_basic()));
            return num / den;
        }
        
        if (op == "Sum" || op == "Product") {
            if (ast.size() == 3 && ast[2].is_array() && ast[2].size() >= 4 && ast[2][0] == "Tuple") {
                std::string var_name = "x";
                if (ast[2][1].is_string()) var_name = ast[2][1].get<std::string>();
                
                // 解析表达式与上下限
                Expression body = parseAST(ast[1], isRad, true, hasDMS);
                Expression lower_expr = parseAST(ast[2][2], isRad, true, hasDMS);
                Expression upper_expr = parseAST(ast[2][3], isRad, true, hasDMS);
                
                // 转换为字符串，供 Giac 识别
                std::string exprStr = body.get_basic()->__str__();
                std::string lowerStr = lower_expr.get_basic()->__str__();
                std::string upperStr = upper_expr.get_basic()->__str__();
                
                adaptSymEngineToGiac(exprStr);
                adaptSymEngineToGiac(lowerStr);
                adaptSymEngineToGiac(upperStr);
                
                // 根据操作符选择对应的 Giac 函数
                std::string giacFuncName = (op == "Sum") ? "sum" : "product";
                
                // 【重构战役一】：直接装箱返回，绕过局部计算
                return Expression(SymEngine::symbol(giacFuncName + "(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")"));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Sum/Product format");
        }
        
        if (op == "diff" || op == "Diff") {
            if (ast.size() == 2) {
                bool dummy = false;
                Expression body = parseAST(ast[1], isRad, true, dummy);
                
                Expression raw_diff = Expression(body.get_basic()->diff(SymEngine::symbol("x")));
                
                std::string exprStr = body.get_basic()->__str__();
                adaptSymEngineToGiac(exprStr);
                
                // 将求导(diff)与化简(simplify)指令给顶层 Giac 处理
                return Expression(SymEngine::symbol("diff(" + exprStr + ", x)"));
            }
        }
        
        // === 微积分：极限 (Limit) ===
        if (op == "Limit") {
            if (ast.size() >= 3) {
                json funcNode = ast[1];
                json targetNode = ast[2];
                std::string varStr = "x";
                
                if (funcNode.is_array() && funcNode.size() >= 3 && funcNode[0] == "Function") {
                    bool dummy = false;
                    Expression body = parseAST(funcNode[1], isRad, true, dummy);
                    if (funcNode[2].is_string()) varStr = funcNode[2].get<std::string>();
                    Expression targetExpr = parseAST(targetNode, isRad, true, dummy);
                    
                    std::string exprStr = body.get_basic()->__str__();
                    std::string targetStr = targetExpr.get_basic()->__str__();
                    
                    replaceAll(exprStr, "**", "^");
                    replaceAll(targetStr, "**", "^");
                    
                    replaceAll(exprStr, "E", "e");
                    replaceAll(targetStr, "E", "e");
                    
                    // 不调 Giac，直接组装符号
                    return Expression(SymEngine::symbol("limit(" + exprStr + ", " + varStr + ", " + targetStr + ")"));
                }
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Limit format");
        }
        
        // === 微积分：积分 (Integration) 双轨制引擎 ===
        if (op == "Integrate") {
            if (ast.size() == 3) {
                
                // 路线 A：不定积分 (Indefinite Integration)
                if (ast[2].is_string()) {
                    std::string var_name = ast[2].get<std::string>();
                    bool dummy = false;
                    Expression body = parseAST(ast[1], isRad, true, dummy);
                    
                    try {
                        // 1. 将 SymEngine 被积函数转为字符串，并进行语法适配
                        std::string exprStr = body.get_basic()->__str__();
                        replaceAll(exprStr, "**", "^");
                        replaceAll(exprStr, "E", "e");
                        
                        // 组装不定积分符号
                        return Expression(SymEngine::symbol("MAGICINDEFintegrate(" + exprStr + ", " + var_name + ")"));
                        
                    } catch (...) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Error:NoIntegralAlg");
                    }
                }
                
                // 路线 B：定积分 (Definite Integration)
                else if (ast[2].is_array() && ast[2][0] == "Tuple") {
                    std::string var_name = "x";
                    if (ast[2].size() > 1 && ast[2][1].is_string()) var_name = ast[2][1].get<std::string>();

                    bool dummy = false;
                    Expression body = parseAST(ast[1], isRad, true, dummy);
                    Expression lower_expr = parseAST(ast[2][2], isRad, true, dummy);
                    Expression upper_expr = parseAST(ast[2][3], isRad, true, dummy);

                    // 💡 优化：将字符串解析提到 try 块外面，让双轨制引擎共享参数
                    std::string exprStr = body.get_basic()->__str__();
                    std::string lowerStr = lower_expr.get_basic()->__str__();
                    std::string upperStr = upper_expr.get_basic()->__str__();
                    
                    replaceAll(exprStr, "**", "^");
                    replaceAll(lowerStr, "**", "^");
                    replaceAll(upperStr, "**", "^");

                    // 【重构战役一】：里施算法与数值积分兜底已移交至 engine，这里仅作翻译！
                    return Expression(SymEngine::symbol("integrate(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")"));
                }
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Integral format");
        }
        
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}