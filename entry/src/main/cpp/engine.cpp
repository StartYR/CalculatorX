#include "napi/native_api.h"
#include "json.hpp"
#include <string>
#include <cmath>

using json = nlohmann::json;

// 🌟 核心引擎：递归遍历 AST 语法树进行计算
double evaluateAST(const json& ast) {
    // 1. 如果节点是纯数字，直接返回
    if (ast.is_number()) {
        return ast.get<double>();
    }
    
    // 2. 如果节点是数组（即表达式），根据操作符执行计算
    if (ast.is_array() && !ast.empty() && ast[0].is_string()) {
        std::string op = ast[0].get<std::string>();

        // -- 基础四则运算 --
        if (op == "Add") {
            double sum = 0;
            for (size_t i = 1; i < ast.size(); ++i) sum += evaluateAST(ast[i]);
            return sum;
        }
        if (op == "Subtract" || op == "Negate") {
            if (ast.size() == 2) return -evaluateAST(ast[1]); // 处理单目取反，比如 -5
            return evaluateAST(ast[1]) - evaluateAST(ast[2]);
        }
        if (op == "Multiply") {
            double product = 1;
            for (size_t i = 1; i < ast.size(); ++i) product *= evaluateAST(ast[i]);
            return product;
        }
        if (op == "Divide") {
            return evaluateAST(ast[1]) / evaluateAST(ast[2]);
        }

        // -- 高级数学函数 --
        if (op == "Sqrt") return std::sqrt(evaluateAST(ast[1]));
        if (op == "Power") return std::pow(evaluateAST(ast[1]), evaluateAST(ast[2]));
        if (op == "Sin") return std::sin(evaluateAST(ast[1]));
        if (op == "Cos") return std::cos(evaluateAST(ast[1]));
        if (op == "Tan") return std::tan(evaluateAST(ast[1]));
    }
    
    // 默认返回 0（或者未来在这里抛出无法解析的异常）
    return 0;
}

// N-API 通信接口
static napi_value Calculate(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t str_len;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_len);
    std::string json_str(str_len, '\0');
    napi_get_value_string_utf8(env, args[0], &json_str[0], str_len + 1, &str_len);

    std::string result_msg;

    try {
        json ast = json::parse(json_str);
        if (ast.is_string()) {
            ast = json::parse(ast.get<std::string>()); 
        }
        
        // 🔥 调用我们新写的递归计算引擎！
        double calc_result = evaluateAST(ast);
        
        // 将数字结果转回字符串
        result_msg = std::to_string(calc_result);

        // 可选：去掉小数点后多余的 0
        result_msg.erase(result_msg.find_last_not_of('0') + 1, std::string::npos);
        if (result_msg.back() == '.') result_msg.pop_back();

    } catch (std::exception& e) {
        result_msg = "Error"; // 如果出错，返回 Error
    }

    napi_value result;
    napi_create_string_utf8(env, result_msg.c_str(), NAPI_AUTO_LENGTH, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "calculate", nullptr, Calculate, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&demoModule);
}