#pragma once
#include "json.hpp"
#include <symengine/expression.h>

SymEngine::Expression parseAST(const nlohmann::json& ast, bool isRad, bool preferExact, bool& hasDMS);