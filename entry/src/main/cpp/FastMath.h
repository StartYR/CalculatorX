// entry/src/main/cpp/FastMath.h
#ifndef FAST_MATH_H
#define FAST_MATH_H

#include <string>

namespace FastMath {
    // 检查是否超出 64 位整数物理极限 (9e18)，超出则抛出溢出异常
    void checkOverflow(double magnitude);

    // 获取阶乘的对数量级 log10(n!) (利用斯特林近似公式)
    double getFactorialMagnitude(double n);

    // 将量级格式化为 LaTeX 的科学计数法 A \times 10^B
    std::string formatScientific(double magnitude);
}

#endif // FAST_MATH_H