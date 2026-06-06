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

using json = nlohmann::json;
using SymEngine::Expression;

// AST 树递归解析
Expression parseAST(const json& ast, bool isRad, bool preferExact = false) {
    if (ast.is_number()) {
        double val = ast.get<double>();
        if (std::floor(val) == val) return Expression(static_cast<long>(val));
        
        // 只有当上下文明确要求精确时（比如在分数、三角函数里），才把小数转分数
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
        // 普通情况（如 1.2 * 1），浮点数
        return Expression(val);
    }
    
    if (ast.is_string()) {
        std::string s = ast.get<std::string>();
        if (s == "Pi") return Expression(SymEngine::pi);
        if (s == "ExponentialE" || s == "e") return Expression(SymEngine::E);
        if (s == "NaN") {
            throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Frontend folded to NaN");
        }
        return Expression(SymEngine::symbol(s));
    }
    
    // ================================================================
    // 处理 MathJSON 的高精度数字对象结构
    // ================================================================
    if (ast.is_object() && ast.contains("num")) {
        std::string s = ast["num"].get<std::string>();
//        
//        if (s == "NaN") throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Frontend folded to NaN");
//        if (s == "Infinity" || s == "+Infinity") return Expression(SymEngine::oo);
//        if (s == "-Infinity") return Expression(SymEngine::minus_oo);
//        if (s == "ComplexInfinity") throw CalcException(CalcErrorCode::DIV_BY_ZERO, "Complex Infinity intercepted");
        

        try {
            size_t ePos = s.find('e');
            if (ePos == std::string::npos) ePos = s.find('E');

            if (ePos != std::string::npos) {
                std::string baseStr = s.substr(0, ePos);
                std::string expStr = s.substr(ePos + 1);
                long long expVal = std::stoll(expStr);

                // 如果指数绝对值大于 10000，连 Boost 都不给了，直接拼合返回！
                if (std::abs(expVal) > 10000) {
                    throw FastResultException(baseStr + "\\times 10^{" + expStr + "}");
                }

                // 【核心重构】：彻底抛弃 double，将小数转化为纯大整数计算
                size_t dotPos = baseStr.find('.');
                if (dotPos != std::string::npos) {
                    int decimals = baseStr.length() - dotPos - 1;
                    baseStr.erase(dotPos, 1); // 移除小数点，例如 "1.23" 变成 "123"
                    long long baseVal = std::stoll(baseStr);
                    expVal -= decimals;       // 补偿减去相应的指数
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
            
        } catch (const std::out_of_range&) {
            throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Astronomical explosion intercepted");
        } catch (...) {
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid num object format");
        }
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
        if (op == "Divide" || op == "Rational") {
            return parseAST(ast[1], isRad, preferExact) / parseAST(ast[2], isRad, preferExact);
        }

        // ==================== 强制精确：为了消除圆周率等无理数误差，强制将小数转换为分数 ====================
        if (op == "Sqrt") return SymEngine::sqrt(parseAST(ast[1], isRad, true));
        if (op == "Root") return SymEngine::pow(parseAST(ast[1], isRad, true), Expression(1) / parseAST(ast[2], isRad, true));
        if (op == "Abs") return SymEngine::abs(parseAST(ast[1], isRad, true));
        if (op == "Power") {
            Expression base = parseAST(ast[1], isRad, true);
            Expression exp = parseAST(ast[2], isRad, true);
            
            // 【瞬间秒杀】：利用对数评估指数运算量级
            try {
                if (SymEngine::is_a<SymEngine::Integer>(*base.get_basic()) && 
                    SymEngine::is_a<SymEngine::Integer>(*exp.get_basic())) {
                    
                    double b = SymEngine::eval_double(base);
                    double e = SymEngine::eval_double(exp);
                    
                    if (b > 0) {
                        double magnitude = e * std::log10(b);
                        
                        // 防止超过 64位整数物理极限 (2^63 - 1)
                        if (std::isinf(magnitude) || std::abs(magnitude) > 9e18) {
                            throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Exceeds 64-bit integer limits");
                        }
                        
                        // 如果结果超过 10^10000，触发直通车抛出结果
                        if (std::abs(magnitude) > 10000) {
                            long long B = static_cast<long long>(std::floor(magnitude));
                            double A = std::pow(10.0, magnitude - B);
                            
                            std::ostringstream oss;
                            oss << std::fixed << std::setprecision(5) << A;
                            std::string A_str = oss.str();
                            A_str.erase(A_str.find_last_not_of('0') + 1, std::string::npos);
                            if (A_str.back() == '.') A_str.pop_back();
                            
                            throw FastResultException(A_str + "\\times 10^{" + std::to_string(B) + "}");
                        }
                    }
                }
            } catch (const FastResultException& e) {
                throw; // 直通车必须继续往外抛出
            } catch (const CalcException& e) {
                throw; // 【必须增加】：让宇宙级溢出的拦截网穿透出去！
            } catch (...) {} // 忽略普通的求值错误，交给原引擎
            
            return SymEngine::pow(base, exp);
        }
        // 最大公约数 (GCD) 与 最小公倍数 (LCM)
        if (op == "GCD" || op == "LCM" || op == "Lcm" || op == "lcm") {
            if (ast.size() == 3) {
                // 为了绝对安全地避开 SymEngine 严苛的类型检查，我们在 AST 树层面直接提取数字
                if (ast[1].is_number() && ast[2].is_number()) {
                    long long a = static_cast<long long>(std::abs(ast[1].get<double>()));
                    long long b = static_cast<long long>(std::abs(ast[2].get<double>()));
                    if (op == "GCD") return Expression(std::gcd(a, b));
                    else return Expression(std::lcm(a, b));
                } else {
                    return Expression(SymEngine::symbol("Error\\_Int\\_Only")); // 提示只能算整数
                }
            }
            return Expression(SymEngine::symbol("Error"));
        }

        // 取模 (mod) 
        if (op == "Mod" || op == "Modulo") {
            if (ast.size() == 3) {
                Expression a = parseAST(ast[1], isRad, true);
                Expression b = parseAST(ast[2], isRad, true);
                // a mod b = a - b * floor(a / b)
                return a - b * SymEngine::floor(a / b);
            }
            return Expression(SymEngine::symbol("Error"));
        }

        // 百分号 (%)
        if (op == "Percent") {
             return parseAST(ast[1], isRad, true) / Expression(100);
        }
        
        // 阶乘
        if (op == "Factorial") {
            if (ast.size() == 2) {
                Expression arg = parseAST(ast[1], isRad, true);
                try {
                    double val = SymEngine::eval_double(arg);
                    if (val < 0 && std::floor(val) == val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Factorial of negative integer intercepted.");
                    }
                    
                    // 获取量级、防御并抛出结果
                    if (val > 5000 && std::floor(val) == val) {
                        double magnitude = FastMath::getFactorialMagnitude(val);
                        FastMath::checkOverflow(magnitude);
                        throw FastResultException(FastMath::formatScientific(magnitude));
                    }
                } catch (const FastResultException&) { throw; }
                  catch (const CalcException&) { throw; }
                  catch (...) {}

                return Expression(SymEngine::gamma((arg + Expression(1)).get_basic()));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Factorial node length.");
        }
        
        // 组合
        if (op == "nCr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true);
                Expression r = parseAST(ast[2], isRad, true);
                
                try {
                    double n_val = SymEngine::eval_double(n);
                    double r_val = SymEngine::eval_double(r);
                    
                    // 组合定义域检查
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid nCr arguments");
                    }

                    // 极速计算：log(n!) - log(r!) - log((n-r)!)
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(r_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        
                        if (mag > 15.0) {
                            throw FastResultException(FastMath::formatScientific(mag));
                        }
                    }
                } catch (const FastResultException&) { throw; }
                  catch (const CalcException&) { throw; }
                  catch (...) {}

                Expression num(SymEngine::gamma((n + Expression(1)).get_basic()));
                Expression den1(SymEngine::gamma((r + Expression(1)).get_basic()));
                Expression den2(SymEngine::gamma((n - r + Expression(1)).get_basic()));
                return num / (den1 * den2);
            }
            return Expression(SymEngine::symbol("Error"));
        }

       // 排列
        if (op == "nPr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true);
                Expression r = parseAST(ast[2], isRad, true);
                
                try {
                    double n_val = SymEngine::eval_double(n);
                    double r_val = SymEngine::eval_double(r);
                    
                    // 排列定义域检查
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid nPr arguments");
                    }

                    // 【极速计算】：log(n!) - log((n-r)!)
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        
                        // 只有当排列结果大于 10^15 时才以科学计数法拦截，否则让引擎算出精确值
                        if (mag > 15.0) {
                            throw FastResultException(FastMath::formatScientific(mag));
                        }
                    }
                } catch (const FastResultException&) { throw; }
                  catch (const CalcException&) { throw; }
                  catch (...) {}

                Expression num(SymEngine::gamma((n + Expression(1)).get_basic()));
                Expression den(SymEngine::gamma((n - r + Expression(1)).get_basic()));
                return num / den;
            }
            return Expression(SymEngine::symbol("Error"));
        }

        // 三角函数
        if (op == "Sin" || op == "Cos" || op == "Tan") {
            if (ast.size() < 2) return Expression(SymEngine::symbol("Error"));
            Expression arg = parseAST(ast[1], isRad, true); 
            if (!isRad) arg = arg * Expression(SymEngine::pi) / Expression(180);
            
            if (op == "Sin") return SymEngine::sin(arg);
            if (op == "Cos") return SymEngine::cos(arg);
            if (op == "Tan") return SymEngine::tan(arg);
        }

        // 反三角函数
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
        
        // 对数
        if (op == "Ln") return SymEngine::log(parseAST(ast[1], isRad, true));
        if (op == "Log") {
            if (ast.size() == 3) return SymEngine::log(parseAST(ast[1], isRad, true), parseAST(ast[2], isRad, true));
            return SymEngine::log(parseAST(ast[1], isRad, true), Expression(10));
        }
        if (op == "Log10" || op == "Lg") {
            // 利用换底公式：lg(x) = ln(x) / ln(10)
            Expression num(SymEngine::log(parseAST(ast[1], isRad, true).get_basic()));
            Expression den(SymEngine::log(Expression(10).get_basic()));
            return num / den;
        }
        
        return Expression(SymEngine::symbol("Unknown\\_" + op));
    }
    return Expression(SymEngine::symbol("Invalid\\_Node"));
}

