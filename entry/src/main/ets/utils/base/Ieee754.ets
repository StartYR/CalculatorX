/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file Ieee754.ets
 * @description IEEE 754 二进制格式及精确十进制有理数舍入
 */
import { Natural } from './Natural';

export class FloatFormat {
  width: number;
  exponentBits: number;
  fractionBits: number;
  bias: number;
  constructor(width: number) {
    if (![16, 32, 64].includes(width)) throw new Error('不支持的浮点格式');
    this.width = width;
    this.exponentBits = width === 16 ? 5 : width === 32 ? 8 : 11;
    this.fractionBits = width - this.exponentBits - 1;
    this.bias = Math.pow(2, this.exponentBits - 1) - 1;
  }
}

export class FloatDetails {
  sign: number = 0;
  exponent: number = 0;
  actualExponent: number = 0;
  fraction: string = '';
  category: string = '';
  decimal: string = '';
  exact: string = '';
  payload: string = '';
}

function compose(format: FloatFormat, sign: number, exponent: number, fraction: Natural): Natural {
  return Natural.small(sign).shift(format.width - 1)
    .add(Natural.small(exponent).shift(format.fractionBits)).add(fraction);
}

function roundEven(numerator: Natural, denominator: Natural, shift: number): Natural {
  const division = (shift >= 0 ? numerator.shift(shift) : numerator)
    .divide(shift >= 0 ? denominator : denominator.shift(-shift));
  const comparison = division.remainder.shift(1).compare(shift >= 0 ? denominator : denominator.shift(-shift));
  return comparison > 0 || (comparison === 0 && division.quotient.bit(0) === 1) ?
    division.quotient.add(Natural.small(1)) : division.quotient;
}

export function encodeFloat(text: string, width: number): Natural {
  const format = new FloatFormat(width);
  const input = text.trim().toLowerCase();
  const sign = input.startsWith('-') ? 1 : 0;
  const maximumExponent = Math.pow(2, format.exponentBits) - 1;
  if (/^[+-]?(infinity|inf|∞)$/.test(input)) return compose(format, sign, maximumExponent, new Natural());
  if (/^[+-]?nan$/.test(input)) return compose(format, sign, maximumExponent, Natural.small(1).shift(format.fractionBits - 1));
  if (input.length > 768 || !/^[+-]?(\d+(\.\d*)?|\.\d+)(e[+-]?\d+)?$/.test(input)) {
    throw new Error('请输入十进制数、Infinity 或 NaN');
  }
  const unsigned = input.replace(/^[+-]/, '');
  const parts = unsigned.split('e');
  const decimal = parts[0].split('.');
  const digits = (decimal[0] + (decimal.length > 1 ? decimal[1] : '')).replace(/^0+/, '');
  if (digits.length === 0) return compose(format, sign, 0, new Natural());
  const power = (parts.length > 1 ? Number(parts[1]) : 0) - (decimal.length > 1 ? decimal[1].length : 0);
  // 全格式共同的远端边界，避免为巨大十进制指数分配位数组。
  if (power + digits.length > 310) return compose(format, sign, maximumExponent, new Natural());
  if (power + digits.length < -400) return compose(format, sign, 0, new Natural());
  let numerator = Natural.parse(digits, 10);
  let denominator = Natural.small(1);
  const tenPower = Natural.parse('1' + '0'.repeat(Math.abs(power)), 10);
  if (power >= 0) numerator = numerator.multiply(tenPower);
  else denominator = tenPower;
  let exponent = numerator.bits.length - denominator.bits.length;
  if ((exponent >= 0 ? numerator.compare(denominator.shift(exponent)) : numerator.shift(-exponent).compare(denominator)) < 0) {
    exponent--;
  }
  const minimum = 1 - format.bias;
  if (exponent < minimum) {
    const fraction = roundEven(numerator, denominator, format.fractionBits - minimum);
    // 非正规数舍入可能跨越至最小正规数。
    return compose(format, sign, fraction.bit(format.fractionBits), fraction.low(format.fractionBits));
  }
  let significand = roundEven(numerator, denominator, format.fractionBits - exponent);
  if (significand.bits.length > format.fractionBits + 1) {
    exponent++;
    significand = significand.shift(-1);
  }
  if (exponent + format.bias >= maximumExponent) return compose(format, sign, maximumExponent, new Natural());
  return compose(format, sign, exponent + format.bias, significand.low(format.fractionBits));
}

export function decodeFloat(bits: Natural, width: number): FloatDetails {
  const format = new FloatFormat(width);
  if (bits.bits.length > width) throw new Error('位模式超出浮点格式宽度');
  const result = new FloatDetails();
  result.sign = bits.bit(width - 1);
  result.exponent = bits.shift(-format.fractionBits).low(format.exponentBits).toNumber();
  result.actualExponent = (result.exponent === 0 ? 1 : result.exponent) - format.bias;
  const fraction = bits.low(format.fractionBits);
  result.fraction = fraction.toString(2).padStart(format.fractionBits, '0');
  const prefix = result.sign ? '-' : '';
  if (result.exponent === Math.pow(2, format.exponentBits) - 1) {
    result.category = fraction.isZero() ? '无穷' : fraction.bit(format.fractionBits - 1) ? 'quiet NaN' : 'signaling NaN';
    result.decimal = fraction.isZero() ? prefix + 'Infinity' : 'NaN';
    result.payload = fraction.low(format.fractionBits - 1).toString(16);
    result.exact = fraction.isZero() ? prefix + '∞' : 'payload = 0x' + result.payload;
    return result;
  }
  const significand = result.exponent === 0 ? fraction : Natural.small(1).shift(format.fractionBits).add(fraction);
  result.category = significand.isZero() ? (result.sign ? '负零' : '正零') : result.exponent === 0 ? '非正规数' : '正规数';
  const power = result.actualExponent - format.fractionBits;
  // 先按尾数位数缩放，避免 binary64 非正规数的中间幂下溢。
  const value = significand.toNumber() / Math.pow(2, format.fractionBits) * Math.pow(2, result.actualExponent);
  result.decimal = prefix + value.toString();
  result.exact = prefix + significand.toString() + ' × 2^' + power.toString();
  return result;
}
