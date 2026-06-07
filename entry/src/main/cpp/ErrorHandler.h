// entry/src/main/cpp/ErrorHandler.h
#ifndef ERROR_HANDLER_H
#define ERROR_HANDLER_H

#include <string>
#include <stdexcept>

// 定义计算器专属错误码
enum class CalcErrorCode {
    DIV_BY_ZERO,     // 除以零
    DOMAIN_ERROR,    // 定义域错误（如负数阶乘、对数非正数）
    SYNTAX_ERROR,    // 语法/节点解析错误
    OVERFLOW_ERROR,  // 溢出
    UNKNOWN_ERROR    // 未知错误兜底
};

// 自定义计算异常类，继承自标准库 runtime_error
class CalcException : public std::runtime_error {
public:
    CalcErrorCode code;

    CalcException(CalcErrorCode c, const std::string& msg);
    
    // 获取传给 ArkTS 前端的标准化字符串标识
    std::string getFrontEndMessage() const;
};

#endif // ERROR_HANDLER_H