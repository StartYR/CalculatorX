/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file FormatUtils.cpp
 * @description 统一格式化与字符串工具中枢
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "FormatUtils.h"
#include <iomanip>
#include <sstream>
#include <cmath>
#include <regex>

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); 
    }
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

std::string formatDMS(double float_val, bool isRad) {
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
    
    if (s >= 59.99995) { s = 0.0; m += 1; }
    if (m >= 60) { m = 0; d += 1; }
    
    std::ostringstream s_oss;
    s_oss << std::fixed << std::setprecision(4) << s;
    std::string s_str = s_oss.str();
    s_str.erase(s_str.find_last_not_of('0') + 1, std::string::npos);
    if (!s_str.empty() && s_str.back() == '.') s_str.pop_back();
    
    return sign + std::to_string(d) + "^{\\circ}" + std::to_string(m) + "^{\\prime}" + s_str + "^{\\prime\\prime}";
}

std::string formatFraction(const std::string& s) {
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
                return sign + std::to_string(std::abs(integer_part)) + "\\frac{" + std::to_string(remainder) + "}{" + std::to_string(den) + "}";
            } else if (remainder == 0) {
                return std::to_string(integer_part);
            } else {
                if (num < 0) return "-\\frac{" + std::to_string(std::abs(num)) + "}{" + std::to_string(den) + "}";
                else return "\\frac{" + std::to_string(num) + "}{" + std::to_string(den) + "}";
            }
        } catch (...) { return ""; }
    }
    return "";
}

std::string formatFloat(double float_val, int precision) {
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
            return a + "\\times 10^{" + std::to_string(b) + "}";
        }
        return s;
    } else {
        std::ostringstream oss;
        if (precision == -2) {
            oss << std::fixed << std::setprecision(12) << float_val;
            std::string str = oss.str();
            str.erase(str.find_last_not_of('0') + 1, std::string::npos);
            if (!str.empty() && str.back() == '.') str.pop_back();
            return str;
        } else {
            oss << std::fixed << std::setprecision(precision) << float_val;
            return oss.str();
        }
    }
}

void applyGlobalUIFormatting(std::string& result_msg) {
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
    replaceAll(result_msg, "MAGICGIACRESULT", "");
    replaceAll(result_msg, "infinity", "\\infty");
    replaceAll(result_msg, "undef", "\\text{undefined}");
    replaceAll(result_msg, "\\log", "\\ln");
    replaceAll(result_msg, "j", "i");
    
    // 处理不定积分
    replaceAll(result_msg, "MAGIC\\_CONST\\_C", "\\mathbf{C}");
    replaceAll(result_msg, "MAGIC_CONST_C", "\\mathbf{C}");
    
    // 积分常数排版优化，处理常数 C 被代数引擎排在最前面的情况，将其移到末尾
    if (result_msg.find("\\mathbf{C}") == 0) {
        if (result_msg.find("\\mathbf{C} + ") == 0) {
            result_msg = result_msg.substr(13) + " + \\mathbf{C}";
        } else if (result_msg.find("\\mathbf{C}+") == 0) {
            result_msg = result_msg.substr(11) + " + \\mathbf{C}";
        } else if (result_msg.find("\\mathbf{C} - ") == 0) {
            result_msg = "-" + result_msg.substr(13) + " + \\mathbf{C}";
        } else if (result_msg.find("\\mathbf{C}-") == 0) {
            result_msg = "-" + result_msg.substr(11) + " + \\mathbf{C}";
        }
    }
    
    try {
        std::regex array_start(R"(\\left[\[\(]\\begin\{(array|matrix)\}(\{[clr]+\})?)");
        result_msg = std::regex_replace(result_msg, array_start, "\\begin{bmatrix}");
        replaceAll(result_msg, "\\end{array}\\right]", "\\end{bmatrix}");
        replaceAll(result_msg, "\\end{array}\\right)", "\\end{bmatrix}");
        replaceAll(result_msg, "\\end{matrix}\\right]", "\\end{bmatrix}");
        replaceAll(result_msg, "\\end{matrix}\\right)", "\\end{bmatrix}");
    } catch (...) {}
}