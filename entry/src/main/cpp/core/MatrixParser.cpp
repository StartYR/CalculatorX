/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file MatrixParser.cpp
 * @description 请在此处输入文件描述...
 * @author 易睿 (Yi Rui)
 * @date 2026/7/26 17:50
*/

#include "MatrixParser.h"
#include "parser.h" // 预留：后续处理子节点时需要调回主解析器
#include <string>

namespace MatrixParser {

bool isMatrixExpression(const nlohmann::json& ast) {
    if (!ast.is_array() || ast.empty() || !ast[0].is_string()) return false;
    
    std::string op = ast[0].get<std::string>();
    
    // 1. 拦截明确的矩阵专属算子
    if (op == "Ring" || op == "MyDet" || op == "Det" || op == "MyTrace" || op == "Trace" || 
        op == "MyRref" || op == "rref" || op == "MyEig" || op == "eig" || op == "MyRank" || op == "rank") {
        return true;
    }

    // 2. 高效嗅探子节点是否包含矩阵（绝对不使用 dump() 序列化）
    for (size_t i = 1; i < ast.size(); ++i) {
        if (ast[i].is_string()) {
            std::string s = ast[i].get<std::string>();
            // 嗅探单位矩阵
            if (s.find("I_upright_") == 0) return true;
        }
        // 嗅探普通显式矩阵
        if (ast[i].is_array() && !ast[i].empty() && ast[i][0] == "Matrix") {
            return true;
        }
    }
    
    return false;
}

SymEngine::Expression handle(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS) {
    // 第一步占位，暂时返回一个空符号，下一步我们再填充流水线
    return SymEngine::Expression(SymEngine::symbol("MAGICMAT_Placeholder"));
}

} // namespace MatrixParser