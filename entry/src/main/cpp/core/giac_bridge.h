#pragma once
#include <string>
#include "json.hpp"

std::string evaluateWithGiac(const std::string& mathExpression);
// 暂且保留的构建指令函数
std::string buildGiacCommand(const nlohmann::json& ast);