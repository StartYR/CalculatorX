// entry/src/main/cpp/ErrorHandler.h
#ifndef ERROR_HANDLER_H
#define ERROR_HANDLER_H

#include <exception>
#include <string>

// 精细化的业务错误码字典
enum class CalcErrorCode {
    DIV_BY_ZERO,     // 除以零
    DOMAIN_ERROR,    // 定义域错误 (如负数开偶次根号，负数阶乘)
    OVERFLOW_ERROR,  // 数值溢出 (超出 64 位物理极限)
    SYNTAX_ERROR,    // 语法/解析错误
    TIMEOUT_ERROR    // 【新增】：计算超时或算力超载 (底层引擎拒绝运算)
};

// 自定义计算业务异常类
class CalcException : public std::exception {
private:
    CalcErrorCode code_;
    std::string detail_;

public:
    CalcException(CalcErrorCode code, const std::string& detail = "")
        : code_(code), detail_(detail) {}

    CalcErrorCode getCode() const { return code_; }
    const char* getDetail() const { return detail_.c_str(); }

    // 将底层错误码映射为前端 UI 友好的短字符串
    std::string getFrontEndMessage() const {
        switch (code_) {
            case CalcErrorCode::DIV_BY_ZERO: return "Error:DivByZero";
            case CalcErrorCode::DOMAIN_ERROR: return "Error:Domain";
            case CalcErrorCode::OVERFLOW_ERROR: return "Error:Overflow";
            case CalcErrorCode::SYNTAX_ERROR: return "Error:Syntax";
            case CalcErrorCode::TIMEOUT_ERROR: return "Error:Timeout"; // 【新增】映射到前端
            default: return "Error:Unknown";
        }
    }
};

#endif // ERROR_HANDLER_H