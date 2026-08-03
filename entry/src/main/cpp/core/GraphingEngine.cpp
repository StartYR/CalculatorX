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
    instructions.reserve(50); 
    compileNode(expr.get_basic());

    // ============ 微积分中枢：自动编译导数伴生虚拟机 ============
    try {
        SymEngine::RCP<const SymEngine::Symbol> x_sym = SymEngine::rcp(new SymEngine::Symbol("x"));
        // 极速符号求导 f'(x)
        SymEngine::RCP<const SymEngine::Basic> df = expr.get_basic()->diff(x_sym);
        
        // 用 instructions 容器编译导数
        std::vector<Instruction> temp = instructions; 
        instructions.clear();
        compileNode(df);
        deriv_instructions = instructions; // 存入专属容器
        instructions = temp; // 恢复原指令集
    } catch (...) {
        // 遇到无法求导的奇异函数，清空伴生指令
        deriv_instructions.clear();
    }
}

// ==================== 极速求值机 ====================
double GraphingEngine::executeMachine(double x, const std::vector<Instruction>& inst_list) const {
    if (inst_list.empty()) return std::nan(""); // 降级保护

    double stack[128];
    int sp = -1; // 栈顶指针

    for (const auto& inst : inst_list) {
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

double GraphingEngine::evaluate(double x) const {
    return executeMachine(x, instructions);
}

double GraphingEngine::evaluateDeriv(double x) const {
    return executeMachine(x, deriv_instructions);
}

// ==================== 自适应递归采样 ====================
void GraphingEngine::sampleRecursive(double x1, double y1, double x2, double y2, int depth, double error_threshold, double jump_threshold, std::vector<double>& result) const {
    // 1. 递归出口：防止无限细分导致栈溢出
    if (depth >= 8) {
        if (std::abs(y1 - y2) > jump_threshold && y1 * y2 < 0) {
            // ============ 奇点的极限逼近 ============
            double a = x1;
            double b = x2;
            
            // 迭代 40 次，把精度压到 double 极限
            for (int k = 0; k < 40; ++k) {
                double m = (a + b) / 2.0;
                double y_m = this->evaluate(m);
                
                // 防御：万一正中红心，刚好算到了真正的奇点导致 NaN
                if (std::isnan(y_m) || std::isinf(y_m)) {
                    a = m - 1e-14;
                    b = m + 1e-14;
                    break;
                }
                
                // 严谨判断符号，收缩边界
                if (this->evaluate(a) * y_m <= 0) {
                    b = m;
                } else {
                    a = m;
                }
            }
            
            double y_a = this->evaluate(a);
            double y_b = this->evaluate(b);
            
            // 奇点左侧点
            result.push_back(a);
            result.push_back(y_a);
            
            // 断崖标志
            result.push_back(std::nan(""));
            result.push_back(std::nan(""));
            
            // 奇点右侧点
            result.push_back(b);
            result.push_back(y_b);
            
            // 递归终点
            result.push_back(x2);
            result.push_back(y2);
        } else {
            // 不是奇点，只是纯粹的极度陡峭，正常推入右侧点
            result.push_back(x2);
            result.push_back(y2);
        }
        return;
    }

    // 2. 取 X 的物理中点，算出真实的 Y 值
    double x_mid = (x1 + x2) / 2.0;
    double y_mid_real = this->evaluate(x_mid);

    // 如果中点算出来是非法值，直接打断连线
    if (std::isnan(y_mid_real) || std::isinf(y_mid_real)) {
        result.push_back(std::nan(""));
        result.push_back(std::nan(""));
        return;
    }

    // 3. 计算如果用直线相连，中点的理论 Y 值
    double y_mid_line = (y1 + y2) / 2.0;

    // 4. 核心裁决：计算真实曲线与直线的垂直偏差
    double error = std::abs(y_mid_real - y_mid_line);

    // 5. 分支判断：如果偏差大于我们设定的容忍度，说明曲线在这里很弯，继续递归细分！
    if (error > error_threshold) {
        sampleRecursive(x1, y1, x_mid, y_mid_real, depth + 1, error_threshold, jump_threshold, result);
        sampleRecursive(x_mid, y_mid_real, x2, y2, depth + 1, error_threshold, jump_threshold, result);
    } else {
        // 曲线在这段极其平滑，甚至就是一条直线，停止细分，直接推入右侧点
        result.push_back(x2);
        result.push_back(y2);
    }
}

// ==================== 阶段三：直接采样 (自适应递归) ====================
std::vector<double> GraphingEngine::generatePointsFast(double xMin, double xMax, int pointsCount) const {
    std::vector<double> xy_values;
    // 预留足够大的空间，应对高频震荡函数产生的海量细分点
    xy_values.reserve(2000); 

    // 1. 建立稀疏的“基准网格” (只需极少的探测点，比如 50 段)
    int base_segments = 50; 
    double step = (xMax - xMin) / base_segments;
    
    // 2. 动态计算视口相关的容忍度阈值
    // 弯曲容忍度：屏幕宽度的 1/1000 (相当于容忍 1 像素的视觉误差)
    double error_threshold = (xMax - xMin) / 1000.0;
    // 断崖跳跃阈值：视口宽度的 5 倍 (手机屏幕高度通常不超过宽度的 2.5 倍，5 倍绝对是飞出屏幕的渐近线)
    double jump_threshold = (xMax - xMin) * 5.0;

    // 3. 推入最左侧的初始原点
    double prev_x = xMin;
    double prev_y = this->evaluate(prev_x);
    xy_values.push_back(prev_x);
    if (std::isnan(prev_y) || std::isinf(prev_y)) {
        xy_values.push_back(std::nan(""));
    } else {
        xy_values.push_back(prev_y);
    }

    // 4. 遍历基准网格，对每个区间启动自适应探测
    for (int i = 1; i <= base_segments; ++i) {
        double curr_x = xMin + i * step;
        double curr_y = this->evaluate(curr_x);
        
        // 计算两端点的导数
        double deriv_prev = this->evaluateDeriv(prev_x);
        double deriv_curr = this->evaluateDeriv(curr_x);
        
        if (std::isnan(curr_y) || std::isinf(curr_y)) {
            xy_values.push_back(curr_x);
            xy_values.push_back(std::nan(""));
        } else if (std::isnan(prev_y) || std::isinf(prev_y)) {
            xy_values.push_back(curr_x);
            xy_values.push_back(curr_y);
        } else {
            // ============ 极值点拦截 ============
            // 如果左端点导数和右端点导数符号相反，说明中间必有一个极值点
            if (std::isfinite(deriv_prev) && std::isfinite(deriv_curr) && deriv_prev * deriv_curr < 0) {
                
                // 20 次二分法，求出导数为 0 的 X 坐标
                double a = prev_x;
                double b = curr_x;
                for (int k = 0; k < 20; ++k) {
                    double m = (a + b) / 2.0;
                    if (this->evaluateDeriv(a) * this->evaluateDeriv(m) <= 0) {
                        b = m;
                    } else {
                        a = m;
                    }
                }
                double x_peak = (a + b) / 2.0;
                double y_peak = this->evaluate(x_peak);
                
                if (std::isfinite(y_peak)) {
                    // 强制将区间分成两段
                    sampleRecursive(prev_x, prev_y, x_peak, y_peak, 0, error_threshold, jump_threshold, xy_values);
                    sampleRecursive(x_peak, y_peak, curr_x, curr_y, 0, error_threshold, jump_threshold, xy_values);
                } else {
                    sampleRecursive(prev_x, prev_y, curr_x, curr_y, 0, error_threshold, jump_threshold, xy_values);
                }
            } else {
                // 没有极值点，自适应探测
                sampleRecursive(prev_x, prev_y, curr_x, curr_y, 0, error_threshold, jump_threshold, xy_values);
            }
        }
        
        prev_x = curr_x;
        prev_y = curr_y;
    }

    return xy_values;
}