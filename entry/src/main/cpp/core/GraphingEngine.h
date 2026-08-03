/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEngine.h
 * @description 自定义逆波兰 (RPN) 极速求值机
 * @author 易睿 (Yi Rui)
 * @date 2026/8/2 20:52
*/

#pragma once
#include <vector>
#include <string>
#include <symengine/expression.h>

// 迷你虚拟机的核心指令集 (RPN 操作码)
enum class OpCode {
    VAR_X, CONST_VAL,
    ADD, SUB, MUL, DIV, POW,
    SIN, COS, TAN, ASIN, ACOS, ATAN,
    SINH, COSH, TANH,
    LN, LOG10, SQRT, ABS
};

// 单条执行指令
struct Instruction {
    OpCode op;
    double value = 0.0; // 仅当 op == CONST_VAL 时有效
};

class GraphingEngine {
private:
    std::vector<Instruction> instructions;

    // 降维编译器：将 3D 的 SymEngine AST 压平成 1D 的机器指令数组
    void compileNode(const SymEngine::RCP<const SymEngine::Basic>& node);

    // 自适应递归采样器
    void sampleRecursive(double x1, double y1, double x2, double y2, int depth, double error_threshold, double jump_threshold, std::vector<double>& result) const;

public:
    // 对外接口：预编译表达式
    void compile(const SymEngine::Expression& expr);
    
    // 对外接口：极速求值（零内存分配）
    double evaluate(double x) const;
    
    // 对外接口：返回原生 double 数组
    static std::vector<double> generatePoints(const SymEngine::Expression& expr, double xMin, double xMax, int pointsCount);
    
    // 使用当前对象已编译好的指令进行采样
    std::vector<double> generatePointsFast(double xMin, double xMax, int pointsCount) const;
};