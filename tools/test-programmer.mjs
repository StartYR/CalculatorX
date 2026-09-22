// 在宿主机执行纯 ArkTS 核心；BigInt 和 DataView 仅作为独立测试参照。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

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
const { Word, Flags, operate, encodingRows, decodeEncoding } = await import('../entry/src/main/ets/utils/base/ProgrammerEngine.ets');
const { Natural } = await import('../entry/src/main/ets/utils/base/Natural.ets');
const { ProgrammerExpression } = await import('../entry/src/main/ets/utils/base/ProgrammerExpression.ets');
const { encodeFloat, decodeFloat } = await import('../entry/src/main/ets/utils/base/Ieee754.ets');
let checks = 0;
function equal(actual, expected) { assert.equal(actual, expected); checks++; }
function word(value, width = 8) { return Word.parse(String(value), 10, width); }
let seed = 0x173025;
function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed; }
for (const width of [8, 16, 32, 64]) {
  const modulus = 1n << BigInt(width), mask = modulus - 1n, sign = modulus >> 1n;
  const signed = n => n >= sign ? n - modulus : n;
  for (let sample = 0; sample < 180; sample++) {
    const a = (BigInt(random()) << 32n | BigInt(random())) & mask;
    const b = (BigInt(random()) << 32n | BigInt(random())) & mask;
    const left = word(a, width), right = word(b, width);
    for (const radix of [2, 8, 10, 16]) equal(Word.parse(left.format(radix), radix, width).format(10), a.toString());
    for (const carry of [0, 1]) {
      for (const action of ['+', '-', 'ADC', 'SBB', '*', 'AND', 'OR', 'XOR']) {
        const extra = action === 'ADC' || action === 'SBB' ? BigInt(carry) : 0n;
        const add = action === '+' || action === 'ADC';
        const sub = action === '-' || action === 'SBB';
        const wide = add ? a + b + extra : sub ? a - b - extra : action === '*' ? a * b :
          action === 'AND' ? a & b : action === 'OR' ? a | b : a ^ b;
        const result = operate(action, left, right, true, carry);
        equal(result.word.format(10), (wide & mask).toString());
        if (add || sub) {
          equal(result.flags.cf, add ? Number(wide >= modulus) : Number(wide < 0n));
          const signedWide = add ? signed(a) + signed(b) + extra : signed(a) - signed(b) - extra;
          equal(result.flags.of, Number(signedWide < -sign || signedWide >= sign));
        }
      }
    }
    if (b) for (const isSigned of [true, false]) for (const action of ['/', 'MOD']) {
      const x = isSigned ? signed(a) : a, y = isSigned ? signed(b) : b;
      const result = operate(action, left, right, isSigned).word;
      equal(result.format(10), ((action === '/' ? x / y : x % y) & mask).toString());
    }
    for (const count of [0, 1, width - 1, width, width + 1]) {
      for (const action of ['SHL', 'SHR', 'SAR', 'ROL', 'ROR', 'RCL', 'RCR']) {
        for (const carry of [0, 1]) {
          const through = action === 'RCL' || action === 'RCR';
          const ringWidth = BigInt(width + (through ? 1 : 0));
          const ringMask = (1n << ringWidth) - 1n;
          const n = BigInt(count) % ringWidth;
          const ring = through ? (a << 1n) | BigInt(carry) : a;
          const leftward = action === 'ROL' || action === 'RCL';
          const rotated = leftward ? ((ring << n) | (ring >> (ringWidth - n))) & ringMask :
            ((ring >> n) | (ring << (ringWidth - n))) & ringMask;
          const expected = action === 'SHL' ? a << BigInt(count) : action === 'SHR' ? a >> BigInt(count) :
            action === 'SAR' ? signed(a) >> BigInt(count) : through ? rotated >> 1n : rotated;
          equal(operate(action, left, word(count, width), false, carry).word.format(10), (expected & mask).toString());
        }
      }
    }
  }
}
equal(word('18446744073709551615', 64).format(16), 'FFFFFFFFFFFFFFFF');
equal(word('9007199254740993', 64).format(10), '9007199254740993');
equal(word(255).resize(16, true).format(10, true), '-1');
equal(word(255).resize(16, false).format(10), '255');
equal(encodingRows(word(128), true)[2].bits, '同宽不可表示');
equal(decodeEncoding(word(128), '原码'), '-0');
equal(decodeEncoding(word(255), '反码'), '-0');
for (const [text, expected] of [['2 + 3 * 4', '14'], ['( 2 + 3 ) * 4', '20'], ['-7 / 3', '-2'],
  ['-7 MOD 3', '-1'], ['1 OR 2 AND 4', '1'], ['NOT 0', '-1'], ['1 RCL 1', '3']]) {
  equal(new ProgrammerExpression(10, 8, true, 1).evaluate(text).word.format(10, true), expected);
}
for (const text of ['1 / 0', '1 +', '(1', '1)', '1 . 2', '256', '1 SHL -1']) {
  assert.throws(() => new ProgrammerExpression(10, 8, true).evaluate(text)); checks++;
}
const known = [
  [16, '0', '0000'], [16, '-0', '8000'], [16, '1', '3C00'], [16, '-2.5', 'C100'],
  [16, '65504', '7BFF'], [16, '65520', '7C00'], [16, '0.00006103515625', '0400'],
  [16, '0.000000059604644775390625', '0001'], [16, '1.00048828125', '3C00'],
  [16, '1.000488281250000000000001', '3C01'], [16, '1.00146484375', '3C02'],
  [32, '1', '3F800000'], [32, '-2.5', 'C0200000'], [64, '1', '3FF0000000000000'],
  [64, '-0', '8000000000000000'], [64, '4.9406564584124654e-324', '0000000000000001']
];
for (const [width, input, hex] of known) equal(encodeFloat(input, width).toString(16).padStart(width / 4, '0'), hex);
for (const width of [16, 32, 64]) {
  equal(decodeFloat(encodeFloat('-0', width), width).category, '负零');
  equal(decodeFloat(encodeFloat('NaN', width), width).category, 'quiet NaN');
  equal(decodeFloat(encodeFloat('Infinity', width), width).decimal, 'Infinity');
  equal(decodeFloat(encodeFloat('1e999999', width), width).category, '无穷');
}
// 16 位全部位模式（NaN 保留位模式的解码路径独立测试）。
for (let bits = 0; bits <= 65535; bits++) {
  const raw = Natural.small(bits), decoded = decodeFloat(raw, 16);
  if (!decoded.category.includes('NaN')) equal(encodeFloat(decoded.decimal, 16).toString(16), raw.toString(16));
}
const buffer = new ArrayBuffer(8), view = new DataView(buffer);
for (const width of [32, 64]) for (let i = 0; i < 300; i++) {
  const input = (random() / 1000) + 'e' + ((random() % (width === 32 ? 80 : 620)) - (width === 32 ? 45 : 320));
  if (width === 32) view.setFloat32(0, Number(input)); else view.setFloat64(0, Number(input));
  const expected = width === 32 ? BigInt(view.getUint32(0)) : view.getBigUint64(0);
  equal(encodeFloat(input, width).toString(16), expected.toString(16).toUpperCase());
}
console.log(`Programmer core: ${checks} assertions passed.`);
