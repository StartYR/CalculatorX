/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file ExchangeTypes.ets
 * @description 汇率模块的类型与接口声明文件
 * @author 易睿 (Yi Rui)
 * @date 2026/8/16 17:58
 */

/**
 * 列表项数据模型
 */
export class CurrencyListItem {
  id: string;
  code: string;

  constructor(id: string, code: string) {
    this.id = id;
    this.code = code;
  }
}

/**
 * 定义网络请求返回的 JSON 结构
 */
export interface ExchangeApiResponse {
  disclaimer?: string;
  license?: string;
  timestamp?: number;
  base?: string;
  rates: Record<string, number>; // 核心数据：键是字符串(货币代码)，值是数字(汇率)
}