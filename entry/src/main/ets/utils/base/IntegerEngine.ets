/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file IntegerEngine.ets
 * @description 固定字长算术、位操作、编码与标志位
 * @author StartYi
 * @date 2026/09/22 21:00
 */
import { Natural } from './Natural';

/** 固定字长的原始位模式；构造与算术按 2^width 取模，符号解释只在需要时应用。 */
export class Word {
  value: Natural;
  width: number;

  constructor(value: Natural = new Natural(), width: number = 16) {
    if (![8, 16, 32, 64].includes(width)) throw new Error('字长必须为 8、16、32 或 64');
    this.width = width;
    this.value = value.low(width);
  }

  // 正字面量允许无符号全范围；负字面量的幅值必须处于补码可表示范围。
  static parse(text: string, radix: number, width: number): Word {
    const negative = text.startsWith('-');
    const magnitude = Natural.parse(negative || text.startsWith('+') ? text.slice(1) : text, radix);
    const limit = Natural.small(1).shift(negative ? width - 1 : width);
    if (magnitude.compare(limit) > 0 || (!negative && magnitude.compare(limit) === 0)) {
      throw new Error('输入超出当前字长，请增加字长');
    }
    const word = new Word(magnitude, width);
    return negative ? word.negate() : word;
  }

  sign(): number { return this.value.bit(this.width - 1); }
  // 补码取负采用 2^width - value；零单独处理，避免产生超宽位。
  negate(): Word {
    return new Word(this.value.isZero() ? this.value : Natural.small(1).shift(this.width).subtract(this.value), this.width);
  }
  magnitude(signed: boolean): Natural { return signed && this.sign() ? this.negate().value : this.value; }
  // 十进制按 signed 解释数学值，其他进制始终展示原始位模式。
  format(radix: number, signed: boolean = false, padded: boolean = true): string {
    if (radix === 10) return (signed && this.sign() ? '-' : '') + this.magnitude(signed).toString();
    const digits = Math.ceil(this.width / Math.log2(radix));
    return this.value.toString(radix).padStart(padded ? digits : 1, '0');
  }
  // 缩窄保留低位；扩宽仅在有符号负数时填充高位 1。
  resize(width: number, signed: boolean): Word {
    let value = this.value;
    if (width > this.width && signed && this.sign()) {
      value = value.add(Natural.small(1).shift(width).subtract(Natural.small(1).shift(this.width)));
    }
    return new Word(value, width);
  }
  flip(index: number): Word {
    if (index < 0 || index >= this.width) throw new Error('位索引无效');
    const bit = Natural.small(1).shift(index);
    return new Word(this.value.bit(index) ? this.value.subtract(bit) : this.value.add(bit), this.width);
  }
}

/** -1 表示不适用，0/1 表示已定义的标志；与 CPU 的具体指令规则无绑定。 */
export class Flags {
  cf: number = -1;
  of: number = -1;
  zf: number = -1;
  sf: number = -1;
}

export class OperationResult {
  word: Word;
  flags: Flags;
  constructor(word: Word, flags: Flags = new Flags()) {
    this.word = word;
    this.flags = flags;
  }
}

/**
 * 运算数必须同字长；carry 是独立输入，不自动继承上次 CF。
 * 加减区分无符号进位/借位与有符号溢出，乘除只保留低位并更新 ZF/SF。
 * previous 仅用于零计数移位/旋转，保持其标志不变。
 */
