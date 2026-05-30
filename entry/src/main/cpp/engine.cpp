#include "napi/native_api.h"
#include <cstdio>
#include <cmath>

// 辗转相除法求最大公约数
int gcd(int a, int b) {
    a = std::abs(a);
    b = std::abs(b);
    while (b != 0) {
        int temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

// 核心逻辑：依然是分数计算，只是换个马甲
static napi_value Add(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    char str1[64] = {0};
    char str2[64] = {0};
    size_t len;
    napi_get_value_string_utf8(env, args[0], str1, sizeof(str1), &len);
    napi_get_value_string_utf8(env, args[1], str2, sizeof(str2), &len);

    int n1 = 0, d1 = 1, n2 = 0, d2 = 1;
    sscanf(str1, "%d/%d", &n1, &d1);
    sscanf(str2, "%d/%d", &n2, &d2);

    int num = n1 * d2 + n2 * d1;
    int den = d1 * d2;

    int common = gcd(num, den);
    num /= common;
    den /= common;

    char resultStr[128];
    sprintf(resultStr, "\\frac{%d}{%d}", num, den);

    napi_value result;
    napi_create_string_utf8(env, resultStr, NAPI_AUTO_LENGTH, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // 核心破解点：用回 "add" 这个名字，让 IDE 闭嘴
        { "addFraction", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr }
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