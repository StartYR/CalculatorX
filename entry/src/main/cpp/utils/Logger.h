/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file FormatUtils.h
 * @description 统一格式化与字符串工具中枢
 * @author 易睿 (Yi Rui)
 * @date 2026/7/25 17:11
 */

#pragma once
#include <hilog/log.h>

// 定义 CalculatorX 的专属日志域和标签
#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "CalcX_Engine"

// 生产环境总开关：打正式包时，将 1 改为 0
#define ENABLE_CALCX_DEBUG_LOG 1

// ========= 调试与信息日志 =========
#if ENABLE_CALCX_DEBUG_LOG
    #define LOGD(fmt, ...) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
    #define LOGI(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO,  LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#else
    #define LOGD(fmt, ...) 
    #define LOGI(fmt, ...) 
#endif

// ========= 警告与错误日志 =========
#define LOGW(fmt, ...) OH_LOG_Print(LOG_APP, LOG_WARN,  LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)
#define LOGF(fmt, ...) OH_LOG_Print(LOG_APP, LOG_FATAL, LOG_DOMAIN, LOG_TAG, fmt, ##__VA_ARGS__)