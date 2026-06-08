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

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); 
    }
}

Expression parseAST(const json& ast, bool isRad, bool preferExact = false) {
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
        if (s == "NaN") {
            throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Frontend folded to NaN");
        }
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
            
        } catch (const std::out_of_range&) {
            throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Astronomical explosion intercepted");
        } catch (...) {
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid num object format");
        }
    }
    
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        std::string op = ast[0].get<std::string>();

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

        if (op == "Sqrt") return SymEngine::sqrt(parseAST(ast[1], isRad, true));
        if (op == "Root") return SymEngine::pow(parseAST(ast[1], isRad, true), Expression(1) / parseAST(ast[2], isRad, true));
        if (op == "Abs") return SymEngine::abs(parseAST(ast[1], isRad, true));
        if (op == "Power") {
            Expression base = parseAST(ast[1], isRad, true);
            Expression exp = parseAST(ast[2], isRad, true);
            
            try {
                if (SymEngine::is_a<SymEngine::Integer>(*base.get_basic()) && 
                    SymEngine::is_a<SymEngine::Integer>(*exp.get_basic())) {
                    
                    double b = SymEngine::eval_double(base);
                    double e = SymEngine::eval_double(exp);
                    
                    if (b > 0) {
                        double magnitude = e * std::log10(b);
                        
                        if (std::isinf(magnitude) || std::abs(magnitude) > 9e18) {
                            throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Exceeds 64-bit limits");
                        }
                        
                        if (std::abs(magnitude) > 10000) {
                            return FastMath::buildBigScientificNode(magnitude);
                        }
                    }
                }
            } catch (const CalcException& e) { 
                throw; // 原封不动抛出我们的溢出异常
            } catch (const std::exception& e) {
                // 将 eval_double 翻译为超时或算力越界
                throw CalcException(CalcErrorCode::TIMEOUT_ERROR, "Calculation payload exceeded engine limits");
            } catch (...) {
                throw CalcException(CalcErrorCode::TIMEOUT_ERROR, "Unknown catastrophic evaluation error");
            }
            
            return SymEngine::pow(base, exp);
        }
        
        if (op == "GCD" || op == "LCM" || op == "Lcm" || op == "lcm") {
            if (ast.size() == 3) {
                if (ast[1].is_number() && ast[2].is_number()) {
                    long long a = static_cast<long long>(std::abs(ast[1].get<double>()));
                    long long b = static_cast<long long>(std::abs(ast[2].get<double>()));
                    if (op == "GCD") return Expression(std::gcd(a, b));
                    else return Expression(std::lcm(a, b));
                } else return Expression(SymEngine::symbol("Error\\_Int\\_Only")); 
            }
            return Expression(SymEngine::symbol("Error"));
        }

        if (op == "Mod" || op == "Modulo") {
            if (ast.size() == 3) {
                Expression a = parseAST(ast[1], isRad, true);
                Expression b = parseAST(ast[2], isRad, true);
                return a - b * SymEngine::floor(a / b);
            }
            return Expression(SymEngine::symbol("Error"));
        }

        if (op == "Percent") {
             return parseAST(ast[1], isRad, true) / Expression(100);
        }
        
        // 度分秒
        if (op == "dms" || op == "Dms") {
            if (ast.size() == 4) {
                Expression d = parseAST(ast[1], isRad, true);
                Expression m = parseAST(ast[2], isRad, true);
                Expression s = parseAST(ast[3], isRad, true);
                
                try {
                    // 核心公式：度 + 分/60 + 秒/3600
                    Expression total_deg = d + m / Expression(60) + s / Expression(3600);
                    
                    if (isRad) {
                        // 如果当前是弧度制，将度数转换为弧度再参与后续计算
                        return total_deg * Expression(SymEngine::pi) / Expression(180);
                    } else {
                        // 如果当前是角度制，它本身代表的就是度数，直接返回
                        return total_deg;
                    }
                } catch (...) {
                    throw CalcException(CalcErrorCode::DMS_FORMAT_ERROR, "DMS Calculation Failed");
                }
            }
            throw CalcException(CalcErrorCode::DMS_FORMAT_ERROR, "Invalid DMS Length");
        }
        
        if (op == "Factorial") {
            if (ast.size() == 2) {
                Expression arg = parseAST(ast[1], isRad, true);
                try {
                    double val = SymEngine::eval_double(arg);
                    if (val < 0 && std::floor(val) == val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Negative Factorial");
                    }
                    if (val > 5000 && std::floor(val) == val) {
                        double magnitude = FastMath::getFactorialMagnitude(val);
                        FastMath::checkOverflow(magnitude);
                        return FastMath::buildBigScientificNode(magnitude);
                    }
                } catch (const CalcException&) { throw; } 
                  catch (const std::exception&) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                  catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                return Expression(SymEngine::gamma((arg + Expression(1)).get_basic()));
            }
            throw CalcException(CalcErrorCode::SYNTAX_ERROR, "Invalid Factorial length.");
        }
        
        if (op == "nCr") {
            if (ast.size() == 3) {
                Expression n = parseAST(ast[1], isRad, true);
                Expression r = parseAST(ast[2], isRad, true);
                try {
                    double n_val = SymEngine::eval_double(n);
                    double r_val = SymEngine::eval_double(r);
                    
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid nCr args");
                    }
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(r_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        if (mag > 15.0) return FastMath::buildBigScientificNode(mag);
                    }
                } catch (const CalcException&) { throw; } 
                  catch (const std::exception&) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                  catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }

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
                try {
                    double n_val = SymEngine::eval_double(n);
                    double r_val = SymEngine::eval_double(r);
                    if (n_val < 0 || r_val < 0 || r_val > n_val || std::floor(n_val) != n_val || std::floor(r_val) != r_val) {
                        throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Invalid nPr args");
                    }
                    if (n_val > 5000) {
                        double mag = FastMath::getFactorialMagnitude(n_val) - FastMath::getFactorialMagnitude(n_val - r_val);
                        FastMath::checkOverflow(mag);
                        if (mag > 15.0) return FastMath::buildBigScientificNode(mag);
                    }
                } catch (const CalcException&) { throw; } 
                  catch (const std::exception&) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }
                  catch (...) { throw CalcException(CalcErrorCode::TIMEOUT_ERROR); }

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
        if (op == "Log10" || op == "Lg") {
            Expression num(SymEngine::log(parseAST(ast[1], isRad, true).get_basic()));
            Expression den(SymEngine::log(Expression(10).get_basic()));
            return num / den;
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
        if (ast.is_string()) ast = json::parse(ast.get<std::string>()); 
        
        bool isGlobalExact = (precision == -3 || precision == -4);
        Expression expr = parseAST(ast, isRad, isGlobalExact);
        
        std::string expr_str = expr.get_basic()->__str__();
        if (expr_str.find("MAGICBASETEN") == std::string::npos) {
            expr = Expression(SymEngine::expand(expr.get_basic()));
        }

        if (precision == -1 || precision == -3) {
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
        // 【终极异常翻译】：接住任何 SymEngine 在底层挣扎时抛出的系统级错误
        // 例如：内存分配失败(OOM)、死循环被打破、极其夸张的多项式展开失败等，统一转化为"超时/算力超界"
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