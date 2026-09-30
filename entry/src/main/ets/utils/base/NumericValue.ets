/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file NumericValue.ets
 * @description 普通数值的精确有理数表示与四进制格式化
 * @author StartYi
 * @date 2026/09/28 20:30
 */
import { Natural } from './Natural';

export const NUMERIC_RADICES: number[] = [16, 10, 8, 2];
export const NUMERIC_PLACES: number[] = [16, 32, 64, 128];
export const NUMERIC_INPUT_LIMIT: number = 256;

/** text 是向零截断的显示值；只有 remainder 为零时才能作为精确值重新解析。 */
export class NumericDisplay {
  text: string = '0';
  approximate: boolean = false;
}

/** 分子、分母保存绝对值，符号独立；无固定字长，也不使用宿主浮点数承载完整数值。 */
export class NumericValue {
  private numerator: Natural;
  private denominator: Natural;
  private negative: boolean;

  constructor(numerator: Natural = new Natural(), denominator: Natural = Natural.small(1), negative: boolean = false) {
    if (denominator.isZero()) throw new Error('分母不能为零');
    this.numerator = numerator;
    this.denominator = denominator;
    this.negative = negative && !numerator.isZero();
  }

  /** 仅接收当前进制的有限小数；E 在 HEX 中是数字，不作为指数或前缀解释。 */
  static parse(text: string, radix: number): NumericValue {
    if (!NUMERIC_RADICES.includes(radix)) throw new Error('不支持的输入进制');
    if (text.length > NUMERIC_INPUT_LIMIT) throw new Error('最多输入 256 个字符，请缩短数值');
    if (!/^[+-]?(?:[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]*)?|\.[0-9A-Fa-f]+)$/.test(text)) {
      throw new Error('请输入完整数值，仅支持正负号、数字和一个小数点');
    }
    const negative = text.startsWith('-');
    const unsigned = /^[+-]/.test(text) ? text.slice(1) : text;
    const parts = unsigned.split('.');
    const fraction = parts.length === 2 ? parts[1] : '';
    const numerator = Natural.parse((parts[0] || '0') + fraction, radix);
    let denominator = Natural.small(1);
    const base = Natural.small(radix);
    for (let i = 0; i < fraction.length; i++) denominator = denominator.multiply(base);
    return new NumericValue(numerator, denominator, negative);
  }

  /**
   * 长除产生目标进制的每一位；显示上限只限制小数部分，整数部分始终完整输出。
   * 未耗尽的余数代表近似值，循环小数和有限但超长的小数采用相同的截断标识。
   */
  format(radix: number, places: number): NumericDisplay {
    if (!NUMERIC_RADICES.includes(radix) || !NUMERIC_PLACES.includes(places)) {
      throw new Error('进制或显示精度无效');
    }
    const division = this.numerator.divide(this.denominator);
    let remainder = division.remainder;
    let fraction = '';
    const base = Natural.small(radix);
    const alphabet = '0123456789ABCDEF';
    for (let i = 0; i < places && !remainder.isZero(); i++) {
      remainder = remainder.multiply(base);
      // 每步商小于 radix；小商减法避免对大分母反复执行完整二进制长除。
      let digit = 0;
      while (remainder.compare(this.denominator) >= 0) {
        remainder = remainder.subtract(this.denominator);
        digit++;
      }
      fraction += alphabet.charAt(digit);
    }
    const text = (this.negative ? '-' : '') + division.quotient.toString(radix) +
      (fraction.length > 0 ? '.' + fraction : '');
    return { text: text, approximate: !remainder.isZero() };
  }
}
