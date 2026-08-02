/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEngine.cpp
 * @description 自定义逆波兰 (RPN) 极速求值机
 * @author 易睿 (Yi Rui)
 * @date 2026/8/2 20:52
*/

#include "GraphingEngine.h"
#include <symengine/add.h>
#include <symengine/mul.h>
#include <symengine/pow.h>
#include <symengine/functions.h>
#include <symengine/symbol.h>
#include <symengine/constants.h>
#include <symengine/real_double.h>
#include <symengine/integer.h>
#include <symengine/eval_double.h>
#include <cmath>
#include <symengine/rational.h>
#include <symengine/number.h>
#include "utils/Logger.h"

using namespace SymEngine;

// ==================== 阶段一：降维编译器 ====================
void GraphingEngine::compileNode(const RCP<const Basic>& node) {
//    LOGI("Node type: %{public}s", node->__str__().c_str());
    // 1. 变量 x
    if (is_a<Symbol>(*node)) {
        if (down_cast<const Symbol&>(*node).get_name() == "x") {
            instructions.push_back({OpCode::VAR_X});
            return;
        }
    }
    // 2. 常数 (数字、Pi、E等)
    if (is_a_Number(*node) || is_a<Constant>(*node)) {
        instructions.push_back({OpCode::CONST_VAL, eval_double(*node)});
        return;
    }
    // 3. 加法 (SymEngine 的 Add 可能有多个子节点)
    if (is_a<Add>(*node)) {
        auto args = node->get_args();
        compileNode(args[0]);
        for (size_t i = 1; i < args.size(); ++i) {
            compileNode(args[i]);
            instructions.push_back({OpCode::ADD});
        }
        return;
    }
    // 4. 乘法 (SymEngine 的 Mul 可能有多个子节点)
    if (is_a<Mul>(*node)) {
        auto args = node->get_args();
        compileNode(args[0]);
        for (size_t i = 1; i < args.size(); ++i) {
            compileNode(args[i]);
            instructions.push_back({OpCode::MUL});
        }
        return;
    }
        // 5. 幂运算
    if (is_a<Pow>(*node)) {
        auto args = node->get_args();
        
        // 检查指数是否为整数常量
        if (is_a<Integer>(*args[1])) {
            int exp = down_cast<const Integer&>(*args[1]).as_int();
            if (exp == 0) {
                // x^0 = 1
                instructions.push_back({OpCode::CONST_VAL, 1.0});
                return;
            }
            if (exp == 1) {
                // x^1 = x，直接编译底数
                compileNode(args[0]);
                return;
            }
            if (exp == 2) {
                compileNode(args[0]);
                compileNode(args[0]);
                instructions.push_back({OpCode::MUL});
                return;
            }
            if (exp == 3) {
                compileNode(args[0]);
                compileNode(args[0]);
                instructions.push_back({OpCode::MUL});
                compileNode(args[0]);
                instructions.push_back({OpCode::MUL});
                return;
            }
            // 其他小整数次幂也可以按需展开
            if (exp >= 4 && exp <= 8) {
                compileNode(args[0]);
                for (int i = 1; i < exp; i++) {
                    compileNode(args[0]);
                    instructions.push_back({OpCode::MUL});
                }
                return;
            }
        }
        
        // 非整数次幂，回退到通用路径
        compileNode(args[0]);
        compileNode(args[1]);
        instructions.push_back({OpCode::POW});
        return;
    }
    // 6. 一元数学函数映射
    if (is_a<Sin>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::SIN}); return; }
    if (is_a<Cos>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::COS}); return; }
    if (is_a<Tan>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::TAN}); return; }
    if (is_a<ASin>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::ASIN}); return; }
    if (is_a<ACos>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::ACOS}); return; }
    if (is_a<ATan>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::ATAN}); return; }
    if (is_a<Log>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::LN}); return; }
    if (is_a<Abs>(*node)) { compileNode(node->get_args()[0]); instructions.push_back({OpCode::ABS}); return; }
    
    // 如果遇到不支持的复杂节点（如积分），兜底回退：将其作为一个求值常数处理
    instructions.push_back({OpCode::CONST_VAL, eval_double(*node)});
}

void GraphingEngine::compile(const Expression& expr) {
    instructions.clear();
    instructions.reserve(50); // 预分配空间，防止扩容开销
    compileNode(expr.get_basic());
}

// ==================== 阶段二：极速求值机 ====================
double GraphingEngine::evaluate(double x) const {
    // 使用静态数组充当栈，彻底消灭内存分配
    double stack[128];
    int sp = -1; // 栈顶指针

    for (const auto& inst : instructions) {
        switch (inst.op) {
            case OpCode::VAR_X:     stack[++sp] = x; break;
            case OpCode::CONST_VAL: stack[++sp] = inst.value; break;
            
            // 二元操作符
            case OpCode::ADD: sp--; stack[sp] += stack[sp+1]; break;
            case OpCode::SUB: sp--; stack[sp] -= stack[sp+1]; break;
            case OpCode::MUL: sp--; stack[sp] *= stack[sp+1]; break;
            case OpCode::DIV: sp--; stack[sp] /= stack[sp+1]; break;
            case OpCode::POW: sp--; stack[sp] = std::pow(stack[sp], stack[sp+1]); break;
            
            // 一元操作符
            case OpCode::SIN:  stack[sp] = std::sin(stack[sp]); break;
            case OpCode::COS:  stack[sp] = std::cos(stack[sp]); break;
            case OpCode::TAN:  stack[sp] = std::tan(stack[sp]); break;
            case OpCode::ASIN: stack[sp] = std::asin(stack[sp]); break;
            case OpCode::ACOS: stack[sp] = std::acos(stack[sp]); break;
            case OpCode::ATAN: stack[sp] = std::atan(stack[sp]); break;
            case OpCode::LN:   stack[sp] = std::log(stack[sp]); break;
            case OpCode::ABS:  stack[sp] = std::abs(stack[sp]); break;
            
            case OpCode::SINH:  stack[sp] = std::sinh(stack[sp]); break;
            case OpCode::COSH:  stack[sp] = std::cosh(stack[sp]); break;
            case OpCode::TANH:  stack[sp] = std::tanh(stack[sp]); break;
            case OpCode::LOG10: stack[sp] = std::log10(stack[sp]); break;
            case OpCode::SQRT:  stack[sp] = std::sqrt(stack[sp]); break;
        }
    }
    return sp >= 0 ? stack[0] : 0.0;
}

// ==================== 阶段三：使用已有指令直接极速采样 ====================
std::vector<double> GraphingEngine::generatePointsFast(double xMin, double xMax, int pointsCount) const {
    if (pointsCount <= 1) pointsCount = 2;
    std::vector<double> y_values;
    y_values.reserve(pointsCount); 
    
    double step = (xMax - xMin) / (pointsCount - 1);
    for (int32_t i = 0; i < pointsCount; ++i) {
        double current_x = xMin + i * step;
        double y_val = this->evaluate(current_x);
        
        // 在 C++ 底层也加上双保险：直接将 Infinity 强转为 NaN
        if (std::isnan(y_val) || std::isinf(y_val)) {
            y_values.push_back(std::nan(""));
        } else {
            y_values.push_back(y_val);
        }
    }
    return y_values;
}