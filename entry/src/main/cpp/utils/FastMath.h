/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file FastMath.h
 * @description 极速降维模块：O(1) 时间计算宇宙级超大数
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
#ifndef FAST_MATH_H
#define FAST_MATH_H

#include <symengine/expression.h>
#include <string>

namespace FastMath {
    // 检查是否超出 64 位整数物理极限 (9e18)
    void checkOverflow(double magnitude);

    // 获取阶乘的对数量级
    double getFactorialMagnitude(double n);

    // 根据计算量级，生成包含幽灵变量 MAGICBASETEN 的代数节点 (带 10 位安全四舍五入防线)
    SymEngine::Expression buildBigScientificNode(double magnitude);

    // 组装幽灵节点 (用于前端绝对精确的数据，避免从 magnitude 绕远路带来的精度损耗)
    SymEngine::Expression buildBigScientificNode(double exact_base, long long exact_exp);
}

#endif // FAST_MATH_H