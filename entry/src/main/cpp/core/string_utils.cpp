/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file string_utils.cpp
 * @description 字符串工具函数，提供全局查找替换等基础字符串操作
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "string_utils.h"

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); 
    }
}