export function operate(action: string, left: Word, right: Word, signed: boolean,
  carry: number = 0, previous: Flags = new Flags()): OperationResult {
  const width = left.width;
  const a = left.value;
  const b = right.value;
  const limit = Natural.small(1).shift(width);
  let value = a;
  const flags = new Flags();
  if (['+', 'ADC', '-', 'SBB'].includes(action)) {
    const addition = action === '+' || action === 'ADC';
    const extra = Natural.small(action === 'ADC' || action === 'SBB' ? carry : 0);
    const operand = b.add(extra);
    // 减法先加模数再相减；截断前比较借位，截断后比较符号溢出。
    const wide = addition ? a.add(operand) : a.add(limit).subtract(operand);
    value = wide.low(width);
    flags.cf = addition ? (wide.compare(limit) >= 0 ? 1 : 0) : (a.compare(operand) < 0 ? 1 : 0);
    const sign = value.bit(width - 1);
    flags.of = addition ? (left.sign() === right.sign() && sign !== left.sign() ? 1 : 0) :
      (left.sign() !== right.sign() && sign !== left.sign() ? 1 : 0);
  } else if (action === '*') {
    value = a.multiply(b).low(width);
  } else if (action === '/' || action === 'MOD') {
    // 有符号除法先除幅值，商向零截断，余数与被除数同号。
    const division = left.magnitude(signed).divide(right.magnitude(signed));
    let result = new Word(action === '/' ? division.quotient : division.remainder, width);
    if (signed && (action === '/' ? left.sign() !== right.sign() : left.sign() === 1)) result = result.negate();
    value = result.value;
  } else if (['AND', 'OR', 'XOR', 'NOT'].includes(action)) {
    const bits: number[] = [];
    for (let i = 0; i < width; i++) {
      const x = a.bit(i);
      const y = b.bit(i);
      bits.push(action === 'AND' ? x * y : action === 'OR' ? Math.max(x, y) :
        action === 'XOR' ? (x + y) % 2 : 1 - x);
    }
    value = new Natural(bits);
  } else if (['SHL', 'SHR', 'SAR', 'ROL', 'ROR', 'RCL', 'RCR'].includes(action)) {
    const rotate = ['ROL', 'ROR', 'RCL', 'RCR'].includes(action);
    const throughCarry = action === 'RCL' || action === 'RCR';
    // 旋转按环宽取模；普通移位只需至多 width + 1 步即可确定值与最后移出位。
    const count = rotate ? b.divide(Natural.small(width + (throughCarry ? 1 : 0))).remainder.toNumber() :
      (b.compare(Natural.small(width + 1)) > 0 ? width + 1 : b.toNumber());
    if (count === 0) return new OperationResult(left, previous);
    // 带进位旋转将 CF 视为环的额外一位；普通旋转将移出位直接送回另一端。
    let outgoing = carry;
    for (let step = 0; step < count; step++) {
      const bits: number[] = [];
      const moveLeft = action === 'SHL' || action === 'ROL' || action === 'RCL';
      const bit = value.bit(moveLeft ? width - 1 : 0);
      for (let i = 0; i < width; i++) {
        if (moveLeft) bits.push(i === 0 ? (throughCarry ? outgoing : rotate ? bit : 0) : value.bit(i - 1));
        else bits.push(i === width - 1 ? (throughCarry ? outgoing : rotate ? bit :
          action === 'SAR' ? value.bit(width - 1) : 0) : value.bit(i + 1));
      }
      outgoing = bit;
      value = new Natural(bits);
    }
    flags.cf = outgoing;
    if (count === 1 && !rotate) flags.of = action === 'SHL' ? (value.bit(width - 1) + outgoing) % 2 :
      action === 'SHR' ? left.sign() : 0;
    if (rotate) return new OperationResult(new Word(value, width), flags);
  } else throw new Error('不支持的运算');
  flags.zf = value.isZero() ? 1 : 0;
  flags.sf = value.bit(width - 1);
  return new OperationResult(new Word(value, width), flags);
}

export interface EncodingRow { name: string; bits: string; value: string; }

// 按数学值重新编码；原码/反码比补码少一个负数，超范围时不伪造同宽编码。
export function encodingRows(word: Word, signed: boolean): EncodingRow[] {
  const negative = signed && word.sign() === 1;
  const magnitude = word.magnitude(signed);
  const signBit = Natural.small(1).shift(word.width - 1);
  const fits = magnitude.compare(signBit) < 0;
  const signMagnitude = negative ? magnitude.add(signBit) : magnitude;
  const ones = negative ? Natural.small(1).shift(word.width).subtract(Natural.small(1)).subtract(magnitude) : magnitude;
  return [
    { name: '无符号', bits: negative ? '同宽不可表示' : word.format(2), value: word.format(10, signed) },
    { name: '补码', bits: negative || fits ? word.format(2) : '同宽不可表示', value: word.format(10, signed) },
    { name: '原码', bits: fits ? new Word(signMagnitude, word.width).format(2) : '同宽不可表示', value: word.format(10, signed) },
    { name: '反码', bits: fits ? new Word(ones, word.width).format(2) : '同宽不可表示', value: word.format(10, signed) }
  ];
}

// 将同一原始位串按指定编码解释；原码/反码必须保留负零。
export function decodeEncoding(word: Word, encoding: string): string {
  if (encoding === '补码') return word.format(10, true);
  if (encoding === '无符号') return word.format(10);
  const negative = word.sign() === 1;
  const magnitude = encoding === '原码' ? word.value.low(word.width - 1) : negative ?
    Natural.small(1).shift(word.width).subtract(Natural.small(1)).subtract(word.value) : word.value;
  return (negative ? '-' : '') + magnitude.toString();
}
