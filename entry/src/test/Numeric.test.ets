/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file Numeric.test.ets
 * @description 数值转换的精度、会话与历史恢复回归
 * @author StartYi
 * @date 2026/09/28 20:38
 */
import { describe, it, expect } from '@ohos/hypium';

import { binaryRows } from '../main/ets/utils/base/BinaryDisplay';
import { NumericValue } from '../main/ets/utils/base/NumericValue';
import { BaseConversionSession } from '../main/ets/utils/base/BaseConversionSession';
import { historyRecordOf, restoreRecord } from '../main/ets/utils/base/BaseConversionState';

export default function numericTest(): void {
  describe('Numeric', () => {
    it('defaultsToNumericAndGroupsBinaryDigits', 0, () => {
      expect(new BaseConversionSession().mode).assertEqual('numeric');
      const text = '≈ -' + '1'.repeat(32) + '.' + '0'.repeat(32) + '1…';
      const rows = binaryRows(text);
      expect(rows.length).assertEqual(3);
      expect(rows[0]).assertEqual('≈ -' + '1'.repeat(32) + '.');
      expect(rows[1]).assertEqual('0'.repeat(32));
      expect(rows[2]).assertEqual('1…');
      expect(rows.join('')).assertEqual(text);
    });
    it('convertsBeyond64BitsWithoutTruncation', 0, () => {
      expect(NumericValue.parse('18446744073709551616', 10).format(16, 32).text)
        .assertEqual('10000000000000000');
      expect(NumericValue.parse('-FF.A', 16).format(10, 32).text).assertEqual('-255.625');
    });
    it('keepsExactSourceAcrossApproximateDisplays', 0, () => {
      const session = new BaseConversionSession();
      session.mode = 'numeric';
      session.numeric.replaceInput('0.1');
      session.changeRadix(2);
      expect(session.numeric.display(2).approximate).assertTrue();
      session.changeRadix(16);
      session.changeRadix(10);
      expect(session.numeric.display(10).text).assertEqual('0.1');
    });
    it('restoresExactHistoryInsteadOfTruncatedText', 0, () => {
      const session = new BaseConversionSession();
      session.mode = 'numeric';
      session.numeric.replaceInput('0.1');
      session.changeRadix(2);
      session.key('±');
      const restored = restoreRecord(JSON.stringify(historyRecordOf(session)));
      expect(restored.numeric.radix).assertEqual(2);
      expect(restored.numeric.display(10).text).assertEqual('-0.1');
    });
    it('isolatesDraftsAndUndoSnapshots', 0, () => {
      const session = new BaseConversionSession();
      session.mode = 'integer';
      session.key('7');
      session.mode = 'numeric';
      session.numeric.replaceInput('5.5');
      const before = session.copy();
      session.numeric.replaceInput('1..2');
      expect(session.numeric.previewValid).assertFalse();
      expect(session.numeric.display(10).text).assertEqual('5.5');
      session.key('AC');
      expect(before.numeric.text).assertEqual('5.5');
      expect(session.expression).assertEqual('7');
    });
  });
}
