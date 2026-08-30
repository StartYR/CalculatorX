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
#include <cctype>
#include <string>

using json = nlohmann::json;
using SymEngine::Expression;

namespace {

class ParseDepthGuard {
public:
    explicit ParseDepthGuard(CalcContext& context)
        : ctx(context), root(context.parseDepth == 0) {
        ++ctx.parseDepth;
        if (root) ctx.infiniteProductFallbackExpression.clear();
    }

    ~ParseDepthGuard() {
        --ctx.parseDepth;
    }

    bool isRoot() const { return root; }

private:
    CalcContext& ctx;
    bool root;
};

bool isIntegerText(const std::string& value) {
    if (value.empty()) return false;
    std::size_t pos = (value[0] == '-' || value[0] == '+') ? 1 : 0;
    if (pos == value.size()) return false;
    for (; pos < value.size(); ++pos) {
        if (!std::isdigit(static_cast<unsigned char>(value[pos]))) return false;
    }
    return true;
}

bool isIntegerLiteralNode(const json& node) {
    if (node.is_number_integer() || node.is_number_unsigned()) return true;
    if (node.is_number_float()) {
        double value = node.get<double>();
        return std::isfinite(value) && std::floor(value) == value;
    }
    if (node.is_object() && node.contains("num") && node["num"].is_string()) {
        return isIntegerText(node["num"].get<std::string>());
    }
    if (node.is_array() && node.size() == 2 && node[0] == "Negate") {
        return isIntegerLiteralNode(node[1]);
    }
    return false;
}

bool isNumericCoefficientNode(const json& node) {
    if (node.is_number()) return true;
    if (!node.is_object() || !node.contains("num") || !node["num"].is_string()) return false;

    const std::string value = node["num"].get<std::string>();
    if (value.empty()) return false;
    std::size_t pos = (value[0] == '-' || value[0] == '+') ? 1 : 0;
    bool hasDigit = false;
    for (; pos < value.size(); ++pos) {
        char c = value[pos];
        if (std::isdigit(static_cast<unsigned char>(c))) {
            hasDigit = true;
            continue;
        }
        if (c != '.' && c != 'e' && c != 'E' && c != '+' && c != '-') return false;
    }
    return hasDigit;
}

bool isRationalFunctionNode(const json& node, const std::string& variable) {
    if (isNumericCoefficientNode(node)) return true;
    if (node.is_string()) return node.get<std::string>() == variable;
    if (!node.is_array() || node.empty() || !node[0].is_string()) return false;

    const std::string op = node[0].get<std::string>();
    if (op == "Delimiter") {
        return node.size() == 2 && isRationalFunctionNode(node[1], variable);
    }
    if (op == "Negate") {
        return node.size() == 2 && isRationalFunctionNode(node[1], variable);
    }
    if (op == "Tuple") {
        return node.size() == 3 && isRationalFunctionNode(node[1], variable) &&
               isRationalFunctionNode(node[2], variable);
    }
    if (op == "Subtract") {
        return (node.size() == 2 || node.size() == 3) &&
               isRationalFunctionNode(node[1], variable) &&
               (node.size() == 2 || isRationalFunctionNode(node[2], variable));
    }
    if (op == "Divide" || op == "Rational") {
        return node.size() == 3 && isRationalFunctionNode(node[1], variable) &&
               isRationalFunctionNode(node[2], variable);
    }
    if (op == "Add" || op == "Multiply" || op == "InvisibleOperator") {
        if (node.size() < 2) return false;
        for (std::size_t i = 1; i < node.size(); ++i) {
            if (!isRationalFunctionNode(node[i], variable)) return false;
        }
        return true;
    }
    if (op == "Power") {
        return node.size() == 3 && isRationalFunctionNode(node[1], variable) &&
               isIntegerLiteralNode(node[2]);
    }
    return false;
}

std::string createInternalProductLimitVariable(const json& root, CalcContext& ctx) {
    const std::string serialized = root.dump();
    std::string candidate;
    do {
        candidate = "calcxprodlimit" + std::to_string(ctx.internalSymbolCounter++);
    } while (serialized.find(candidate) != std::string::npos);
    return candidate;
}

} // namespace

