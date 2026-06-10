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
#include <numeric>
#include "ErrorHandler.h"
#include "FastMath.h"
#include <string>
#include "giac.h"

using json = nlohmann::json;
using SymEngine::Expression;

// 前置声明 parseAST，让后续函数可以复用符号解析能力
Expression parseAST(const json& ast, bool isRad, bool preferExact, bool& hasDMS);

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); 
    }
}

// Giac 引擎 (处理极限等高阶数学推导)
std::string evaluateWithGiac(const std::string& mathExpression) {
    try {
        giac::context ctx;
        giac::gen g(mathExpression, &ctx);
        giac::gen result = giac::eval(g, &ctx);
        
        std::string resStr = result.print(&ctx);
        
        // Giac 的 LaTeX/字符串输出两端带有双引号，这里将其剥离
        if (resStr.size() >= 2 && resStr.front() == '"' && resStr.back() == '"') {
            resStr = resStr.substr(1, resStr.size() - 2);
        }
        
        return resStr;
    } catch (const std::exception& e) {
        return "Error: " + std::string(e.what());
    } catch (...) {
        return "Error: Giac Unknown";
    }
}

std::string buildGiacCommand(const json& ast) {
    try {
        if (ast.is_array() && ast.size() >= 3 && ast[0] == "Limit") {
            json funcNode = ast[1]; 
            json targetNode = ast[2]; 

            std::string exprStr = "";
            std::string varStr = "x";

            // 1. 解析函数体与变量
            if (funcNode.is_array() && funcNode.size() >= 3 && funcNode[0] == "Function") {
                bool dummyDMS = false;
                // 复用你的 SymEngine 解析器生成标准的符号表达式
                Expression expr = parseAST(funcNode[1], true, true, dummyDMS);
                exprStr = expr.get_basic()->__str__(); 
                
                if (funcNode[2].is_string()) {
                    varStr = funcNode[2].get<std::string>(); 
                }
            }

            // 2. 解析趋近值
            bool dummyDMS = false;
            Expression targetExpr = parseAST(targetNode, true, true, dummyDMS);
            std::string targetStr = targetExpr.get_basic()->__str__();

            // 3. 语法适配替换
            // 修复乘方语法适配
            replaceAll(exprStr, "**", "^");
            replaceAll(targetStr, "**", "^");
            // 将 SymEngine 可能会解析的无穷大符号映射给 Giac
            replaceAll(targetStr, "Infinity", "infinity");
            replaceAll(targetStr, "\\infty", "infinity");

            // 4. 使用 latex() 函数包裹，让 Giac 计算后直接返回供屏幕渲染的 LaTeX
            return "latex(limit(" + exprStr + ", " + varStr + ", " + targetStr + "))";
        }
    } catch (...) {
        return ""; 
    }
    return "";
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
                            // ⚠️ 你的原版辛普森核心逻辑完全保留，一字未动！
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

std::string formatLargeIntegerToScientific(const std::string& intStr) {
    bool isNeg = (intStr[0] == '-');
    size_t firstDigitPos = isNeg ? 1 : 0;
    
    if (intStr.length() - firstDigitPos <= 1) {
        return (isNeg ? "-" : "") + intStr.substr(firstDigitPos) + "\\times 10^{0}";
    }

    std::string sign = isNeg ? "-" : "";
    std::string firstDigit = intStr.substr(firstDigitPos, 1);
    
    size_t max_frac = 10;
    std::string restDigits = intStr.substr(firstDigitPos + 1, max_frac);
    long long realExp = intStr.length() - firstDigitPos - 1;
    
    if (firstDigitPos + 1 + restDigits.length() < intStr.length()) {
        if (intStr[firstDigitPos + 1 + restDigits.length()] >= '5') {
            int carry = 1;
            for (int i = restDigits.length() - 1; i >= 0; --i) {
                int sum = (restDigits[i] - '0') + carry;
                if (sum > 9) {
                    restDigits[i] = '0';
                    carry = 1;
                } else {
                    restDigits[i] = sum + '0';
                    carry = 0;
                    break;
                }
            }
            if (carry > 0) {
                int fd = firstDigit[0] - '0' + carry;
                if (fd > 9) {
                    firstDigit = "1";
                    realExp++; 
                } else {
                    firstDigit[0] = fd + '0';
                }
            }
        }
    }
    
    restDigits.erase(restDigits.find_last_not_of('0') + 1, std::string::npos);
    
    if (restDigits.empty()) {
        return sign + firstDigit + "\\times 10^{" + std::to_string(realExp) + "}";
    } else {
        return sign + firstDigit + "." + restDigits + "\\times 10^{" + std::to_string(realExp) + "}";
    }
}

// 🧠 核心调度入口 N-API Calculate
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