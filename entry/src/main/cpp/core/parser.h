/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file parser.h
 * @description MathJSON AST 递归下降解析器，将 JSON AST 转换为 SymEngine 表达式
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

#pragma once
#include "json.hpp"
#include <symengine/expression.h>

// 1. 计算模式枚举
enum class CalcMode {
    STANDARD = 0,
    MATRIX = 1,
    EQUATION = 2,
    GRAPHING = 3
};

// 2. 全局状态上下文结构体 (指令下发 + 状态收集)
struct CalcContext {
    bool isRad = false;
    bool preferExact = false;
    bool hasDMS = false;
    bool hasChangeOfBaseLog = false;
    CalcMode mode = CalcMode::STANDARD;
};

// 3. 全局解析器入口
SymEngine::Expression parseAST(const nlohmann::json& ast, CalcContext& ctx);
