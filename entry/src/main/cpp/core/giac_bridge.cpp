/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file giac_bridge.cpp
 * @description Giac CAS 引擎桥接层，负责符号表达式求值与命令构建
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#include "giac_bridge.h"
#include "giac.h"

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