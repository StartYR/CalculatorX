/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file FormatUtils.cpp
 * @description 统一格式化与字符串工具中枢
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "FormatUtils.h"

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