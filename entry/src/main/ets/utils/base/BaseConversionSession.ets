/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BaseConversionSession.ets
 * @description 进制转换输入会话；数值、整数与浮点状态相互独立
 * @author StartYi
 * @date 2026/09/23 01:00
 */
import { Natural } from './Natural';
import { Word, Flags } from './IntegerEngine';
import { IntegerExpression } from './IntegerExpression';
import { decodeFloat, convertFloat, negateFloat } from './Ieee754';
import { FloatExpression } from './FloatExpression';
import { NumericSession } from './NumericSession';

/** 独立保存三种模式的输入；草稿与最近有效位模式允许不同，配置变更前必须确认草稿。 */
export class BaseConversionSession {
  mode: string = 'numeric';
  numeric: NumericSession = new NumericSession();
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
  // 预览仅用于显示，不写入历史或覆盖 floatBits；无效草稿保留最近一次有效预览。
  private floatPreviewBits: Natural | undefined = undefined;
  floatPreviewValid: boolean = true;

  // 撤销快照复制会话字段；Word/Natural/Flags 由运算整体替换，不在原对象上改位。
  copy(): BaseConversionSession {
    const next = new BaseConversionSession();
    next.mode = this.mode;
    next.numeric = this.numeric.copy();
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
    next.floatPreviewBits = this.floatPreviewBits;
    next.floatPreviewValid = this.floatPreviewValid;
    return next;
  }

  currentRadix(): number {
    if (this.mode === 'numeric') return this.numeric.radix;
    return this.mode === 'integer' ? this.radix : this.floatRadix;
  }
  // A–F 仅在 HEX 可用；浮点十进制语法不能混入原始位模式。
  inputEnabled(key: string): boolean {
    if (this.mode === 'numeric') return this.numeric.inputEnabled(key);
    if (/^[0-9A-F]$/.test(key)) return parseInt(key, 16) < this.currentRadix();
    if (this.mode === 'float') {
      return ['AC', '⌫', '='].includes(key) ||
        (this.floatRadix === 10 && ['.', 'e', '±', '+', '-', '*', '/', '(', ')', 'NaN', '∞'].includes(key));
    }
    return true;
  }

  // 解析成功后才替换值并置确认标志；失败保留草稿和此前有效值供继续编辑。
  confirm(): void {
    if (this.mode === 'numeric') { this.numeric.confirm(); this.error = ''; return; }
    if (this.mode === 'integer' ? this.evaluated : this.floatEvaluated) { this.error = ''; return; }
    if (this.mode === 'float') {
      const value = this.evaluateFloat();
      if (value.bits.length > this.floatWidth) throw new Error('位模式超出当前浮点格式');
      this.floatBits = value;
      this.floatEvaluated = true;
      this.floatPreviewBits = undefined;
      this.floatPreviewValid = true;
    } else {
      const result = new IntegerExpression(this.radix, this.width, this.signed, this.carry, this.previousFlags)
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
    if (this.mode === 'numeric') { this.numeric.key(key); return; }
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
      const result = new IntegerExpression(this.radix, this.width, this.signed, this.carry).evaluate(this.expression);
      this.word = result.word;
    } catch (_) {}
  }

  /** 原始位串不执行算术；十进制表达式的字面量和每步运算均按当前格式舍入。 */
  private evaluateFloat(): Natural {
    const value = this.floatRadix === 10 ? new FloatExpression(this.floatWidth).evaluate(this.floatText) :
      Natural.parse(this.floatText, this.floatRadix);
    if (value.bits.length > this.floatWidth) throw new Error('位模式超出当前浮点格式');
    return value;
  }

  /** 显示统一读取此值；确认结果、序列化与历史仍读取 floatBits。 */
  displayedFloatBits(): Natural {
    return this.floatEvaluated ? this.floatBits : this.floatPreviewBits || this.floatBits;
  }

  /** 粘贴与键盘共用预览入口；解析失败只改变有效性标志，确认时才抛出诊断。 */
  refreshFloatPreview(): void {
    if (this.floatEvaluated) {
      this.floatPreviewBits = undefined;
      this.floatPreviewValid = true;
      return;
    }
    try {
      this.floatPreviewBits = this.evaluateFloat();
      this.floatPreviewValid = true;
    } catch (_) {
      this.floatPreviewValid = false;
    }
  }

  /** 替换草稿不会隐式确认，错误粘贴也允许继续编辑，并保持此前显示与已确认位串。 */
  replaceFloatInput(text: string): void {
    if (text.length > 768) throw new Error('输入过长，请退格或清空');
    if (this.floatEvaluated) this.floatPreviewBits = this.floatBits;
    this.floatText = text;
    this.floatEvaluated = false;
    this.error = '';
    this.refreshFloatPreview();
  }

  // 浮点输入保留原文；已确认结果接续运算时以其简短十进制往返，不重新执行旧表达式。
  private floatKey(key: string): void {
    if (key === 'AC') {
      this.floatText = '0'; this.floatBits = new Natural(); this.floatEvaluated = true;
      this.refreshFloatPreview();
      return;
    }
    if (key === '±' && this.floatEvaluated) {
      // 直接改符号保留 signaling NaN 和 payload，不从显示文本重编码。
      this.floatBits = negateFloat(this.floatBits, this.floatWidth);
      this.floatText = decodeFloat(this.floatBits, this.floatWidth).decimal;
      this.refreshFloatPreview();
      return;
    }
    if (this.floatEvaluated) this.floatPreviewBits = this.floatBits;
    if (key === '⌫') this.floatText = this.floatText.trimEnd().slice(0, -1).trimEnd() || '0';
    else if (key === '±') this.toggleFloatSign();
    else if (['+', '-', '*', '/'].includes(key)) {
      if (this.floatEvaluated) this.floatText = decodeFloat(this.floatBits, this.floatWidth).decimal;
      // e 后的正负号属于指数，其余运算符使用空格分隔，避免 1 e-2 一类歧义。
      if (/[eE][+-]?$/.test(this.floatText) && (key === '+' || key === '-')) {
        this.floatText = this.floatText.replace(/[+-]$/, '') + key;
      } else this.floatText += ' ' + key + ' ';
    } else {
      const text = key === '∞' ? 'Infinity' : key;
      if (this.floatEvaluated) this.floatText = '';
      if (this.floatText === '0' && key !== '.' && key !== 'e') this.floatText = '';
      this.floatText += text;
    }
    this.floatEvaluated = false;
    this.refreshFloatPreview();
    if (this.floatText.length > 768) throw new Error('输入过长，请退格或清空');
  }

  /** ± 修改末尾操作数；未完成的科学记数法优先切换指数符号。 */
  private toggleFloatSign(): void {
    if (/[eE][+-]?$/.test(this.floatText)) {
      this.floatText = this.floatText.endsWith('-') ? this.floatText.slice(0, -1) :
        this.floatText.replace(/\+$/, '') + '-';
      return;
    }
    const match = this.floatText.match(/(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$|(?:Infinity|Inf|NaN)$/i);
    if (!match) { this.floatText += '-'; return; }
    const start = this.floatText.length - match[0].length;
    const prefix = this.floatText.slice(0, start);
    const beforeSign = prefix.slice(0, -1).trimEnd();
    const unary = /[+-]$/.test(prefix) && (beforeSign.length === 0 || /[+\-*/(]$/.test(beforeSign));
    this.floatText = (unary ? prefix.slice(0, -1) + (prefix.endsWith('-') ? '' : '-') : prefix + '-') + match[0];
  }

  // 切进制前完成确认；格式化只改变编辑表示，不改变底层位模式。
  changeRadix(radix: number): void {
    if (this.mode === 'numeric') { this.numeric.changeRadix(radix); this.error = ''; return; }
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

  // 按旧符号解释扩展或截断，并通过前后数学值比较提示有损缩窄。
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

  // 只切换解释方式，不重写位模式；十进制草稿随符号解释同步更新。
  changeSigned(): void {
    this.confirm();
    this.signed = !this.signed;
    this.expression = this.word.format(this.radix, this.signed, false);
  }

  // 从原始位模式直接转换，避免经过简短十进制文本再次舍入。
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
