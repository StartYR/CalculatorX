/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file giac_bridge.h
 * @description Giac CAS 引擎桥接层，负责符号表达式求值与命令构建
 * @author StartYi
 * @date 2026
 */
#pragma once
#include <string>

std::string evaluateWithGiac(const std::string& mathExpression);