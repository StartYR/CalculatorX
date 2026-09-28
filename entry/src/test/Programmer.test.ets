/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file Programmer.test.ets
 * @description 程序员核心精度、舍入与会话切换的 ArkTS 回归测试
 * @author StartYi
 * @date 2026/09/23 01:00
 */
import { describe, it, expect } from '@ohos/hypium';
import { Word } from '../main/ets/utils/base/ProgrammerEngine';
import { ProgrammerExpression } from '../main/ets/utils/base/ProgrammerExpression';
import { FloatExpression } from '../main/ets/utils/base/FloatExpression';
import { encodeFloat, convertFloat } from '../main/ets/utils/base/Ieee754';
import { ProgrammerSession } from '../main/ets/utils/base/ProgrammerSession';

export default function programmerTest() {
  describe('Programmer', () => {
    it('retainsAll64Bits', 0, () => {
      expect(Word.parse('18446744073709551615', 10, 64).format(16)).assertEqual('FFFFFFFFFFFFFFFF');
      expect(Word.parse('9007199254740993', 10, 64).format(10)).assertEqual('9007199254740993');
    });
    it('evaluatesPrecedenceAndCarry', 0, () => {
      const parser = new ProgrammerExpression(10, 8, false);
      expect(parser.evaluate('2 + 3 * 4').word.format(10)).assertEqual('14');
      const result = parser.evaluate('255 + 1');
      expect(result.word.format(10)).assertEqual('0');
      expect(result.flags.cf).assertEqual(1);
      expect(result.flags.of).assertEqual(0);
    });
    // 该输入略高于 binary16 中点，先经 binary64 会抹掉偏差，暴露双重舍入问题。
    it('roundsDirectlyToTargetFormat', 0, () => {
      expect(encodeFloat('1.000488281250000000000001', 16).toString(16)).assertEqual('3C01');
      expect(convertFloat(encodeFloat('1.00048828125', 64), 64, 16).toString(16)).assertEqual('3C00');
    });
    it('keepsBitsWhenChangingRadix', 0, () => {
      const session = new ProgrammerSession();
      session.key('1'); session.key('+'); session.key('2'); session.key('=');
      session.changeRadix(16);
      expect(session.word.format(10)).assertEqual('3');
      expect(session.expression).assertEqual('3');
    });
    it('roundsEachFloatOperationAtSelectedWidth', 0, () => {
      // binary16 中 2048 + 1 位于中点，偶数舍入得到 2048，随后相减为零。
      expect(new FloatExpression(16).evaluate('2048 + 1 - 2048').toString(16)).assertEqual('0');
      expect(new FloatExpression(32).evaluate('2 + 3 * 4').toString(16)).assertEqual('41600000');
      expect(new FloatExpression(64).evaluate('1 / -0').toString(16)).assertEqual('FFF0000000000000');
    });
    it('continuesFloatCalculationFromConfirmedResult', 0, () => {
      const session = new ProgrammerSession();
      session.mode = 'float';
      for (const key of ['2', '+', '3', '=', '*', '4', '=']) session.key(key);
      expect(session.floatBits.toString(16)).assertEqual('41A00000');
      session.changeRadix(16);
      expect(session.inputEnabled('*')).assertFalse();
    });
  });
}
