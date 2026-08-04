/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEngine.h
 * @description 函数渲染核心 (集成符号伴生导数雷达、极限边界嗅探与 RPN 自适应递归采样)
 * @author 易睿 (Yi Rui)
 * @date 2026/8/2 20:52
*/
#pragma once
#include <vector>
#include <string>
#include <symengine/expression.h>

// 迷你虚拟机的核心指令集 (RPN 操作码)
enum class OpCode {
    VAR_X, VAR_Y, VAR_T, VAR_THETA, CONST_VAL, // 多变量支持
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
    // 双核架构：支持主表达式和伴生表达式
    std::vector<Instruction> instructions;
    std::vector<Instruction> deriv_instructions; 
    std::vector<Instruction> instructions2;       // 专用于 y(t) 或独立点的 y
    std::vector<Instruction> deriv_instructions2; 

    // 让编译器把指令推入指定的容器，而不是写死
    void compileNode(const SymEngine::RCP<const SymEngine::Basic>& node, std::vector<Instruction>& target_inst);
    
    // 支持同时传入 x, y, t, theta
    double executeMachine(double x, double y, double t, double theta, const std::vector<Instruction>& inst_list) const;

    // 自适应递归采样器
    void sampleRecursive(double x1, double y1, double x2, double y2, int depth, double error_threshold, double jump_threshold, std::vector<double>& result) const;
    
public:
    // 预编译表达式 (支持传入双表达式，第二个可为空)
    void compile(const SymEngine::Expression& expr1, const SymEngine::Expression& expr2 = SymEngine::Expression(0));
    
    // 极速求值接口
    double evaluate(double x, double y = 0, double t = 0, double theta = 0) const;
    double evaluateDeriv(double x, double y = 0, double t = 0, double theta = 0) const; 
    
    // 第二套指令的极速求值
    double evaluate_2(double x, double y = 0, double t = 0, double theta = 0) const;
    double evaluateDeriv_2(double x, double y = 0, double t = 0, double theta = 0) const;
    
    // 原有的静态生成接口和单变量快速采样接口
    static std::vector<double> generatePoints(const SymEngine::Expression& expr, double xMin, double xMax, int pointsCount);
    std::vector<double> generatePointsFast(double xMin, double xMax, int pointsCount) const;
    
    // ==================== 多形态函数采样器 ====================
    // 参数方程 x(t), y(t)
    std::vector<double> generateParametric(double tMin, double tMax, int pointsCount) const;
    
    // 极坐标方程 r(θ)
    std::vector<double> generatePolar(double thetaMin, double thetaMax, int pointsCount) const;
    
    // 独立点 (x, y)
    std::vector<double> generatePoint() const;
};

