/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file NumericSession.ets
 * @description 普通数值草稿、精确原值与进制切换状态
 * @author StartYi
 * @date 2026/09/28 20:30
 */
import { NumericValue, NumericDisplay, NUMERIC_RADICES, NUMERIC_PLACES, NUMERIC_INPUT_LIMIT } from './NumericValue';

/** 四个结果按 NUMERIC_RADICES 顺序缓存；无效草稿保留最近有效值，快照共享不可变值对象。 */
export class NumericSession {
  radix: number = 10;
  places: number = 32;
  text: string = '0';
  evaluated: boolean = true;
  previewValid: boolean = true;
  sourceText: string = '0';
  sourceRadix: number = 10;
  private value: NumericValue = new NumericValue();
  private displays: NumericDisplay[] = NUMERIC_RADICES.map((): NumericDisplay => ({ text: '0', approximate: false }));

  copy(): NumericSession {
    const next = new NumericSession();
    next.radix = this.radix;
    next.places = this.places;
    next.text = this.text;
    next.evaluated = this.evaluated;
    next.previewValid = this.previewValid;
    next.sourceText = this.sourceText;
    next.sourceRadix = this.sourceRadix;
    next.value = this.value;
    next.displays = this.displays.slice();
    return next;
  }

  private refresh(): void {
    this.displays = NUMERIC_RADICES.map((radix: number): NumericDisplay => this.value.format(radix, this.places));
  }

  display(radix: number): NumericDisplay {
    const index = NUMERIC_RADICES.indexOf(radix);
    if (index < 0) throw new Error('不支持的显示进制');
    return this.displays[index];
  }

  displayText(radix: number): string {
    const result = this.display(radix);
    return result.approximate ? '≈ ' + result.text + '…' : result.text;
  }

  inputEnabled(key: string): boolean {
    if (/^[0-9A-F]$/.test(key)) return parseInt(key, 16) < this.radix;
    return ['AC', '⌫', '=', '±', '.'].includes(key);
  }

  /** 成功解析才替换原值；切进制和修改显示位数均不能把截断结果写回这里。 */
  private accept(): void {
    const value = NumericValue.parse(this.text, this.radix);
    this.value = value;
    this.sourceText = this.text;
    this.sourceRadix = this.radix;
    this.previewValid = true;
    this.refresh();
  }

  replaceInput(text: string): void {
    if (text.length > NUMERIC_INPUT_LIMIT) throw new Error('最多输入 256 个字符，请缩短数值');
    this.text = text;
    this.evaluated = false;
    try { this.accept(); } catch (_) { this.previewValid = false; }
  }

  confirm(): void {
    if (this.evaluated) return;
    this.accept();
    this.evaluated = true;
  }

  changeRadix(radix: number): void {
    if (!NUMERIC_RADICES.includes(radix)) throw new Error('不支持的输入进制');
    this.confirm();
    this.radix = radix;
    this.text = radix === this.sourceRadix ? this.sourceText : this.display(radix).text;
  }

  changePlaces(places: number): void {
    if (!NUMERIC_PLACES.includes(places)) throw new Error('显示精度无效');
    this.places = places;
    this.refresh();
    if (this.evaluated && this.radix !== this.sourceRadix) this.text = this.display(this.radix).text;
  }

  /** 近似目标值不可隐式成为编辑原值；显式返回原输入进制后可继续编辑完整有限小数。 */
  editSource(): void {
    this.radix = this.sourceRadix;
    this.text = this.sourceText;
    this.evaluated = false;
    this.previewValid = true;
  }

  key(key: string): void {
    if (!this.inputEnabled(key)) return;
    if (key === '=') { this.confirm(); return; }
    if (key === 'AC') {
      this.replaceInput('0');
      this.confirm();
      return;
    }
    if (key === '±' && this.evaluated) {
      // 在原进制翻转数学符号，避免对循环小数的目标显示再次量化。
      const radix = this.radix;
      this.editSource();
      this.replaceInput(this.text.startsWith('-') ? this.text.slice(1) : '-' + this.text.replace(/^\+/, ''));
      this.confirm();
      this.changeRadix(radix);
      return;
    }
    if (key === '⌫' && this.evaluated && this.radix !== this.sourceRadix && this.display(this.radix).approximate) {
      throw new Error('当前进制显示为近似值，请先点“编辑原值”或直接输入新数值');
    }
    let text = this.text;
    if (key === '⌫') text = text.slice(0, -1) || '0';
    else if (key === '±') text = text.startsWith('-') ? text.slice(1) : '-' + text.replace(/^\+/, '');
    else if (key === '.') {
      if (this.evaluated) text = '0';
      if (text.includes('.')) return;
      text += '.';
    } else text = this.evaluated || text === '0' ? key : text === '-0' ? '-' + key : text + key;
    this.replaceInput(text);
  }
}
