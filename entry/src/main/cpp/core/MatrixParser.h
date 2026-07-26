/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file MatrixParser.h
 * @description 集中式矩阵运算路由与解析器
 * @author 易睿 (Yi Rui)
 * @date 2026/7/26 17:50
*/

#ifndef MATRIX_PARSER_H
#define MATRIX_PARSER_H

#include <../include/json.hpp>
#include <symengine/expression.h>

namespace MatrixParser {

    /**
     * @brief 矩阵安检机：嗅探当前 AST 节点是否涉及矩阵运算
     * @param ast 当前的 JSON 语法树节点
     * @return true 如果包含矩阵或矩阵专属算子
     */
    bool isMatrixExpression(const nlohmann::json& ast);

    /**
     * @brief 矩阵专属处理器：集中处理加减乘及哈达玛积
     */
    SymEngine::Expression handle(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS);

} // namespace MatrixParser

#endif // MATRIX_PARSER_H