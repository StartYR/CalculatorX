/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingTypes.ets
 * @description 图形计算器相关基础数据结构和类型声明
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

// ==================== 函数项数据结构 ====================
export interface GraphFunctionItem {
  id: string;
  latex: string;
  base64: string;
  color: string;
  isVisible: boolean;
  ast?: string;
}