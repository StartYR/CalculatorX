/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEngine.cpp
 * @description 函数渲染核心 (集成符号伴生导数雷达、极限边界嗅探与 RPN 自适应递归采样)
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
// 增加 target_inst 参数，实现多核复用
void GraphingEngine::compileNode(const RCP<const Basic>& node, std::vector<Instruction>& target_inst) {
    // 1. 多变量感知
    if (is_a<Symbol>(*node)) {
        std::string name = down_cast<const Symbol&>(*node).get_name();
        if (name == "x") { target_inst.push_back({OpCode::VAR_X}); return; }
        if (name == "y") { target_inst.push_back({OpCode::VAR_Y}); return; }
        if (name == "t") { target_inst.push_back({OpCode::VAR_T}); return; }
        if (name == "θ" || name == "theta") { target_inst.push_back({OpCode::VAR_THETA}); return; } // 支持直接匹配前端的 Unicode
        
        // 兜底：遇到不认识的字母直接按 0 处理，防止引擎崩溃
        target_inst.push_back({OpCode::CONST_VAL, 0.0}); 
        return;
    }
    
    // 2. 常数 (数字、Pi、E等)
    if (is_a_Number(*node) || is_a<Constant>(*node)) {
        target_inst.push_back({OpCode::CONST_VAL, eval_double(*node)});
        return;
    }
    
    // 3. 加法
    if (is_a<Add>(*node)) {
        auto args = node->get_args();
        compileNode(args[0], target_inst);
        for (size_t i = 1; i < args.size(); ++i) {
            compileNode(args[i], target_inst);
            target_inst.push_back({OpCode::ADD});
        }
        return;
    }
    // 4. 乘法
    if (is_a<Mul>(*node)) {
        auto args = node->get_args();
        compileNode(args[0], target_inst);
        for (size_t i = 1; i < args.size(); ++i) {
            compileNode(args[i], target_inst);
            target_inst.push_back({OpCode::MUL});
        }
        return;
    }
    
    // 5. 幂运算
    if (is_a<Pow>(*node)) {
        auto args = node->get_args();
        if (is_a<Integer>(*args[1])) {
            int exp = down_cast<const Integer&>(*args[1]).as_int();
            if (exp == 0) { target_inst.push_back({OpCode::CONST_VAL, 1.0}); return; }
            if (exp == 1) { compileNode(args[0], target_inst); return; }
            if (exp == 2) {
                compileNode(args[0], target_inst);
                compileNode(args[0], target_inst);
                target_inst.push_back({OpCode::MUL});
                return;
            }
            if (exp == 3) {
                compileNode(args[0], target_inst);
                compileNode(args[0], target_inst);
                target_inst.push_back({OpCode::MUL});
                compileNode(args[0], target_inst);
                target_inst.push_back({OpCode::MUL});
                return;
            }
            if (exp >= 4 && exp <= 8) {
                compileNode(args[0], target_inst);
                for (int i = 1; i < exp; i++) {
                    compileNode(args[0], target_inst);
                    target_inst.push_back({OpCode::MUL});
                }
                return;
            }
        }
        compileNode(args[0], target_inst);
        compileNode(args[1], target_inst);
        target_inst.push_back({OpCode::POW});
        return;
    }
    
    // 6. 一元数学函数映射
    if (is_a<Sin>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::SIN}); return; }
    if (is_a<Cos>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::COS}); return; }
    if (is_a<Tan>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::TAN}); return; }
    if (is_a<ASin>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::ASIN}); return; }
    if (is_a<ACos>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::ACOS}); return; }
    if (is_a<ATan>(*node)) { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::ATAN}); return; }
    if (is_a<Log>(*node))  { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::LN}); return; }
    if (is_a<Abs>(*node))  { compileNode(node->get_args()[0], target_inst); target_inst.push_back({OpCode::ABS}); return; }
    
    target_inst.push_back({OpCode::CONST_VAL, eval_double(*node)});
}

