/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file FloatExpression.ets
 * @description IEEE 754 十进制表达式解析及逐节点目标精度求值
 * @author StartYi
 * @date 2026/09/28 15:10
 */
import { Natural } from './Natural';
import { encodeFloat, negateFloat, operateFloat } from './IEEE754';

/** 每个字面量与二元节点分别舍入；括号和一元符号优先，乘除高于加减，同级左结合。 */
export class FloatExpression {
  private tokens: string[] = [];
  private position: number = 0;
  private width: number;

  constructor(width: number) {
    this.width = width;
  }

  /** 仅接受十进制数、科学记数法、Infinity/∞、NaN 和四则运算，不解释整数位运算。 */
  evaluate(text: string): Natural {
    if (text.length > 768) throw new Error('浮点表达式过长');
    // 指数符号属于数字 token；兜底捕获非空白字符，禁止静默跳过非法输入。
    this.tokens = text.match(/(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|Infinity|Inf|NaN|∞|[^\s]/gi) || [];
    this.position = 0;
    const result = this.expression(0, 0);
    if (this.position !== this.tokens.length) throw new Error('请检查浮点运算符或括号');
    return result;
  }

  private expression(minimum: number, depth: number): Natural {
    if (depth > 64) throw new Error('浮点表达式嵌套过深');
    let left = this.primary(depth + 1);
    while (this.position < this.tokens.length) {
      const action = this.tokens[this.position];
      const precedence = action === '+' || action === '-' ? 1 : action === '*' || action === '/' ? 2 : -1;
      if (precedence < minimum) break;
      this.position++;
      const right = this.expression(precedence + 1, depth + 1);
      left = operateFloat(action, left, right, this.width);
    }
    return left;
  }

  private primary(depth: number): Natural {
    if (depth > 64) throw new Error('浮点表达式嵌套过深');
    if (this.position >= this.tokens.length) throw new Error('浮点表达式尚未完成');
    const token = this.tokens[this.position++];
    if (token === '(') {
      const result = this.expression(0, depth + 1);
      if (this.tokens[this.position++] !== ')') throw new Error('缺少右括号');
      return result;
    }
    if (token === '+' || token === '-') {
      const operand = this.primary(depth + 1);
      return token === '-' ? negateFloat(operand, this.width) : operand;
    }
    return encodeFloat(token, this.width);
  }
}
