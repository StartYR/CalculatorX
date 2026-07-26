/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file MatrixParser.cpp
 * @description 集中式矩阵运算路由与解析器
 * @author 易睿 (Yi Rui)
 * @date 2026/7/26 17:50
*/

#include "MatrixParser.h"
#include "parser.h"
#include "../utils/FormatUtils.h" 
#include "ErrorHandler.h"
#include <string>
#include <vector>

namespace MatrixParser {

// 1. 海关安检机 (Sniffer)
bool isMatrixExpression(const nlohmann::json& ast) {
    if (!ast.is_array() || ast.empty() || !ast[0].is_string()) return false;
    
    std::string op = ast[0].get<std::string>();
    
    // 拦截明确的矩阵专属算子
    if (op == "Ring" || op == "MyDet" || op == "Det" || op == "MyTrace" || op == "Trace" || 
        op == "MyRref" || op == "rref" || op == "MyEig" || op == "eig" || op == "MyRank" || op == "rank") {
        return true;
    }

    // 嗅探子节点是否包含矩阵
    for (size_t i = 1; i < ast.size(); ++i) {
        if (ast[i].is_string() && ast[i].get<std::string>().find("I_upright_") == 0) return true;
        if (ast[i].is_array() && !ast[i].empty() && ast[i][0] == "Matrix") return true;
    }
    return false;
}

// 2. 辅助函数：集中提取矩阵维度
static std::pair<int, int> getMatrixDim(const nlohmann::json& node) {
    if (node.is_string()) {
        std::string s = node.get<std::string>();
        if (s.find("I_upright_") == 0) {
            try { return {std::stoi(s.substr(10)), std::stoi(s.substr(10))}; } catch (...) {}
        }
    }
    if (node.is_array() && node.size() >= 2 && node[0] == "Matrix") {
        auto listNode = node[1];
        if (listNode.is_array() && !listNode.empty() && listNode[0] == "List") {
            int r = listNode.size() - 1;
            int c = (r > 0 && listNode[1].is_array() && listNode[1][0] == "List") ? listNode[1].size() - 1 : 0;
            return {r, c};
        }
    }
    return {0, 0};
}

// 3. 辅助函数：净化流水线 (拦截伪装的平级算子，完成上标缝合)
static std::vector<std::string> getCleanArgs(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS) {
    std::vector<std::string> args;
    for (size_t i = 1; i < ast.size(); ++i) {
        
        // 1. 拦截你之前设计的平级伪装算子 (TranOp, InvOp 等)
        if (ast[i].is_string()) {
            std::string s = ast[i].get<std::string>();
            if (!args.empty()) { // 确保前面有矩阵
                if (s == "TranOp") { args.back() = "tran(" + args.back() + ")"; continue; }
                if (s == "ConjTranOp") { args.back() = "trn(" + args.back() + ")"; continue; }
                if (s == "InvOp") { args.back() = "inv(" + args.back() + ")"; continue; }
            }
        }
        
        // 2. 拦截我们新增的泛型乘方替身 (MatPowOp)
        if (ast[i].is_array() && ast[i].size() >= 3 && ast[i][0] == "Power" && 
            ast[i][1].is_string() && ast[i][1].get<std::string>() == "MatPowOp") {
            if (!args.empty()) {
                bool dummy = false;
                std::string expStr = parseAST(ast[i][2], isRad, preferExact, dummy).get_basic()->__str__();
                replaceAll(expStr, "**", "^");
                
                args.back() = "(" + args.back() + ") ^ (" + expStr + ")";
                continue; // 缝合成功，跳过当前循环
            }
        }
        
        // 3. 常规节点净化
        bool dummy = false;
        std::string s = parseAST(ast[i], isRad, preferExact, dummy).get_basic()->__str__();
        replaceAll(s, "MAGICMAT", ""); 
        args.push_back(s);
    }
    return args;
}

// 4. 矩阵核心调度中心 (Dispatcher)
SymEngine::Expression handle(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS) {
    std::string op = ast[0].get<std::string>();
    
    // 一键获取所有彻底净化好的参数字符串！
    auto args = getCleanArgs(ast, isRad, preferExact, hasDMS);

    // 单参数算子
    if (op == "MyDet" || op == "Det") return SymEngine::Expression(SymEngine::symbol("MAGICMATdet(" + args[0] + ")"));
    if (op == "MyTrace" || op == "Trace") return SymEngine::Expression(SymEngine::symbol("MAGICMATtrace(" + args[0] + ")"));
    if (op == "MyRref" || op == "rref") return SymEngine::Expression(SymEngine::symbol("MAGICMATrref(" + args[0] + ")"));
    if (op == "MyEig" || op == "eig") return SymEngine::Expression(SymEngine::symbol("MAGICMATeigenvals(" + args[0] + ")"));
    if (op == "MyRank" || op == "rank") return SymEngine::Expression(SymEngine::symbol("MAGICMATrank(" + args[0] + ")"));

    // 乘方与转置
    if (op == "Power" && args.size() == 2) {
        if (ast[2].is_string()) { // 判断 AST 的原始未解析形态
            std::string expStr = ast[2].get<std::string>(); 
            if (expStr == "T_upright") return SymEngine::Expression(SymEngine::symbol("MAGICMATtran(" + args[0] + ")"));
            if (expStr == "H_upright") return SymEngine::Expression(SymEngine::symbol("MAGICMATtrn(" + args[0] + ")"));
        }
        // 普通矩阵乘方 (如 A^2, A^-1 甚至逆矩阵)
        return SymEngine::Expression(SymEngine::symbol("MAGICMAT((" + args[0] + ") ^ (" + args[1] + "))"));
    }

    // 哈达玛积
    if (op == "Ring" && args.size() == 2) {
        auto dim1 = getMatrixDim(ast[1]); auto dim2 = getMatrixDim(ast[2]);
        if (dim1.first != 0 && dim2.first != 0 && dim1 != dim2) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "哈达玛积要求矩阵维度必须完全一致");
        return SymEngine::Expression(SymEngine::symbol("MAGICMAThadamard(" + args[0] + ", " + args[1] + ")"));
    }

