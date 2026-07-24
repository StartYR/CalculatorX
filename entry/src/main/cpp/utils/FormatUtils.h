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

// 度分秒格式化
std::string formatDMS(double float_val, bool isRad);

// 分数格式化
std::string formatFraction(const std::string& s);

// 浮点数科学计数法与精度排版
std::string formatFloat(double float_val, int precision);

// 全局 UI 统一美化（正则清理、伪符号剥离）
void applyGlobalUIFormatting(std::string& result_msg);