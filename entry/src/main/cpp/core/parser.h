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

SymEngine::Expression parseAST(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS);