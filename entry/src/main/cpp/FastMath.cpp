// entry/src/main/cpp/FastMath.cpp
#include "FastMath.h"
#include "ErrorHandler.h"
#include <cmath>
#include <sstream>
#include <iomanip>

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
        // Stirling's approximation: log10(n!) ≈ 0.5 * log10(2 * π * n) + n * log10(n / e)
        return 0.5 * std::log10(2 * pi_val * n) + n * std::log10(n / e_val);
    }

    std::string formatScientific(double magnitude) {
        long long B = static_cast<long long>(std::floor(magnitude));
        double A = std::pow(10.0, magnitude - B);
        
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(5) << A;
        std::string A_str = oss.str();
        A_str.erase(A_str.find_last_not_of('0') + 1, std::string::npos);
        if (A_str.back() == '.') A_str.pop_back();
        
        return A_str + "\\times 10^{" + std::to_string(B) + "}";
    }

}