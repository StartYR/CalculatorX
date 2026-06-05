#ifndef MATHVALIDATOR_H
#define MATHVALIDATOR_H

#include "json.hpp"
#include <string>
#include <cmath>

using json = nlohmann::json;

class MathValidator {
public:
    // 🌟 核心扫描雷达：返回 "OK" 表示安全，返回其他字符串则触发熔断
    static std::string validate(const json& ast) {
        // 1. 如果是普通数字或独立的符号（叶子节点），绝对安全
        if (ast.is_number() || ast.is_string()) {
            return "OK";
        }

        // 2. 如果是运算节点，开启规则审查
        if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
            std::string op = ast[0].get<std::string>();

            // 🚨 防线 A：除数为 0 拦截
            if (op == "Divide" || op == "Rational") {
                if (ast.size() > 2 && ast[2].is_number()) {
                    if (ast[2].get<double>() == 0.0) {
                        return "Math Error: Division by Zero";
                    }
                }
            }

            // 🚨 防线 B：阶乘炸弹拦截 (防止 1000000! 导致 App 闪退)
            if (op == "Factorial") {
                if (ast.size() > 1 && ast[1].is_number()) {
                    double val = ast[1].get<double>();
                    // 超过 10000 的阶乘直接拒收，保护内存
                    if (val > 10000) {
                        return "Math Error: Overflow"; 
                    }
                    // 顺手封杀负整数阶乘
                    if (val < 0 && std::floor(val) == val) {
                        return "Math Error: Domain Error"; 
                    }
                }
            }

            // 3. 递归扫描深层节点 (比如 1 + (2 / 0)，必须把藏在里面的除以 0 挖出来)
            for (size_t i = 1; i < ast.size(); ++i) {
                std::string childResult = validate(ast[i]);
                if (childResult != "OK") {
                    return childResult; // 一旦内部节点报警，立刻向上拉响警报！
                }
            }
        }
        
        return "OK"; // 全员扫描完毕，予以放行
    }
};

#endif // MATHVALIDATOR_H