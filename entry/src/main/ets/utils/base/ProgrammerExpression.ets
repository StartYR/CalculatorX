/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ProgrammerExpression.ets
 * @description 固定字长表达式解析与优先级求值
 */
import { Word, Flags, OperationResult, operate } from './ProgrammerEngine';

export class ProgrammerExpression {
  private tokens: string[] = [];
  private position: number = 0;
  private radix: number;
  private width: number;
  private signed: boolean;
  private carry: number;
  private flags: Flags;

  constructor(radix: number, width: number, signed: boolean, carry: number = 0, flags: Flags = new Flags()) {
    this.radix = radix;
    this.width = width;
    this.signed = signed;
    this.carry = carry;
    this.flags = flags;
  }

  evaluate(text: string): OperationResult {
    if (text.length > 1024) throw new Error('表达式过长');
    this.tokens = text.toUpperCase().match(/[0-9A-Z]+|[()+\-*/]|[^\s]/g) || [];
    this.position = 0;
    const result = this.expression(0, 0);
    if (this.position !== this.tokens.length) throw new Error('请检查运算符或括号');
    return new OperationResult(result, this.flags);
  }

  private precedence(token: string): number {
    if (token === 'OR') return 1;
    if (token === 'XOR') return 2;
    if (token === 'AND') return 3;
    if (['SHL', 'SHR', 'SAR', 'ROL', 'ROR', 'RCL', 'RCR'].includes(token)) return 4;
    if (['+', '-', 'ADC', 'SBB'].includes(token)) return 5;
    if (['*', '/', 'MOD'].includes(token)) return 6;
    return -1;
  }

  private expression(minimum: number, depth: number): Word {
    if (depth > 64) throw new Error('括号或一元运算嵌套过深');
    let left = this.primary(depth + 1);
    while (this.position < this.tokens.length) {
      const action = this.tokens[this.position];
      const precedence = this.precedence(action);
      if (precedence < minimum) break;
      this.position++;
      const right = this.expression(precedence + 1, depth + 1);
      if (precedence === 4 && this.signed && right.sign()) throw new Error('移位计数不能为负数');
      const result = operate(action, left, right, this.signed, this.carry, this.flags);
      left = result.word;
      this.flags = result.flags;
    }
    return left;
  }

  private primary(depth: number): Word {
    if (depth > 64) throw new Error('括号或一元运算嵌套过深');
    if (this.position >= this.tokens.length) throw new Error('表达式尚未完成');
    const token = this.tokens[this.position++];
    if (token === '(') {
      const result = this.expression(0, depth + 1);
      if (this.tokens[this.position++] !== ')') throw new Error('缺少右括号');
      return result;
    }
    if (token === '+' || token === '-' || token === 'NOT') {
      const operand = this.primary(depth + 1);
      if (token === '+') return operand;
      const result = operate(token === '-' ? '-' : 'NOT', token === '-' ? new Word(undefined, this.width) : operand,
        operand, this.signed, this.carry, this.flags);
      this.flags = result.flags;
      return result.word;
    }
    return Word.parse(token, this.radix, this.width);
  }
}
