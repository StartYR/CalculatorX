/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file formatter.h
 * @description 结果格式化模块，负责大整数科学记数法与 LaTeX 输出格式化
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#pragma once
#include <string>

std::string formatLargeIntegerToScientific(const std::string& intStr);