    // 加法
    if (op == "Add") {
        std::pair<int, int> targetDim = {-1, -1};
        std::string res = "";
        for (size_t i = 0; i < args.size(); ++i) {
            auto dim = getMatrixDim(ast[i + 1]);
            if (dim.first != 0 && dim.second != 0) {
                if (targetDim.first == -1) targetDim = dim;
                else if (targetDim != dim) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Matrix dimension mismatch");
            }
            res += args[i];
            if (i < args.size() - 1) res += " + ";
        }
        return SymEngine::Expression(SymEngine::symbol("MAGICMAT(" + res + ")"));
    }

    // 减法与取反
    if (op == "Subtract" || op == "Negate") {
        if (args.size() == 2) {
            auto dim1 = getMatrixDim(ast[1]); auto dim2 = getMatrixDim(ast[2]);
            if (dim1.first != 0 && dim2.first != 0 && dim1 != dim2) throw CalcException(CalcErrorCode::DOMAIN_ERROR, "Matrix dimension mismatch");
            return SymEngine::Expression(SymEngine::symbol("MAGICMAT(" + args[0] + " - " + args[1] + ")"));
        }
        if (args.size() == 1) return SymEngine::Expression(SymEngine::symbol("MAGICMAT(-" + args[0] + ")")); // Negate
    }

    // 乘法 (包括普通 Multiply 和隐式 Tuple)
    if (op == "Multiply" || op == "Tuple")  {
        std::string res = "";
        for (size_t i = 0; i < args.size(); ++i) {
            res += args[i];
            if (i < args.size() - 1) res += " * ";
        }
        return SymEngine::Expression(SymEngine::symbol("MAGICMAT(" + res + ")"));
    }

    return SymEngine::Expression(SymEngine::symbol("MAGICMAT_Fallback"));
}

} // namespace MatrixParser