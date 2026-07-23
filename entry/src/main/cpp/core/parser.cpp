/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file parser.cpp
 * @description MathJSON AST 递归下降解析器，将 JSON AST 转换为 SymEngine 表达式
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "parser.h"
#include "giac_bridge.h"
#include "string_utils.h"
#include "FastMath.h"
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
            replaceAll(elemStr, "**", "^"); // 顺手做个符号适配
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
        if (s == "Pi") return Expression(SymEngine::pi);
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E);
        if (s == "NaN") throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Frontend folded to NaN");
        if (s == "PositiveInfinity" || s == "Infinity") return Expression(SymEngine::symbol("infinity"));
        if (s == "NegativeInfinity") return -Expression(SymEngine::symbol("infinity"));
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
        if (op == "Matrix") {
            if (ast.size() >= 2) { // ast[1] 里包裹的就是 ["List", ["List", ...], ...]
                // 1. 调用辅助函数，把 JSON 扒成 Giac 认识的 [[1,2],[3,4]] 字符串
                std::string giacMatrixStr = parseListToGiacString(ast[1], isRad, preferExact, hasDMS);
                
                // 2. 组装成 Giac 命令：利用 latex(simplify(...)) 让它自动返回渲染好的 LaTeX
                std::string giacCmd = "latex(simplify(" + giacMatrixStr + "))";
                std::string rawResult = evaluateWithGiac(giacCmd);
                
                // 3. 剥离 Giac 输出两端的双引号
                if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                    rawResult = rawResult.substr(1, rawResult.size() - 2);
                }
                
                // 4. 装进魔法盒，强势穿透 SymEngine 的类型检查直接返回！
                return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
            }
        }
        
        // 线性代数与矩阵单参数函数
        if (op == "Det" || op == "Tr" || op == "rref" || op == "eig" || op == "rank") {
            if (ast.size() >= 2) {
                // 映射 Giac 的原生函数名
                std::string giacFunc = op;
                if (op == "Det") giacFunc = "det";
                else if (op == "Tr") giacFunc = "trace";
                else if (op == "eig") giacFunc = "eigenvals"; 

                std::string argStr = "";
                if (ast[1].is_array() && ast[1][0] == "Matrix" && ast[1].size() >= 2) {
                    argStr = parseListToGiacString(ast[1][1], isRad, preferExact, hasDMS);
                } else {
                    // 否则当作普通表达式解析（兼容符号变量）
                    argStr = parseAST(ast[1], isRad, preferExact, hasDMS).get_basic()->__str__();
                }

                // 生成 Giac 计算指令并求值
                std::string giacCmd = "latex(simplify(" + giacFunc + "(" + argStr + ")))";
                std::string rawResult = evaluateWithGiac(giacCmd);
                
                if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                    rawResult = rawResult.substr(1, rawResult.size() - 2);
                }
                return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
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
        
        // ================= Tuple (处理矩阵叉乘与降维算子) =================
        if (op == "Tuple") {
            // 1. 拦截矩阵的叉乘与点乘: ["Tuple", Matrix1, "cross", Matrix2]
            if (ast.size() == 4 && ast[2].is_string()) {
                std::string midElem = ast[2].get<std::string>();
                if (midElem == "cross" || midElem == "dot") {
                    std::string arg1Str = (ast[1].is_array() && ast[1][0] == "Matrix") ? 
                        parseListToGiacString(ast[1][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[1], isRad, preferExact, hasDMS).get_basic()->__str__();
                        
                    std::string arg2Str = (ast[3].is_array() && ast[3][0] == "Matrix") ? 
                        parseListToGiacString(ast[3][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[3], isRad, preferExact, hasDMS).get_basic()->__str__();

                    std::string giacCmd = "latex(simplify(" + midElem + "(" + arg1Str + ", " + arg2Str + ")))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
                }
            }
            
            // 2. 拦截降维后的矩阵后缀操作: ["Tuple", Matrix, "TranOp"]
            if (ast.size() == 3 && ast.back().is_string()) {
                std::string lastElem = ast.back().get<std::string>();
                if (lastElem == "TranOp" || lastElem == "ConjTranOp" || lastElem == "InvOp") {
                    std::string giacFunc = "tran";
                    if (lastElem == "ConjTranOp") giacFunc = "trn";
                    if (lastElem == "InvOp") giacFunc = "inv";
                    
                    std::string baseStr = (ast[1].is_array() && ast[1][0] == "Matrix") ? 
                        parseListToGiacString(ast[1][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[1], isRad, preferExact, hasDMS).get_basic()->__str__();
                        
                    std::string giacCmd = "latex(simplify(" + giacFunc + "(" + baseStr + ")))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
                }
            }
        }
        if (op == "Multiply") {
            // 隐式向量叉乘与点乘
            if (ast.size() >= 4 && ast.back().is_string()) {
                std::string lastElem = ast.back().get<std::string>();
                if (lastElem == "cross" || lastElem == "dot") {
                    std::string arg1Str = (ast[1].is_array() && ast[1][0] == "Matrix") ? 
                        parseListToGiacString(ast[1][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[1], isRad, preferExact, hasDMS).get_basic()->__str__();
                        
                    std::string arg2Str = (ast[2].is_array() && ast[2][0] == "Matrix") ? 
                        parseListToGiacString(ast[2][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[2], isRad, preferExact, hasDMS).get_basic()->__str__();

                    // 直接使用 cross(A, B) 或 dot(A, B)
                    std::string giacCmd = "latex(simplify(" + lastElem + "(" + arg1Str + ", " + arg2Str + ")))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
                }
            }
            
            // 双保险：拦截可能被解析为 Multiply 的后缀算子
            if (ast.size() >= 3 && ast.back().is_string()) {
                std::string lastElem = ast.back().get<std::string>();
                if (lastElem == "TranOp" || lastElem == "ConjTranOp" || lastElem == "InvOp") {
                    std::string giacFunc = "tran";
                    if (lastElem == "ConjTranOp") giacFunc = "trn";
                    if (lastElem == "InvOp") giacFunc = "inv";
                    
                    // 乘法数组的倒数第二个元素就是矩阵
                    std::string baseStr = (ast[ast.size()-2].is_array() && ast[ast.size()-2][0] == "Matrix") ? 
                        parseListToGiacString(ast[ast.size()-2][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[ast.size()-2], isRad, preferExact, hasDMS).get_basic()->__str__();
                        
                    std::string giacCmd = "latex(simplify(" + giacFunc + "(" + baseStr + ")))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
                }
            }
            
            // 普通乘法
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
            // 拦截矩阵转置 (T) 与共轭转置 (H)
            if (ast.size() == 3 && ast[2].is_string()) {
                std::string expStr = ast[2].get<std::string>();
                if (expStr == "T_upright" || expStr == "H_upright") {
                    // tran 是转置，trn 是共轭转置
                    std::string giacFunc = (expStr == "T_upright") ? "tran" : "trn";
                    
                    std::string baseStr = (ast[1].is_array() && ast[1][0] == "Matrix") ? 
                        parseListToGiacString(ast[1][1], isRad, preferExact, hasDMS) : 
                        parseAST(ast[1], isRad, preferExact, hasDMS).get_basic()->__str__();
                        
                    std::string giacCmd = "latex(simplify(" + giacFunc + "(" + baseStr + ")))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
                }
            }
            
            // 普通 Power
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

                // 构建 Giac 指令
                std::string giacCmd = "latex(simplify(" + giacFunc + "(" + aStr + ", " + bStr + ")))";
                std::string rawResult = evaluateWithGiac(giacCmd);
                
                if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                    rawResult = rawResult.substr(1, rawResult.size() - 2);
                }
                
                // 处理 Giac 无法计算的降级情况
                if (rawResult.find("undef") != std::string::npos || 
                    rawResult.find(giacFunc) != std::string::npos || 
                    rawResult.empty()) {
                    throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid arguments for " + giacFunc);
                }
                
                return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
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
                
                // 语法适配：将 SymEngine 的乘方符号替换为 Giac 的乘方符号
                replaceAll(exprStr, "**", "^");
                replaceAll(lowerStr, "**", "^");
                replaceAll(upperStr, "**", "^");
                
                // 根据操作符选择对应的 Giac 函数
                std::string giacFuncName = (op == "Sum") ? "sum" : "product";
                
                // 构建 Giac 指令，套上 simplify 和 latex
                std::string giacCmd = "latex(simplify(" + giacFuncName + "(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")))";
                
                std::string rawResult = evaluateWithGiac(giacCmd);
                
                // 剥离 Giac 输出自带的双引号
                if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                    rawResult = rawResult.substr(1, rawResult.size() - 2);
                }
                
                // 直接装箱返回前端渲染，绕过 SymEngine 解析
                return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Sum/Product format");
        }
        
        if (op == "diff" || op == "Diff") {
            if (ast.size() == 2) {
                bool dummy = false;
                Expression body = parseAST(ast[1], isRad, true, dummy);
                return Expression(body.get_basic()->diff(SymEngine::symbol("x")));
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
                    
                    // 呼叫 Giac
                    std::string giacCmd = "latex(limit(" + exprStr + ", " + varStr + ", " + targetStr + "))";
                    std::string rawResult = evaluateWithGiac(giacCmd);
                    
                    if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                        rawResult = rawResult.substr(1, rawResult.size() - 2);
                    }
                    return Expression(SymEngine::symbol("MAGICGIACRESULT" + rawResult));
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
                        
                        // 2. 组装 Giac 指令
                        std::string giacCmd = "latex(simplify(integrate(" + exprStr + ", " + var_name + ")))";
                        std::string rawResult = evaluateWithGiac(giacCmd);
                        
                        // 3. 剥离 Giac 输出自带的双引号
                        if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                            rawResult = rawResult.substr(1, rawResult.size() - 2);
                        }
                        
                        // 4. 加上常数 C
                        std::string boxedResult = "MAGICGIACRESULT" + rawResult + " + \\mathbf{C}";
                        return Expression(SymEngine::symbol(boxedResult));
                        
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

                    // 里施算法 / 符号解析 (尝试求精确解)
                    try {
                        std::string giacCmd = "latex(simplify(integrate(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")))";
                        std::string rawResult = evaluateWithGiac(giacCmd);
                        
                        if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                            rawResult = rawResult.substr(1, rawResult.size() - 2);
                        }
                        
                        // 如果 Giac 算不出来精确解析解，
                        // 或者算出了过于超纲的“特殊函数”（如 Ci, igamma, erf 等），主动熔断触发数值积分兜底
                        if (rawResult.find("undef") != std::string::npos || 
                            rawResult.find("\\int") != std::string::npos || 
                            rawResult.find("integrate") != std::string::npos ||
                            rawResult.find("?") != std::string::npos ||
                            rawResult.find("Ci") != std::string::npos || 
                            rawResult.find("Si") != std::string::npos || 
                            rawResult.find("igamma") != std::string::npos || 
                            rawResult.find("erf") != std::string::npos || 
                            rawResult.empty()) {
                            throw std::runtime_error("Force Numerical Fallback");
                        }
                        
                        std::string boxedResult = "MAGICGIACRESULT" + rawResult;
                        return Expression(SymEngine::symbol(boxedResult));
                        
                    } 
                    // 极速数值积分兜底 (接管了之前的辛普森 1/3)
                    catch (...) {
                        try {
                            // 调用 Giac 内部的 Romberg 自适应高精度数值积分算法
                            std::string giacCmd = "latex(romberg(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + "))";
                            std::string rawResult = evaluateWithGiac(giacCmd);

                            if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                                rawResult = rawResult.substr(1, rawResult.size() - 2);
                            }

                            if (rawResult.find("undef") != std::string::npos || 
                                rawResult.find("romberg") != std::string::npos ||
                                rawResult.find("?") != std::string::npos ||
                                rawResult.empty()) {
                                throw std::runtime_error("Romberg Failed");
                            }

                            // 处理剧烈震荡函数返回的误差区间 [min, max]
                            if (rawResult.find(',') != std::string::npos && 
                               (rawResult.find('[') != std::string::npos || rawResult.find("left[") != std::string::npos)) {
                                
                                std::string cleanStr = rawResult;
                                // 清洗所有的 LaTeX 包装符号、括号和空格
                                replaceAll(cleanStr, "\\left", "");
                                replaceAll(cleanStr, "\\right", "");
                                replaceAll(cleanStr, "[", "");
                                replaceAll(cleanStr, "]", "");
                                replaceAll(cleanStr, " ", "");
                                
                                size_t commaPos = cleanStr.find(',');
                                if (commaPos != std::string::npos) {
                                    try {
                                        double num1 = std::stod(cleanStr.substr(0, commaPos));
                                        double num2 = std::stod(cleanStr.substr(commaPos + 1));
                                        double mid = (num1 + num2) / 2.0; // 取区间中点
                                        rawResult = std::to_string(mid);
                                    } catch (...) {} // 解析失败则原样放行
                                }
                            }

                            std::string boxedResult = "MAGICGIACRESULT" + rawResult;
                            return Expression(SymEngine::symbol(boxedResult));
                        } catch (...) {
                            throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Integration bounds invalid or body unresolvable");
                        }
                    }
                }
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Integral format");
        }
        
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}