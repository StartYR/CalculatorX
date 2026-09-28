// 在宿主机执行纯 ArkTS 核心；BigInt 和 DataView 仅作为独立测试参照。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

// 宿主机只擦除纯核心类型，不模拟 ArkUI；框架类型错误仍需 ArkTS 工具验证。
registerHooks({
  resolve(specifier, context, next) {
    if (context.parentURL?.endsWith('.ets') && specifier.startsWith('./')) specifier += '.ets';
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', shortCircuit: true,
      source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')) };
    return next(url, context);
  }
});
const { NumericValue, NUMERIC_INPUT_LIMIT } = await import('../entry/src/main/ets/utils/base/NumericValue.ets');
const { NumericSession } = await import('../entry/src/main/ets/utils/base/NumericSession.ets');
const { BaseConversionSession } = await import('../entry/src/main/ets/utils/base/BaseConversionSession.ets');
const { recordOf, historyRecordOf, restoreRecord, settingsOf, restoreSettings } = await import('../entry/src/main/ets/utils/base/BaseConversionState.ets');
let checks = 0;
function equal(actual, expected) { assert.deepEqual(actual, expected); checks++; }
function rejects(action) { assert.throws(action); checks++; }
// BigInt 长除作为独立参照，生产 ArkTS 核心只使用 Natural。
function reference(numerator, denominator, radix, places) {
  const negative = numerator < 0n;
  let value = negative ? -numerator : numerator;
  let text = (negative ? '-' : '') + (value / denominator).toString(radix).toUpperCase();
  let remainder = value % denominator;
  if (remainder) text += '.';
  for (let i = 0; i < places && remainder; i++) {
    remainder *= BigInt(radix);
    text += (remainder / denominator).toString(radix).toUpperCase();
    remainder %= denominator;
  }
  return { text, approximate: remainder !== 0n };
}
for (const [input, radix, target, output] of [
  ['-FF.A', 16, 10, '-255.625'], ['101.101', 2, 10, '5.625'],
  ['.5', 10, 2, '0.1'], ['+0001.', 10, 16, '1'], ['-0.0', 10, 10, '0'],
  ['18446744073709551616', 10, 16, '10000000000000000'],
  ['9007199254740993.5', 10, 16, '20000000000001.8'], ['1e2', 16, 10, '482']
]) equal(NumericValue.parse(input, radix).format(target, 32), { text: output, approximate: false });
for (const input of ['', '-', '.', '-.', '1..2', '1e2', 'NaN', 'Infinity', '0x10', '1/3', '1 2', '≈ 0.1…']) {
  rejects(() => NumericValue.parse(input, 10));
}
rejects(() => NumericValue.parse('2', 2));
rejects(() => NumericValue.parse('8', 8));
rejects(() => NumericValue.parse('1', 3));
rejects(() => NumericValue.parse('1'.repeat(NUMERIC_INPUT_LIMIT + 1), 10));
const huge = 'F'.repeat(256);
equal(NumericValue.parse(huge, 16).format(2, 32).text, '1'.repeat(1024));
equal(NumericValue.parse('0.' + '0'.repeat(100) + '1', 10).format(10, 32).approximate, true);
equal(NumericValue.parse('0.' + '0'.repeat(100) + '1', 10).format(10, 128).approximate, false);
let seed = 0x170;
function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed; }
for (const from of [2, 8, 10, 16]) for (let sample = 0; sample < 90; sample++) {
  const value = (BigInt(random()) << 80n) + (BigInt(random()) << 48n) + BigInt(random());
  const digits = value.toString(from).toUpperCase();
  const fraction = random() % (digits.length + 4);
  const padded = digits.padStart(fraction + 1, '0');
  const sign = sample % 2 ? '-' : '';
  const text = sign + (fraction ? padded.slice(0, -fraction) + '.' + padded.slice(-fraction) : padded);
  const parsed = NumericValue.parse(text, from);
  for (const target of [2, 8, 10, 16]) for (const places of [16, 32, 64, 128]) {
    equal(parsed.format(target, places), reference(sign ? -value : value, BigInt(from) ** BigInt(fraction), target, places));
  }
}
const session = new BaseConversionSession();
session.mode = 'numeric';
for (const key of ['0', '.', '1']) session.key(key);
equal(session.numeric.display(10).text, '0.1');
session.changeRadix(2);
equal(session.numeric.display(2).approximate, true);
for (let i = 0; i < 12; i++) {
  for (const radix of [16, 8, 2, 10]) session.changeRadix(radix);
  equal(session.numeric.display(10), { text: '0.1', approximate: false });
}
session.changeRadix(2);
rejects(() => session.key('⌫'));
equal(session.numeric.sourceText, '0.1');
session.key('±');
equal(session.numeric.display(10).text, '-0.1');
session.numeric.changePlaces(128);
equal(session.numeric.display(2).text.length, 131);
session.key('=');
const restored = restoreRecord(JSON.stringify(historyRecordOf(session)));
equal(restored.numeric.display(10).text, '-0.1');
equal(restored.numeric.radix, 2);
equal(restored.numeric.places, 128);
restored.numeric.editSource();
equal(restored.numeric.radix, 10);
equal(restored.numeric.text, '-0.1');
restored.key('⌫'); restored.key('2');
equal(restored.numeric.display(10).text, '-0.2');
const snap = restored.copy();
restored.key('AC');
equal(snap.numeric.display(10).text, '-0.2');
equal(restored.numeric.display(10).text, '0');
restored.mode = 'integer'; restored.key('7');
restored.mode = 'float'; restored.key('5');
restored.mode = 'numeric'; restored.key('9');
equal(restored.expression, '7'); equal(restored.floatText, '5'); equal(restored.numeric.text, '9');
restored.numeric.replaceInput('1..2');
equal(restored.numeric.previewValid, false);
equal(restored.numeric.display(10).text, '9');
rejects(() => restored.changeRadix(16));
equal(restored.numeric.radix, 10);
rejects(() => restored.confirm());
restored.numeric.replaceInput('0.5'); restored.confirm(); restored.changeRadix(2);
restored.key('⌫');
equal(restored.numeric.text, '0.');
equal(restored.numeric.display(10).text, '0');
restored.key('1'); restored.key('='); restored.key('0');
equal(restored.numeric.text, '0');
restored.key('.'); restored.key('.'); restored.key('1');
equal(restored.numeric.text, '0.1');
equal(restored.inputEnabled('F'), false);
equal(restored.inputEnabled('+'), false);
restored.changeRadix(16);
equal(restored.inputEnabled('F'), true);
const settings = restoreSettings(settingsOf(restored));
equal(settings.mode, 'numeric'); equal(settings.numeric.radix, 16);
equal(settings.numeric.display(10).text, '0');
// 固定旧版样例确保升级不会丢弃已存的整数和 IEEE 历史。
const legacy = { kind: 'programmer', version: 1, settings: {
  mode: 'integer', radix: 16, width: 8, signed: true, floatWidth: 32, floatRadix: 10
}, bits: 'FF', expression: 'FF', flags: { cf: -1, of: -1, zf: 0, sf: 1 }, carry: 0,
floatBits: '3F800000', floatText: '1' };
equal(restoreRecord(JSON.stringify(legacy)).word.format(10, true), '-1');
legacy.settings.mode = 'float';
equal(restoreRecord(JSON.stringify(legacy)).floatBits.toString(16), '3F800000');
equal(restoreSettings(legacy.settings).numeric.places, 32);
const record = recordOf(session);
for (const field of ['numericSourceText', 'numericSourceRadix']) {
  const invalid = { ...record }; delete invalid[field]; rejects(() => restoreRecord(JSON.stringify(invalid)));
}
rejects(() => restoreRecord(JSON.stringify({ ...record, numericSourceText: '≈ 0.1…' })));
rejects(() => restoreSettings({ ...settingsOf(session), numericRadix: 3 }));
rejects(() => restoreSettings({ ...settingsOf(session), numericPlaces: 4096 }));
console.log(`Numeric conversion and session: ${checks} assertions passed.`);