// 支持双表达式编译，智能寻找求导目标变量
void GraphingEngine::compile(const Expression& expr1, const Expression& expr2) {
    instructions.clear();
    deriv_instructions.clear();
    instructions2.clear();
    deriv_instructions2.clear();

    // 编译主表达式
    compileNode(expr1.get_basic(), instructions);
    
    // 如果有第二表达式 (比如 y(t))，编译之
    bool has_expr2 = (expr2.get_basic()->__str__() != "0");
    if (has_expr2) {
        compileNode(expr2.get_basic(), instructions2);
    }

    try {
        // 简单智能推断：用什么变量来求导（针对隐函数和普通函数优先用x，参数方程优先用t，极坐标优先用θ）
        std::string diff_var = "x";
        std::string s1 = expr1.get_basic()->__str__();
        if (s1.find("t") != std::string::npos) diff_var = "t";
        else if (s1.find("θ") != std::string::npos) diff_var = "θ";

        SymEngine::RCP<const SymEngine::Symbol> diff_sym = SymEngine::rcp(new SymEngine::Symbol(diff_var));
        
        // 编译主表达式的导数
        SymEngine::RCP<const SymEngine::Basic> df1 = expr1.get_basic()->diff(diff_sym);
        compileNode(df1, deriv_instructions);
        
        // 如果有伴生表达式，编译其导数
        if (has_expr2) {
            SymEngine::RCP<const SymEngine::Basic> df2 = expr2.get_basic()->diff(diff_sym);
            compileNode(df2, deriv_instructions2);
        }
    } catch (...) {
        // 求导失败时静默清空
        deriv_instructions.clear();
        deriv_instructions2.clear();
    }
}

