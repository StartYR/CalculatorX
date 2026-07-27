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

// 1. 定义计算模式枚举
enum class CalcMode {
    STANDARD = 0,
    MATRIX = 1,
    EQUATION = 2,
    GRAPHING = 3
};

// 2. 状态上下文结构体
struct CalcContext {
    bool isRad = false;
    bool preferExact = false;
    bool hasDMS = false;
    CalcMode mode = CalcMode::STANDARD;
};

// 3. 全局入口 (engine.cpp 调用)
SymEngine::Expression parseAST(const nlohmann::json& ast, CalcContext& ctx);

SymEngine::Expression parseAST(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS);