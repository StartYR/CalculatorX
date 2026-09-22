/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ProgrammerSession.ets
 * @description 程序员输入会话；整数与浮点状态相互独立
 */
import { Natural } from './Natural';
import { Word, Flags } from './ProgrammerEngine';
import { ProgrammerExpression } from './ProgrammerExpression';
import { encodeFloat, decodeFloat, convertFloat } from './Ieee754';

export class ProgrammerSession {
  mode: string = 'integer';
  radix: number = 10;
  width: number = 16;
  signed: boolean = true;
  carry: number = 0;
  expression: string = '0';
  word: Word = new Word();
  flags: Flags = new Flags();
  previousFlags: Flags = new Flags();
  evaluated: boolean = true;
  error: string = '';
  floatWidth: number = 32;
  floatRadix: number = 10;
  floatText: string = '0';
  floatBits: Natural = new Natural();
  floatEvaluated: boolean = true;

  copy(): ProgrammerSession {
    const next = new ProgrammerSession();
    next.mode = this.mode;
    next.radix = this.radix;
    next.width = this.width;
    next.signed = this.signed;
    next.carry = this.carry;
    next.expression = this.expression;
    next.word = this.word;
    next.flags = this.flags;
    next.previousFlags = this.previousFlags;
    next.evaluated = this.evaluated;
    next.error = this.error;
    next.floatWidth = this.floatWidth;
    next.floatRadix = this.floatRadix;
    next.floatText = this.floatText;
    next.floatBits = this.floatBits;
    next.floatEvaluated = this.floatEvaluated;
    return next;
  }

  currentRadix(): number { return this.mode === 'integer' ? this.radix : this.floatRadix; }
  inputEnabled(key: string): boolean {
    if (/^[0-9A-F]$/.test(key)) return parseInt(key, 16) < this.currentRadix();
    if (this.mode === 'float' && ['.', 'e', '±', '+', '-', 'NaN', '∞'].includes(key)) return this.floatRadix === 10;
    return true;
  }

  confirm(): void {
    if (this.mode === 'integer' ? this.evaluated : this.floatEvaluated) { this.error = ''; return; }
    if (this.mode === 'float') {
      const value = this.floatRadix === 10 ? encodeFloat(this.floatText, this.floatWidth) :
        Natural.parse(this.floatText, this.floatRadix);
      if (value.bits.length > this.floatWidth) throw new Error('位模式超出当前浮点格式');
      this.floatBits = value;
      this.floatEvaluated = true;
    } else {
      const result = new ProgrammerExpression(this.radix, this.width, this.signed, this.carry, this.previousFlags)
        .evaluate(this.expression);
      this.word = result.word;
      this.flags = result.flags;
      this.previousFlags = result.flags;
      this.evaluated = true;
    }
    this.error = '';
  }

  key(key: string): void {
    if (!this.inputEnabled(key)) return;
    this.error = '';
    if (key === '=') { this.confirm(); return; }
    if (this.mode === 'float') { this.floatKey(key); return; }
    if (key === 'AC') {
      this.expression = '0'; this.word = new Word(undefined, this.width);
      this.flags = new Flags(); this.previousFlags = new Flags(); this.evaluated = true;
      return;
    }
    if (key === '⌫') {
      this.expression = this.expression.trimEnd().replace(/(?:\s(?:AND|OR|XOR|SHL|SHR|SAR|ROL|ROR|RCL|RCR|ADC|SBB|MOD)|NOT|.)$/, '').trimEnd() || '0';
    } else if (key === '±') {
      this.expression = '- ( ' + (this.evaluated ? this.word.format(this.radix, this.signed, false) : this.expression) + ' )';
    } else if (/^[0-9A-F]$/.test(key)) {
      if (this.evaluated) this.previousFlags = new Flags();
      this.expression = this.evaluated || this.expression === '0' ? key : this.expression + key;
    } else if (key === '(' || key === 'NOT') {
      if (this.evaluated) this.previousFlags = new Flags();
      this.expression = (this.evaluated ? '' : this.expression) + key + ' ';
    } else if (key === ')') {
      this.expression += ' )';
    } else {
      if (this.evaluated) this.expression = this.word.format(this.radix, this.signed, false);
      this.expression += ' ' + key + ' ';
    }
    this.evaluated = false;
    this.flags = new Flags();
    if (this.expression.length > 1024) throw new Error('表达式过长，请退格或清空');
    // 不完整草稿保留上一个有效结果，确认时才显示语法诊断。
    try {
      const result = new ProgrammerExpression(this.radix, this.width, this.signed, this.carry).evaluate(this.expression);
      this.word = result.word;
    } catch (_) {}
  }

  private floatKey(key: string): void {
    if (key === 'AC') {
      this.floatText = '0'; this.floatBits = new Natural(); this.floatEvaluated = true;
      return;
    }
    if (key === '⌫') this.floatText = this.floatText.slice(0, -1) || '0';
    else if (key === '±') this.floatText = this.floatText.startsWith('-') ? this.floatText.slice(1) : '-' + this.floatText;
    else if (key === 'NaN' || key === '∞') this.floatText = key === '∞' ? 'Infinity' : key;
    else this.floatText = (this.floatEvaluated || this.floatText === '0' ? '' : this.floatText) + key;
    this.floatEvaluated = false;
    if (this.floatText.length > 768) throw new Error('输入过长，请退格或清空');
  }

  changeRadix(radix: number): void {
    this.confirm();
    if (this.mode === 'float') {
      this.floatRadix = radix;
      this.floatText = radix === 10 ? decodeFloat(this.floatBits, this.floatWidth).decimal :
        this.floatBits.toString(radix).padStart(radix === 16 ? this.floatWidth / 4 : this.floatWidth, '0');
    } else {
      this.radix = radix;
      this.expression = this.word.format(radix, this.signed, false);
    }
  }

  changeWidth(width: number): void {
    this.confirm();
    const before = this.word.format(10, this.signed);
    this.word = this.word.resize(width, this.signed);
    this.width = width;
    this.expression = this.word.format(this.radix, this.signed, false);
    this.flags = new Flags();
    this.previousFlags = new Flags();
    if (before !== this.word.format(10, this.signed)) this.error = '已保留低 ' + width + ' 位，高位截断改变了数值';
  }

  changeSigned(): void {
    this.confirm();
    this.signed = !this.signed;
    this.expression = this.word.format(this.radix, this.signed, false);
  }

  changeFloatWidth(width: number): void {
    this.confirm();
    const bits = convertFloat(this.floatBits, this.floatWidth, width);
    this.floatWidth = width;
    this.floatBits = bits;
    this.floatText = this.floatRadix === 10 ? decodeFloat(bits, width).decimal : bits.toString(this.floatRadix);
    this.floatEvaluated = true;
  }

  flip(index: number): void {
    this.confirm();
    if (this.mode === 'integer') {
      this.word = this.word.flip(index);
      this.expression = this.word.format(this.radix, this.signed, false);
      this.flags = new Flags();
      this.previousFlags = new Flags();
    } else {
      this.floatBits = new Word(this.floatBits, this.floatWidth).flip(index).value;
      // 位编辑切换到原始 HEX，避免重新编码 NaN 时丢失 payload。
      this.floatRadix = 16;
      this.floatText = this.floatBits.toString(16).padStart(this.floatWidth / 4, '0');
      this.floatEvaluated = true;
    }
  }
}
