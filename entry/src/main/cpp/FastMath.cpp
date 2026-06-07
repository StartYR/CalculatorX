// entry/src/main/cpp/FastMath.cpp
#include "FastMath.h"
#include "ErrorHandler.h"
#include <cmath>

namespace FastMath {

    void checkOverflow(double magnitude) {
        if (std::isinf(magnitude) || std::abs(magnitude) > 9e18) {
            throw CalcException(CalcErrorCode::OVERFLOW_ERROR, "Exceeds 64-bit integer limits");
        }
    }

    double getFactorialMagnitude(double n) {
        if (n <= 1.0) return 0.0;
        double pi_val = std::acos(-1.0);
        double e_val = std::exp(1.0);
        return 0.5 * std::log10(2 * pi_val * n) + n * std::log10(n / e_val);
    }

    // 针对计算产生的大数 (带磁吸防线与安全舍入)
    SymEngine::Expression buildBigScientificNode(double magnitude) {
        long long B = static_cast<long long>(std::floor(magnitude));
        double A = std::pow(10.0, magnitude - B);
        
        // 抹除 IEEE 754 浮点数噪音
        if (std::abs(A - std::round(A)) < 1e-10) {
            A = std::round(A); // 磁吸到最近整数
        } else {
            A = std::round(A * 1e10) / 1e10; // 保留 10 位安全小数位数，其余截断并四舍五入
        }
        
        // 防止进位导致 A 满 10
        if (A >= 10.0) {
            A /= 10.0;
            B += 1;
        }
        
        SymEngine::Expression tenBase(SymEngine::symbol("MAGICBASETEN"));
        SymEngine::Expression expExpr(B);
        
        if (std::abs(A - 1.0) < 1e-9) {
            return SymEngine::pow(tenBase, expExpr);
        } else {
            return SymEngine::Expression(A) * SymEngine::pow(tenBase, expExpr);
        }
    }

    // 【重载】：针对前端直接输入的大数 (绕开双精度损耗，绝对保真)
    SymEngine::Expression buildBigScientificNode(double exact_base, long long exact_exp) {
        SymEngine::Expression tenBase(SymEngine::symbol("MAGICBASETEN"));
        SymEngine::Expression expExpr(exact_exp);
        
        if (std::abs(exact_base - 1.0) < 1e-9) {
            return SymEngine::pow(tenBase, expExpr);
        } else {
            return SymEngine::Expression(exact_base) * SymEngine::pow(tenBase, expExpr);
        }
    }
}