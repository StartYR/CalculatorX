/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file FormatUtils.h
 * @description 统一格式化与字符串工具中枢
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#pragma once
#include <string>

// 全局查找替换
void replaceAll(std::string& str, const std::string& from, const std::string& to);

// 大整数科学记数法排版
std::string formatLargeIntegerToScientific(const std::string& intStr);