// 将超长整数折叠为 LaTeX 科学计数法
std::string formatLargeIntegerToScientific(const std::string& intStr) {
    bool isNeg = (intStr[0] == '-');
    size_t firstDigitPos = isNeg ? 1 : 0;
    std::string firstDigit = intStr.substr(firstDigitPos, 1);
    
    // 截取前 5 位作为小数部分，并去掉末尾多余的 0
    std::string restDigits = intStr.substr(firstDigitPos + 1, 5); 
    restDigits.erase(restDigits.find_last_not_of('0') + 1, std::string::npos);
    
    long long realExp = intStr.length() - firstDigitPos - 1;
    std::string sign = isNeg ? "-" : "";
    
    if (restDigits.empty()) {
        return sign + firstDigit + "\\times 10^{" + std::to_string(realExp) + "}";
    } else {
        return sign + firstDigit + "." + restDigits + "\\times 10^{" + std::to_string(realExp) + "}";
    }
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
        
        // 精度控制逻辑 
        bool isGlobalExact = (precision == -3 || precision == -4);
        Expression expr = parseAST(ast, isRad, isGlobalExact);
        
        expr = Expression(SymEngine::expand(expr.get_basic()));

        if (precision == -1 || precision == -3) {
            // 【新增】：检查是否为整数，且长度是否超过 15 位
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
            // 带分数拆解逻辑
            std::string s = expr.get_basic()->__str__();
            
            // 确保这是个纯粹的分数 (不包含 x, pi, 根号等)
            bool is_simple_frac = true;
            for (char c : s) {
                if (!isdigit(c) && c != '/' && c != '-') { is_simple_frac = false; break; }
            }
            
            size_t slash = s.find('/');
            if (is_simple_frac && slash != std::string::npos) {
                try {
                    // 将字符串提取为安全的长整型进行除法运算
                    long long num = std::stoll(s.substr(0, slash));
                    long long den = std::stoll(s.substr(slash + 1));
                    
                    long long integer_part = num / den;           // 提取整数部分
                    long long remainder = std::abs(num % den);    // 提取余数部分绝对值
                    
                    if (integer_part != 0 && remainder != 0) {
                        // 组装带分数 LaTeX (比如: -2\frac{3}{5})
                        std::string sign = (num < 0) ? "-" : "";
                        result_msg = sign + std::to_string(std::abs(integer_part)) + "\\frac{" + std::to_string(remainder) + "}{" + std::to_string(den) + "}";
                    } else if (remainder == 0) {
                        result_msg = std::to_string(integer_part);
                    } else {
                        // 如果本来就是真分数，按原样输出
                        if (num < 0) result_msg = "-\\frac{" + std::to_string(std::abs(num)) + "}{" + std::to_string(den) + "}";
                        else result_msg = "\\frac{" + std::to_string(num) + "}{" + std::to_string(den) + "}";
                    }
                } catch (...) { // 遇到超大数字溢出时，安全兜底退回假分数
                    result_msg = SymEngine::latex(*expr.get_basic());
                }
            } else { // 如果不是纯数字分数（比如含有 pi），原样输出
                result_msg = SymEngine::latex(*expr.get_basic());
            }
            
        } else {
            // 小数模式
            try {
                // 如果是超大数字，eval_double 会抛出异常，触发 catch 降级
                double float_val = SymEngine::eval_double(*expr.get_basic());
                
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
            } catch (...) {
                // 【修改兜底机制】：退回符号输出前，先检查是不是超大整数
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
            }
        }
        // =========================================================
        
    } catch (const FastResultException& e) {
        // 【第一优先级】：一定要加在这里！接住我们的直通车结果
        result_msg = e.what();
    } catch (const CalcException& e) {
        // 【第二优先级】：捕获除以0、溢出等业务逻辑错误
        result_msg = e.getFrontEndMessage();
    } catch (const std::exception& e) {
        // 【第三优先级】：底层库的错误兜底
        result_msg = "Error:Domain"; 
    } catch (...) {
        // 终极防线兜底，防止应用在 HarmonyOS 层直接闪退 (Crash)
        result_msg = "Error:Unknown";
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