// 矩阵与数组转 Giac 字符串的核心解析器
static std::string parseListToGiacString(const json& listNode, CalcContext& ctx) {
    if (!listNode.is_array() || listNode.empty() || listNode[0] != "List") return "";
    
    std::string result = "[";
    for (size_t i = 1; i < listNode.size(); ++i) {
        if (i > 1) result += ","; // 元素之间用逗号隔开
        
        if (listNode[i].is_array() && listNode[i][0] == "List") {
            // 遇到嵌套数组（比如矩阵的行），递归深扒
            result += parseListToGiacString(listNode[i], ctx);
        } else {
            // 遇到具体的数字或公式（叶子节点），交回给 parseAST 解析，然后转成字符串
            Expression elementExpr = parseAST(listNode[i], ctx);
            std::string elemStr = elementExpr.get_basic()->__str__();
            replaceAll(elemStr, "**", "^"); // 符号适配
            replaceAll(elemStr, "I", "i");
            result += elemStr;
        }
    }
    result += "]";
    return result;
}

Expression parseAST(const json& ast, CalcContext& ctx) {
    ParseDepthGuard depthGuard(ctx);
    
    // 1. 强制精确求值，并允许向下级传播 DMS 副作用 (如 Sqrt, Power)
    auto parseExact = [&](const json& node) {
        bool oldExact = ctx.preferExact;
        ctx.preferExact = true;
        Expression res = parseAST(node, ctx);
        ctx.preferExact = oldExact; // 恢复之前的精确状态
        return res;
    };

    // 2. 强制精确求值，但物理隔离（忽略）子节点的 DMS 污染 (如 Complex, Integrate)
    auto parseExactIsolateDMS = [&](const json& node) {
        bool oldExact = ctx.preferExact;
        bool oldDMS = ctx.hasDMS;
        ctx.preferExact = true;
        Expression res = parseAST(node, ctx);
        ctx.preferExact = oldExact;
        ctx.hasDMS = oldDMS; // 屏蔽下层的 DMS 举旗行为，恢复原来的状态
        return res;
    };

    // ==========================================
    // 常数与基础数字解析
    // ==========================================
    if (ast.is_number()) {
        double val = ast.get<double>();
        if (std::floor(val) == val) return Expression(static_cast<long>(val));
        
        if (ctx.preferExact) { // 👈 统一使用上下文配置
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
    
    // ==========================================
    // AST 数组节点解析与路由分发
    // ==========================================
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        
        // 只有前端明确是矩阵模式时，才允许进行矩阵判断
        if (ctx.mode == CalcMode::MATRIX && MatrixParser::isMatrixExpression(ast)) {
            return MatrixParser::handle(ast, ctx);
        }
        
        std::string op = ast[0].get<std::string>();

        // --- 度分秒 (DMS) 拦截锁 ---
        if (op == "dms" || op == "Dms") {
            // 矩阵、解方程等非标准模式下，彻底封杀 DMS
            if (ctx.mode != CalcMode::STANDARD) {
                throw CalcException(CalcErrorCode::SYNTAX_ERROR, "DMS is only available in Standard Mode");
            }
            
            if (ast.size() == 4) {
                Expression d = parseExactIsolateDMS(ast[1]);
                Expression m = parseExactIsolateDMS(ast[2]);
                Expression s = parseExactIsolateDMS(ast[3]);
                try {
                    Expression total_deg = d + m / Expression(60) + s / Expression(3600);
                    ctx.hasDMS = true; // 👈 举起 DMS 小红旗
                    if (ctx.isRad) {
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
            if (ast.size() > 1) return parseAST(ast[1], ctx);
            return Expression(0);
        }
        
        // 带有 MAGICMAT 标记的特殊矩阵符号交由 Giac
        if (op == "Matrix" && ast.size() >= 2) {
            std::string giacMatrixStr = parseListToGiacString(ast[1], ctx);
            return Expression(SymEngine::symbol("MAGICMAT" + giacMatrixStr));
        }

        // 拦截 Tuple：解决隐式乘法和特殊算子
        if (op == "Tuple") {
            if (ast.size() == 3) {
                return parseAST(ast[1], ctx) * parseAST(ast[2], ctx);
            }
        }
        
        // 复数 (Complex)
        if (op == "Complex") {
            if (ast.size() == 3) {
                Expression real_part = parseExactIsolateDMS(ast[1]);
                Expression imag_part = parseExactIsolateDMS(ast[2]);
                return real_part + imag_part * Expression(SymEngine::I);
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Complex format");
        }
        
        // 四则运算
        if (op == "Add") {
            Expression sum(0);
            for (size_t i = 1; i < ast.size(); ++i) sum += parseAST(ast[i], ctx);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -parseAST(ast[1], ctx);
            return parseAST(ast[1], ctx) - parseAST(ast[2], ctx);
        }
        if (op == "Multiply" || op == "InvisibleOperator") {
            Expression prod(1);
            for (size_t i = 1; i < ast.size(); ++i) prod *= parseAST(ast[i], ctx);
            return prod;
        }
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1], ctx) / parseAST(ast[2], ctx);
        }
        if (op == "Equal") {
            // 确保等式绝对有左右两边
            if (ast.size() != 3) {
                throw std::runtime_error("SyntaxError: 完整的等式需要左右两边");
            }
    
            // 递归解析左右两式
            SymEngine::Expression lhs = parseAST(ast[1], ctx);
            SymEngine::Expression rhs = parseAST(ast[2], ctx);
        
            // 方程模式，转化为 LHS - RHS
            if (ctx.mode == CalcMode::EQUATION) {
                return SymEngine::sub(lhs, rhs);
            }
    
            // 如果不是方程模式却出现了等号
            throw std::runtime_error("MathError: 非方程模式下不允许存在等号");
        }

        // 基础数学函数
        if (op == "Sqrt") return SymEngine::sqrt(parseExact(ast[1]));
        if (op == "Root") return SymEngine::pow(parseExact(ast[1]), Expression(1) / parseExact(ast[2]));
        if (op == "Abs") return SymEngine::abs(parseExact(ast[1]));
        if (op == "Power") {
            Expression base = parseExact(ast[1]);
            Expression exp = parseExact(ast[2]);
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
                Expression a = parseExactIsolateDMS(ast[1]);
                Expression b = parseExactIsolateDMS(ast[2]);
                
                std::string aStr = a.get_basic()->__str__();
                std::string bStr = b.get_basic()->__str__();
                
                replaceAll(aStr, "**", "^");
                replaceAll(bStr, "**", "^");
                
                std::string giacFunc;
                if (op == "GCD") giacFunc = "gcd";
                else if (op == "LCM" || op == "Lcm" || op == "lcm") giacFunc = "lcm";
                else giacFunc = "irem";

                return Expression(SymEngine::symbol(giacFunc + "(" + aStr + ", " + bStr + ")"));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid format for GCD/LCM/Mod");
        }
        
        if (op == "Percent") {
             return parseExact(ast[1]) / Expression(100);
        }
        
        if (op == "Factorial") {
            if (ast.size() == 2) {
                Expression arg = parseExact(ast[1]);
                try {
                    double val = SymEngine::eval_double(arg);
                    if (val < 0 && std::floor(val) == val) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Negative Factorial");
                    if (val > 5000 && std::floor(val) == val) {
                        double magnitude = FastMath::getFactorialMagnitude(val);
                        FastMath::checkOverflow(magnitude);
                        return FastMath::buildBigScientificNode(magnitude);
                    }
                } catch (const CalcException&) {
                    throw;
                } catch (...) {
                    // 符号阶乘（如 n!）无法转换为 double，应保留为 Gamma 表达式，
                    // 而不是把立即发生的类型失败误报成计算超时。
                }
                return Expression(SymEngine::gamma((arg + Expression(1)).get_basic()));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Factorial length.");
        }
        
        if (op == "nCr") {
            if (ast.size() == 3) {
                Expression n = parseExact(ast[1]);
                Expression r = parseExact(ast[2]);
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
                Expression n = parseExact(ast[1]);
                Expression r = parseExact(ast[2]);
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

        // === 三角函数与倒数三角函数 ===
        if (op == "Sin" || op == "Cos" || op == "Tan" || op == "Csc" || op == "Sec" || op == "Cot") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseExactIsolateDMS(ast[1]); 
            // 角度制下，先将输入的角度转换为弧度再进行计算
            if (!ctx.isRad) arg = arg * Expression(SymEngine::pi) / Expression(180);
            
            if (op == "Sin") return SymEngine::sin(arg);
            if (op == "Cos") return SymEngine::cos(arg);
            if (op == "Tan") return SymEngine::tan(arg);
            if (op == "Csc") return Expression(1) / SymEngine::sin(arg);
            if (op == "Sec") return Expression(1) / SymEngine::cos(arg);
            if (op == "Cot") return Expression(1) / SymEngine::tan(arg);
        }

        if (op == "Arcsin" || op == "Arccos" || op == "Arctan" || op == "Arccsc" || op == "Arcsec" || op == "Arccot") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseExactIsolateDMS(ast[1]); 
            Expression res;
            
            if (op == "Arcsin") res = SymEngine::asin(arg);
            else if (op == "Arccos") res = SymEngine::acos(arg);
            else if (op == "Arctan") res = SymEngine::atan(arg);
            else if (op == "Arccsc") res = SymEngine::asin(Expression(1) / arg);
            else if (op == "Arcsec") res = SymEngine::acos(Expression(1) / arg);
            else if (op == "Arccot") res = SymEngine::atan(Expression(1) / arg);
            
            // 角度制下，将算出的弧度结果转换为角度
            if (!ctx.isRad) res = res * Expression(180) / Expression(SymEngine::pi);
            return res;
        }

        // === 双曲函数与反双曲函数 (不受 Rad/Deg 模式影响) ===
        if (op == "Sinh" || op == "Cosh" || op == "Tanh") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseExactIsolateDMS(ast[1]);
            
            if (op == "Sinh") return SymEngine::sinh(arg);
            if (op == "Cosh") return SymEngine::cosh(arg);
            if (op == "Tanh") return SymEngine::tanh(arg);
        }

        if (op == "Arcsinh" || op == "Arccosh" || op == "Arctanh") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseExactIsolateDMS(ast[1]);
            
            if (op == "Arcsinh") return SymEngine::asinh(arg);
            if (op == "Arccosh") return SymEngine::acosh(arg);
            if (op == "Arctanh") return SymEngine::atanh(arg);
        }
        
        
        
        // === 对数函数 ===
        if (op == "Ln") return SymEngine::log(parseExact(ast[1]));
        if (op == "Log") {
            ctx.hasChangeOfBaseLog = true;
            if (ast.size() == 3) return SymEngine::log(parseExact(ast[1]), parseExact(ast[2]));
            return SymEngine::log(parseExact(ast[1]), Expression(10));
        }
        if (op == "Log10" || op == "Lg") {
            ctx.hasChangeOfBaseLog = true;
            Expression num(SymEngine::log(parseExact(ast[1]).get_basic()));
            Expression den(SymEngine::log(Expression(10).get_basic()));
            return num / den;
        }
        
        // === 求和与连乘 ===
        if (op == "Sum" || op == "Product") {
            if (ast.size() == 3 && ast[2].is_array() && ast[2].size() >= 4 && ast[2][0] == "Tuple") {
                std::string var_name = "x";
                if (ast[2][1].is_string()) var_name = ast[2][1].get<std::string>();
                
                Expression body = parseExactIsolateDMS(ast[1]);
                Expression lower_expr = parseExactIsolateDMS(ast[2][2]);
                Expression upper_expr = parseExactIsolateDMS(ast[2][3]);
                
                std::string exprStr = body.get_basic()->__str__();
                std::string lowerStr = lower_expr.get_basic()->__str__();
                std::string upperStr = upper_expr.get_basic()->__str__();
                
                adaptSymEngineToGiac(exprStr);
                adaptSymEngineToGiac(lowerStr);
                adaptSymEngineToGiac(upperStr);
                
                std::string giacFuncName = (op == "Sum") ? "sum" : "product";

                // Giac 1.9.0 会把部分无穷有理乘积的分子、分母分别代入无穷，
                // 从而把本应整体取极限的结果变成 undef。保留原始 product 作为首选路径，
                // 只为安全的顶层有理式准备“有限部分乘积 -> 整体极限”降级表达式。
                if (op == "Product" && depthGuard.isRoot() && upperStr == "inf" &&
                    isIntegerLiteralNode(ast[2][2]) && isRationalFunctionNode(ast[1], var_name)) {
                    std::string limitVar = createInternalProductLimitVariable(ast, ctx);
                    ctx.infiniteProductFallbackExpression =
                        "limit(product(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + limitVar +
                        "), " + limitVar + ", inf)";
                }

                return Expression(SymEngine::symbol(giacFuncName + "(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")"));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Sum/Product format");
        }
        
        // === 求导 ===
        if (op == "diff" || op == "Diff") {
            if (ast.size() == 2) {
                Expression body = parseExactIsolateDMS(ast[1]);
                Expression raw_diff = Expression(body.get_basic()->diff(SymEngine::symbol("x")));
                std::string exprStr = body.get_basic()->__str__();
                adaptSymEngineToGiac(exprStr);
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
                    Expression body = parseExactIsolateDMS(funcNode[1]);
                    if (funcNode[2].is_string()) varStr = funcNode[2].get<std::string>();
                    Expression targetExpr = parseExactIsolateDMS(targetNode);
                    
                    std::string exprStr = body.get_basic()->__str__();
                    std::string targetStr = targetExpr.get_basic()->__str__();
                    
                    replaceAll(exprStr, "**", "^");
                    replaceAll(targetStr, "**", "^");
                    
                    replaceAll(exprStr, "E", "e");
                    replaceAll(targetStr, "E", "e");
                    
                    return Expression(SymEngine::symbol("limit(" + exprStr + ", " + varStr + ", " + targetStr + ")"));
                }
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Limit format");
        }
        
        // === 微积分：积分 (Integration) 双轨制引擎 ===
        if (op == "Integrate") {
            if (ast.size() == 3) {
                
                // 路线 A：不定积分
                if (ast[2].is_string()) {
                    std::string var_name = ast[2].get<std::string>();
                    Expression body = parseExactIsolateDMS(ast[1]);
                    
                    try {
                        std::string exprStr = body.get_basic()->__str__();
                        replaceAll(exprStr, "**", "^");
                        replaceAll(exprStr, "E", "e");
                        
                        return Expression(SymEngine::symbol("MAGICINDEFintegrate(" + exprStr + ", " + var_name + ")"));
                        
                    } catch (...) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Error:NoIntegralAlg");
                    }
                }
                
                // 路线 B：定积分
                else if (ast[2].is_array() && ast[2][0] == "Tuple") {
                    std::string var_name = "x";
                    if (ast[2].size() > 1 && ast[2][1].is_string()) var_name = ast[2][1].get<std::string>();

                    Expression body = parseExactIsolateDMS(ast[1]);
                    Expression lower_expr = parseExactIsolateDMS(ast[2][2]);
                    Expression upper_expr = parseExactIsolateDMS(ast[2][3]);

                    std::string exprStr = body.get_basic()->__str__();
                    std::string lowerStr = lower_expr.get_basic()->__str__();
                    std::string upperStr = upper_expr.get_basic()->__str__();
                    
                    replaceAll(exprStr, "**", "^");
                    replaceAll(lowerStr, "**", "^");
                    replaceAll(upperStr, "**", "^");

                    return Expression(SymEngine::symbol("integrate(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")"));
                }
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Integral format");
        }
        
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}
