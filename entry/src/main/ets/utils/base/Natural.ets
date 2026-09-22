/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file Natural.ets
 * @description 使用低位在前的二进制数组执行精确非负整数运算
 * @author StartYi
 * @date 2026/09/22 21:00
 */
export class Natural {
  bits: number[];

  constructor(bits: number[] = []) {
    this.bits = bits.slice();
    while (this.bits.length > 0 && this.bits[this.bits.length - 1] === 0) this.bits.pop();
  }

  static small(value: number): Natural {
    const bits: number[] = [];
    while (value > 0) {
      bits.push(value % 2);
      value = Math.floor(value / 2);
    }
    return new Natural(bits);
  }

  static parse(text: string, radix: number): Natural {
    if (radix < 2 || radix > 36 || text.length === 0 || text.length > 4096) {
      throw new Error('输入长度或进制无效');
    }
    let value = new Natural();
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (let i = 0; i < text.length; i++) {
      const digit = alphabet.indexOf(text[i].toUpperCase());
      if (digit < 0 || digit >= radix) throw new Error('包含当前进制不支持的数字');
      value = value.multiply(Natural.small(radix)).add(Natural.small(digit));
    }
    return value;
  }

  isZero(): boolean { return this.bits.length === 0; }
  bit(index: number): number { return this.bits[index] || 0; }
  compare(other: Natural): number {
    if (this.bits.length !== other.bits.length) return this.bits.length > other.bits.length ? 1 : -1;
    for (let i = this.bits.length - 1; i >= 0; i--) {
      if (this.bit(i) !== other.bit(i)) return this.bit(i) > other.bit(i) ? 1 : -1;
    }
    return 0;
  }

  add(other: Natural): Natural {
    const bits: number[] = [];
    let carry = 0;
    for (let i = 0; i < Math.max(this.bits.length, other.bits.length) || carry > 0; i++) {
      const sum = this.bit(i) + other.bit(i) + carry;
      bits.push(sum % 2);
      carry = Math.floor(sum / 2);
    }
    return new Natural(bits);
  }

  subtract(other: Natural): Natural {
    if (this.compare(other) < 0) throw new Error('非负整数减法越界');
    const bits: number[] = [];
    let borrow = 0;
    for (let i = 0; i < this.bits.length; i++) {
      const difference = this.bit(i) - other.bit(i) - borrow;
      bits.push((difference + 2) % 2);
      borrow = difference < 0 ? 1 : 0;
    }
    return new Natural(bits);
  }

  shift(count: number): Natural {
    if (count < 0) return new Natural(this.bits.slice(-count));
    if (this.isZero()) return new Natural();
    const zeros: number[] = [];
    for (let i = 0; i < count; i++) zeros.push(0);
    return new Natural(zeros.concat(this.bits));
  }

  low(width: number): Natural { return new Natural(this.bits.slice(0, width)); }

  multiply(other: Natural): Natural {
    let result = new Natural();
    for (let i = 0; i < other.bits.length; i++) {
      if (other.bit(i)) result = result.add(this.shift(i));
    }
    return result;
  }

  divide(other: Natural): NaturalDivision {
    if (other.isZero()) throw new Error('除数不能为零');
    let remainder = new Natural();
    const quotient: number[] = [];
    for (let i = this.bits.length - 1; i >= 0; i--) {
      remainder = remainder.shift(1).add(Natural.small(this.bit(i)));
      quotient[i] = remainder.compare(other) >= 0 ? 1 : 0;
      if (quotient[i]) remainder = remainder.subtract(other);
    }
    return { quotient: new Natural(quotient), remainder: remainder };
  }

  toNumber(): number {
    if (this.bits.length > 53) throw new Error('整数超出安全数值范围');
    let value = 0;
    for (let i = this.bits.length - 1; i >= 0; i--) value = value * 2 + this.bit(i);
    return value;
  }

  toString(radix: number = 10): string {
    if (this.isZero()) return '0';
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let bits = this.bits.slice();
    let output = '';
    // 小除数长除法避免十进制格式化重复创建大位向量。
    while (bits.length > 0) {
      let remainder = 0;
      const next: number[] = [];
      for (let i = bits.length - 1; i >= 0; i--) {
        remainder = remainder * 2 + bits[i];
        next[i] = Math.floor(remainder / radix);
        remainder %= radix;
      }
      output = alphabet[remainder] + output;
      while (next.length > 0 && next[next.length - 1] === 0) next.pop();
      bits = next;
    }
    return output;
  }
}

export interface NaturalDivision {
  quotient: Natural;
  remainder: Natural;
}
