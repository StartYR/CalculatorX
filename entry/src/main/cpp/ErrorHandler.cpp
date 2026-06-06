// entry/src/main/cpp/ErrorHandler.cpp
#include "ErrorHandler.h"

CalcException::CalcException(CalcErrorCode c, const std::string& msg)
    : std::runtime_error(msg), code(c) {}

std::string CalcException::getFrontEndMessage() const {
    switch (code) {
        case CalcErrorCode::DIV_BY_ZERO: 
            return "Error:DivByZero"; // 前端可据此提示“除数不能为0”
        case CalcErrorCode::DOMAIN_ERROR: 
            return "Error:Domain";    // 前端可据此提示“数学域错误”或“无效输入”
        case CalcErrorCode::SYNTAX_ERROR: 
            return "Error:Syntax";    // 前端可据此提示“语法错误”
        case CalcErrorCode::OVERFLOW_ERROR:
            return "Error:Overflow"; // 结果过大或超出范围
//            return "错误：溢出";
        default: 
            return "Error:Unknown";
    }
}