// ==================== 极速求值机 ====================
double GraphingEngine::executeMachine(double x, double y, double t, double theta, const std::vector<Instruction>& inst_list) const {
    if (inst_list.empty()) return std::nan("");

    double stack[128];
    int sp = -1; 

    for (const auto& inst : inst_list) {
        switch (inst.op) {
            case OpCode::VAR_X:     stack[++sp] = x; break;
            case OpCode::VAR_Y:     stack[++sp] = y; break;
            case OpCode::VAR_T:     stack[++sp] = t; break;
            case OpCode::VAR_THETA: stack[++sp] = theta; break;
            case OpCode::CONST_VAL: stack[++sp] = inst.value; break;
            
            case OpCode::ADD: sp--; stack[sp] += stack[sp+1]; break;
            case OpCode::SUB: sp--; stack[sp] -= stack[sp+1]; break;
            case OpCode::MUL: sp--; stack[sp] *= stack[sp+1]; break;
            case OpCode::DIV: sp--; stack[sp] /= stack[sp+1]; break;
            case OpCode::POW: sp--; stack[sp] = std::pow(stack[sp], stack[sp+1]); break;
            
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

double GraphingEngine::evaluate(double x, double y, double t, double theta) const { return executeMachine(x, y, t, theta, instructions); }
double GraphingEngine::evaluateDeriv(double x, double y, double t, double theta) const { return executeMachine(x, y, t, theta, deriv_instructions); }
double GraphingEngine::evaluate_2(double x, double y, double t, double theta) const { return executeMachine(x, y, t, theta, instructions2); }
double GraphingEngine::evaluateDeriv_2(double x, double y, double t, double theta) const { return executeMachine(x, y, t, theta, deriv_instructions2); }

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

    // 1. 建立稀疏的“基准网格”，让基准网格的密度与屏幕像素宽度挂钩，每 4 个像素放置一个探测点
    int base_segments = pointsCount / 4; 
    if (base_segments < 50) base_segments = 50;
    if (base_segments > 500) base_segments = 500; // 封顶
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
        
        // 状态
        bool prev_valid = std::isfinite(prev_y);
        bool curr_valid = std::isfinite(curr_y);

        if (!prev_valid && !curr_valid) {
            // 1. 都在定义域外，直接推入 NaN 保持断开
            xy_values.push_back(curr_x);
            xy_values.push_back(std::nan(""));
        } 
        else if (!prev_valid && curr_valid) {
            // 2. 【进入定义域】（例如 sqrt(x) 跨越 0，从左往右）
            double a = prev_x;
            double b = curr_x;
            // 20 次二分，锁定定义域左边界
            for (int k = 0; k < 20; ++k) {
                double m = (a + b) / 2.0;
                if (std::isfinite(this->evaluate(m))) {
                    b = m; // 中点有效，说明边界在左半区
                } else {
                    a = m; // 中点无效，说明边界在右半区
                }
            }
            // 此时 b 是贴近有效定义域的最极限点
            double y_b = this->evaluate(b);
            
            // 注入断点，确保左侧没有脏线
            xy_values.push_back(a);
            xy_values.push_back(std::nan(""));
            
            // 从真正的精确边界点 b 开始，向 curr_x 启动正常的自适应递归采样！
            sampleRecursive(b, y_b, curr_x, curr_y, 0, error_threshold, jump_threshold, xy_values);
        } 
        else if (prev_valid && !curr_valid) {
            // 3. 【离开定义域】跨越 0，从左往右
            double a = prev_x;
            double b = curr_x;
            // 二分法计算定义域右边界
            for (int k = 0; k < 20; ++k) {
                double m = (a + b) / 2.0;
                if (std::isfinite(this->evaluate(m))) {
                    a = m; // 中点有效，说明边界在右半区
                } else {
                    b = m; // 中点无效，说明边界在左半区
                }
            }
            // 此时 a 是贴近有效定义域的最极限点
            double y_a = this->evaluate(a);
            
            // 从 prev_x 向真正的精确边界点 a 进行采样
            sampleRecursive(prev_x, prev_y, a, y_a, 0, error_threshold, jump_threshold, xy_values);
            
            // 注入断点，彻底切断右侧的线
            xy_values.push_back(b);
            xy_values.push_back(std::nan(""));
        } 
        else {
            // 4. 【全在定义域内】：寻找极值点强制采样
            double deriv_prev = this->evaluateDeriv(prev_x);
            double deriv_curr = this->evaluateDeriv(curr_x);
            
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

// ==================== 阶段二：多形态函数专属采样器 ====================

// 1. 参数方程 x(t), y(t)
std::vector<double> GraphingEngine::generateParametric(double tMin, double tMax, int pointsCount) const {
    std::vector<double> result;
    // 参数方程往往会画出复杂的闭合曲线，保证至少 500 个点以确保平滑
    if (pointsCount < 500) pointsCount = 500; 
    result.reserve((pointsCount + 1) * 2);
    
    double step = (tMax - tMin) / pointsCount;
    
    for (int i = 0; i <= pointsCount; ++i) {
        double t = tMin + i * step;
        
        // 核心魔法：将 t 喂入第 3 个参数，分别执行两套指令集
        // evaluate(x, y, t, theta)
        double curr_x = this->evaluate(0, 0, t, 0);   // 计算 x(t)
        double curr_y = this->evaluate_2(0, 0, t, 0); // 计算 y(t)
        
        // 如果遇到非法值（如除以 0），推入 NaN 切断线条
        if (std::isnan(curr_x) || std::isinf(curr_x) || std::isnan(curr_y) || std::isinf(curr_y)) {
            result.push_back(std::nan(""));
            result.push_back(std::nan(""));
        } else {
            result.push_back(curr_x);
            result.push_back(curr_y);
        }
    }
    return result;
}

// 2. 极坐标方程 r(θ)
std::vector<double> GraphingEngine::generatePolar(double thetaMin, double thetaMax, int pointsCount) const {
    std::vector<double> result;
    if (pointsCount < 500) pointsCount = 500;
    result.reserve((pointsCount + 1) * 2);
    
    double step = (thetaMax - thetaMin) / pointsCount;
    
    for (int i = 0; i <= pointsCount; ++i) {
        double theta = thetaMin + i * step;
        
        // 核心魔法：将 theta 喂入第 4 个参数，算出半径 r
        double r = this->evaluate(0, 0, 0, theta); 
        
        if (std::isnan(r) || std::isinf(r)) {
            result.push_back(std::nan(""));
            result.push_back(std::nan(""));
        } else {
            // 极坐标到直角坐标的极速转换
            result.push_back(r * std::cos(theta)); // X = r * cos(θ)
            result.push_back(r * std::sin(theta)); // Y = r * sin(θ)
        }
    }
    return result;
}

// 3. 独立点 (x, y)
std::vector<double> GraphingEngine::generatePoint() const {
    std::vector<double> result;
    
    // 点不需要循环，直接执行主表达式 (x) 和伴生表达式 (y)
    double curr_x = this->evaluate(0, 0, 0, 0);
    double curr_y = this->evaluate_2(0, 0, 0, 0);
    
    result.push_back(curr_x);
    result.push_back(curr_y);
    
    return result;
}

// 4. 隐函数 f(x, y) = 0
std::vector<double> GraphingEngine::generateImplicit(double xMin, double xMax, double yMin, double yMax, int resolution) const {
    std::vector<double> result;
    // 分辨率：网格越密，曲线越精细。150x150 = 22500 次并行采样
    int resX = resolution > 100 ? resolution : 150;
    int resY = resX; 

    double dx = (xMax - xMin) / resX;
    double dy = (yMax - yMin) / resY;

    // 1. 预先采样二维网格
    std::vector<std::vector<double>> grid(resX + 1, std::vector<double>(resY + 1));
    for (int i = 0; i <= resX; ++i) {
        double x = xMin + i * dx;
        for (int j = 0; j <= resY; ++j) {
            double y = yMin + j * dy;
            // 将 x 和 y 同时喂给虚拟机，t 和 theta 传 0
            grid[i][j] = this->evaluate(x, y, 0, 0);
        }
    }

    // 线性插值辅助函数：精准定位 0 点在哪
    auto interp = [](double val1, double val2, double coord1, double coord2) {
        if (std::abs(val1 - val2) < 1e-9) return coord1;
        return coord1 + (0.0 - val1) * (coord2 - coord1) / (val2 - val1);
    };

    // 压入独立线段，并用 NaN 切断，完美适配前端的 lineTo 逻辑
    auto addLine = [&](double x1, double y1, double x2, double y2) {
        result.push_back(x1); result.push_back(y1);
        result.push_back(x2); result.push_back(y2);
        result.push_back(std::nan("")); result.push_back(std::nan(""));
    };

    // 2. 遍历网格，查表法画线
    for (int i = 0; i < resX; ++i) {
        for (int j = 0; j < resY; ++j) {
            double x0 = xMin + i * dx;
            double x1 = xMin + (i + 1) * dx;
            double y0 = yMin + j * dy;
            double y1 = yMin + (j + 1) * dy;

            double v0 = grid[i][j];       // 左下
            double v1 = grid[i+1][j];     // 右下
            double v2 = grid[i+1][j+1];   // 右上
            double v3 = grid[i][j+1];     // 左上

            // 计算 16 种状态 (用 4 位二进制表示，1 表示值大于 0)
            int state = 0;
            if (v0 > 0) state |= 1;
            if (v1 > 0) state |= 2;
            if (v2 > 0) state |= 4;
            if (v3 > 0) state |= 8;

            if (state == 0 || state == 15) continue; // 全大于0或全小于0，内部无交点

            // 计算四条边的插值零点
            double p0x = interp(v0, v1, x0, x1), p0y = y0; // 底边
            double p1x = x1, p1y = interp(v1, v2, y0, y1); // 右边
            double p2x = interp(v3, v2, x0, x1), p2y = y1; // 顶边
            double p3x = x0, p3y = interp(v0, v3, y0, y1); // 左边

            // 核心连线路由
            switch (state) {
                case 1: case 14: addLine(p3x, p3y, p0x, p0y); break;
                case 2: case 13: addLine(p0x, p0y, p1x, p1y); break;
                case 4: case 11: addLine(p1x, p1y, p2x, p2y); break;
                case 8: case 7:  addLine(p2x, p2y, p3x, p3y); break;
                case 3: case 12: addLine(p3x, p3y, p1x, p1y); break;
                case 6: case 9:  addLine(p0x, p0y, p2x, p2y); break;
                case 5: // 鞍点交错
                    addLine(p0x, p0y, p3x, p3y);
                    addLine(p1x, p1y, p2x, p2y);
                    break;
                case 10: // 鞍点交错
                    addLine(p0x, p0y, p1x, p1y);
                    addLine(p2x, p2y, p3x, p3y);
                    break;
            }
        }
    }
    return result;
}