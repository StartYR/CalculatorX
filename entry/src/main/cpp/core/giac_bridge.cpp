/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file giac_bridge.cpp
 * @description Giac CAS 引擎桥接层，负责符号表达式求值与命令构建
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

#include "giac_bridge.h"
#include "parser.h"
#include "../utils/FormatUtils.h"
#include "giac.h"

using json = nlohmann::json;
using SymEngine::Expression;

std::string evaluateWithGiac(const std::string& mathExpression) {
    try {
        giac::context ctx;
        giac::gen g(mathExpression, &ctx);
        giac::gen result = giac::eval(g, &ctx);
        
        std::string resStr = result.print(&ctx);
        
        // Giac 的 LaTeX/字符串输出两端带有双引号，这里将其剥离
        if (resStr.size() >= 2 && resStr.front() == '"' && resStr.back() == '"') {
            resStr = resStr.substr(1, resStr.size() - 2);
        }
        
        return resStr;
    } catch (const std::exception& e) {
        return "Error: " + std::string(e.what());
    } catch (...) {
        return "Error: Giac Unknown";
    }
}

std::string buildGiacCommand(const json& ast) {
    try {
        if (ast.is_array() && ast.size() >= 3 && ast[0] == "Limit") {
            json funcNode = ast[1]; 
            json targetNode = ast[2]; 

            std::string exprStr = "";
            std::string varStr = "x";

            // 1. 解析函数体与变量
            if (funcNode.is_array() && funcNode.size() >= 3 && funcNode[0] == "Function") {
                bool dummyDMS = false;
                // 复用你的 SymEngine 解析器生成标准的符号表达式
                Expression expr = parseAST(funcNode[1], true, true, dummyDMS);
                exprStr = expr.get_basic()->__str__(); 
                
                if (funcNode[2].is_string()) {
                    varStr = funcNode[2].get<std::string>(); 
                }
            }

            // 2. 解析趋近值
            bool dummyDMS = false;
            Expression targetExpr = parseAST(targetNode, true, true, dummyDMS);
            std::string targetStr = targetExpr.get_basic()->__str__();

            // 3. 语法适配替换
            // 修复乘方语法适配
            replaceAll(exprStr, "**", "^");
            replaceAll(targetStr, "**", "^");
            // 将 SymEngine 可能会解析的无穷大符号映射给 Giac
            replaceAll(targetStr, "Infinity", "infinity");
            replaceAll(targetStr, "\\infty", "infinity");

            // 4. 使用 latex() 函数包裹，让 Giac 计算后直接返回供屏幕渲染的 LaTeX
            return "latex(limit(" + exprStr + ", " + varStr + ", " + targetStr + "))";
        }
    } catch (...) {
        return ""; 
    }
    return "";
}