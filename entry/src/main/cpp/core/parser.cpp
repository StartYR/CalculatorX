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
        
        if (op == "GCD" || op == "LCM" || op == "Lcm" || op == "lcm") { /* numbers only */ }
        if (op == "Mod" || op == "Modulo") {
            if (ast.size() == 3) {
                Expression a = parseAST(ast[1], isRad, true, hasDMS);
                Expression b = parseAST(ast[2], isRad, true, hasDMS);
                return a - b * SymEngine::floor(a / b);
            }
            return Expression(SymEngine::symbol("Error"));
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
                
                Expression lower_expr = parseAST(ast[2][2], isRad, true, hasDMS);
                Expression upper_expr = parseAST(ast[2][3], isRad, true, hasDMS);
                
                long long start = 0, end = 0;
                try {
                    start = static_cast<long long>(std::floor(SymEngine::eval_double(lower_expr)));
                    end = static_cast<long long>(std::floor(SymEngine::eval_double(upper_expr)));
                } catch (...) {
                    throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Limits must be calculable numbers");
                }
                
                if (end < start) return (op == "Sum") ? Expression(0) : Expression(1);
                if (end - start > 10000) {
                    throw CalcException(CalcErrorCode::TIMEOUT_ERROR, "Iteration limit exceeded");
                }
                
                Expression body = parseAST(ast[1], isRad, true, hasDMS);
                Expression total = (op == "Sum") ? Expression(0) : Expression(1);
                SymEngine::RCP<const SymEngine::Symbol> sym_var = SymEngine::symbol(var_name);
                
                for (long long i = start; i <= end; ++i) {
                    SymEngine::map_basic_basic subs_map;
                    subs_map[sym_var] = Expression(i).get_basic();
                    Expression evaluated_term(body.get_basic()->subs(subs_map));
                    if (op == "Sum") total += evaluated_term;
                    else total *= evaluated_term;
                }
                return total;
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
                    auto sym_var = SymEngine::symbol(var_name);

                    // 里施算法 / 符号解析
                    try {
                        std::string exprStr = body.get_basic()->__str__();
                        std::string lowerStr = lower_expr.get_basic()->__str__();
                        std::string upperStr = upper_expr.get_basic()->__str__();
                        
                        replaceAll(exprStr, "**", "^");
                        replaceAll(lowerStr, "**", "^");
                        replaceAll(upperStr, "**", "^");
                        
                        // 调用 Giac 尝试算出精确解
                        std::string giacCmd = "latex(simplify(integrate(" + exprStr + ", " + var_name + ", " + lowerStr + ", " + upperStr + ")))";
                        std::string rawResult = evaluateWithGiac(giacCmd);
                        
                        if (rawResult.size() >= 2 && rawResult.front() == '"' && rawResult.back() == '"') {
                            rawResult = rawResult.substr(1, rawResult.size() - 2);
                        }
                        
                        // 如果 Giac 算不出来，它会返回 undef、原样返回 integrate(...)，或者带有问号
                        if (rawResult.find("undef") != std::string::npos || 
                            rawResult.find("\\int") != std::string::npos || 
                            rawResult.find("integrate") != std::string::npos ||
                            rawResult.find("?") != std::string::npos ||
                            rawResult.empty()) {
                            // 主动熔断抛出异常，使用辛普森算法兜底
                            throw std::runtime_error("Force Numerical Fallback");
                        }
                        
                        // 计算成功
                        std::string boxedResult = "MAGICGIACRESULT" + rawResult;
                        return Expression(SymEngine::symbol(boxedResult));
                        
                    } 
                    // 辛普森 1/3 极速数值积分 (近似解)
                    catch (...) {
                        try {
                            double a = SymEngine::eval_double(lower_expr);
                            double b = SymEngine::eval_double(upper_expr);

                            int N = 1000;
                            double h = (b - a) / N;
                            double sum = 0.0;

                            for (int i = 0; i <= N; ++i) {
                                double x_i = a + i * h;
                                SymEngine::map_basic_basic subs_map;
                                subs_map[sym_var] = Expression(x_i).get_basic();
                                double y_i = SymEngine::eval_double(Expression(body.get_basic()->subs(subs_map)));
                                
                                // 权重分配：首尾为 1，奇数为 4，偶数为 2
                                double weight = (i == 0 || i == N) ? 1.0 : ((i % 2 == 1) ? 4.0 : 2.0);
                                sum += weight * y_i;
                            }
                            double raw_result = sum * h / 3.0;
                            // 四舍五入保留 10 位小数
                            double snapped_result = std::round(raw_result * 1e10) / 1e10;
                            return Expression(snapped_result);
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