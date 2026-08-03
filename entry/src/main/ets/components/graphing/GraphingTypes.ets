/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingTypes.ets
 * @description 图形计算器相关基础数据结构和类型声明
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

// ==================== 函数类型枚举 ====================
export enum FunctionType {
  NORMAL = 0,      // 普通显函数 y = f(x)
  PARAMETRIC = 1,  // 参数方程 x(t), y(t)
  POLAR = 2,       // 极坐标方程 r(t) 或 r(θ)
  IMPLICIT = 3     // 隐函数 f(x,y) = 0
}

// ==================== 函数项数据结构 ====================
export interface GraphFunctionItem {
  // --- 基础公共属性 ---
  id: string;
  color: string;
  isVisible: boolean;
  type?: FunctionType; // 函数类型（缺省时可默认为 NORMAL）

  // --- 主表达式（适用于普通函数、极坐标、隐函数，以及参数方程的 x(t)） ---
  latex: string;
  base64: string;
  ast?: string;

  // --- 伴生表达式（专用于参数方程的 y(t) 等多输入场景） ---
  latex2?: string;
  base64_2?: string;
  ast2?: string;

  // --- 定义域边界（专用于参数方程和极坐标的自变量范围） ---
  tMin?: number;
  tMax?: number;
}