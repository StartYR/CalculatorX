/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ExchangeSnapshot.ets
 * @description 汇率用户状态与网络缓存的版本契约、校验和进程内快照
 * @author StartYi
 * @date 2026/09/30 14:00
 */
import { CurrencyListItem } from './ExchangeTypes';
import { CURRENCY_MAP } from './CurrencyData';

// 字典的继承属性不是币种；恢复和网络入口共用明确的代码白名单。
const SUPPORTED_CODES: string[] = Object.keys(CURRENCY_MAP);

export interface ExchangeUserSnapshot {
  schemaVersion: number;
  currencyList: CurrencyListItem[];
  activeId: string;
  baseAmount: string;
}

export interface ExchangeCacheSnapshot {
  schemaVersion: number;
  rates: Record<string, number>;
  fetchedAt: number;
}

export class ExchangeMemory {
  static user: ExchangeUserSnapshot | undefined = undefined;
  static cache: ExchangeCacheSnapshot | undefined = undefined;
}

export function defaultExchangeUser(): ExchangeUserSnapshot {
  const codes = ['USD', 'CNY', 'HKD', 'EUR', 'GBP', 'JPY', 'KRW'];
  return { schemaVersion: 1, currencyList: codes.map((code: string, index: number): CurrencyListItem =>
    new CurrencyListItem((index + 1).toString(), code)), activeId: '1', baseAmount: '100' };
}

/** 允许尾随小数点和换算生成的科学计数；占位符、非有限值与非法尾缀不能进入输入。 */
export function validExchangeAmount(value: Object): boolean {
  return typeof value === 'string' && value.length <= 128 &&
    /^[+-]?\d+(?:\.\d*)?(?:e[+-]?\d+)?$/i.test(value) && Number.isFinite(Number(value));
}

export function normalizeExchangeUser(raw: Object): ExchangeUserSnapshot {
  const defaults = defaultExchangeUser();
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return defaults;
  const data = raw as Record<string, Object>;
  const list: CurrencyListItem[] = [];
  const ids: Set<string> = new Set();
  if (Array.isArray(data.currencyList)) {
    (data.currencyList as Object[]).slice(0, 256).forEach((item: Object): void => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return;
      const entry = item as Record<string, Object>;
      if (typeof entry.id !== 'string' || entry.id.length === 0 || entry.id.length > 128 ||
        typeof entry.code !== 'string' || !SUPPORTED_CODES.includes(entry.code) || ids.has(entry.id)) return;
      ids.add(entry.id);
      list.push(new CurrencyListItem(entry.id, entry.code));
    });
  }
  const currencyList = list.length > 0 ? list : defaults.currencyList;
  const activeId = typeof data.activeId === 'string' && currencyList.some((item: CurrencyListItem): boolean =>
    item.id === data.activeId) ? data.activeId : currencyList[0].id;
  return { schemaVersion: 1, currencyList: currencyList, activeId: activeId,
    baseAmount: validExchangeAmount(data.baseAmount) ? data.baseAmount as string : defaults.baseAmount };
}

export function normalizeExchangeRates(raw: Object): Record<string, number> {
  const rates: Record<string, number> = {};
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return rates;
  const source = raw as Record<string, Object>;
  Object.keys(source).forEach((code: string): void => {
    const value = source[code];
    if (SUPPORTED_CODES.includes(code) && typeof value === 'number' && Number.isFinite(value) && value > 0) {
      rates[code] = value;
    }
  });
  return rates;
}

export function normalizeExchangeCache(raw: Object, now: number = Date.now()): ExchangeCacheSnapshot {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return { schemaVersion: 1, rates: {}, fetchedAt: 0 };
  const data = raw as Record<string, Object>;
  const rates = normalizeExchangeRates(data.rates);
  const time = data.fetchedAt;
  // 未来时间和空字典不能建立有效缓存；有效旧汇率仍可供离线展示。
  const fetchedAt = typeof time === 'number' && Number.isInteger(time) && time > 0 && time <= now &&
    Object.keys(rates).length > 0 ? time : 0;
  return { schemaVersion: 1, rates: rates, fetchedAt: fetchedAt };
}

/** 比较自然小时，并拒绝空缓存与未来时间。 */
export function exchangeCacheValid(cache: ExchangeCacheSnapshot, now: number = Date.now()): boolean {
  if (cache.fetchedAt <= 0 || cache.fetchedAt > now || Object.keys(cache.rates).length === 0) return false;
  const current = new Date(now);
  const saved = new Date(cache.fetchedAt);
  return current.getFullYear() === saved.getFullYear() && current.getMonth() === saved.getMonth() &&
    current.getDate() === saved.getDate() && current.getHours() === saved.getHours();
}
