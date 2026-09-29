/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BaseConversionState.ets
 * @description 进制转换偏好和历史扩展槽的版本化数据契约
 * @author StartYi
 * @date 2026/09/23 01:00
 */
import { BaseConversionSession } from './BaseConversionSession';
import { Word, Flags } from './IntegerEngine';
import { Natural } from './Natural';
import { decodeFloat } from './IEEE754';
import { NUMERIC_RADICES, NUMERIC_PLACES } from './NumericValue';

/** 跨启动偏好仅保存配置，不包含计算草稿、结果或进位输入。 */
export interface BaseConversionSettings {
  mode: string;
  numericRadix?: number;
  numericPlaces?: number;
  radix: number;
  width: number;
  signed: boolean;
  floatWidth: number;
  floatRadix: number;
}

/**
 * 历史 extra_params 用 HEX 保存位模式；版本 2 增加数值模式的精确输入来源。
 * 继续读取 kind=programmer 的版本 1 记录；缺失数值字段时恢复默认零值。
 */
export interface BaseConversionRecord {
  kind: string;
  version: number;
  settings: BaseConversionSettings;
  bits: string;
  expression: string;
  flags: Flags;
  carry: number;
  floatBits: string;
  floatText: string;
  numericSourceText?: string;
  numericSourceRadix?: number;
}

/** 仅在进程内保留页面往返状态；应用重启后由偏好重建空会话。 */
export class BaseConversionMemory {
  static session: BaseConversionSession | undefined = undefined;
}

export function settingsOf(session: BaseConversionSession): BaseConversionSettings {
  return { mode: session.mode, radix: session.radix, width: session.width, signed: session.signed,
    floatWidth: session.floatWidth, floatRadix: session.floatRadix,
    numericRadix: session.numeric.radix, numericPlaces: session.numeric.places };
}

// 反序列化后仍需校验枚举与类型，避免持久化损坏进入位宽和进制运算。
export function restoreSettings(settings: BaseConversionSettings): BaseConversionSession {
  if (!settings || !['numeric', 'integer', 'float'].includes(settings.mode) || ![2, 8, 10, 16].includes(settings.radix) ||
    ![8, 16, 32, 64].includes(settings.width) || typeof settings.signed !== 'boolean' ||
    ![16, 32, 64].includes(settings.floatWidth) || ![2, 10, 16].includes(settings.floatRadix)) {
    throw new Error('程序员配置无效');
  }
  if ((settings.numericRadix !== undefined && !NUMERIC_RADICES.includes(settings.numericRadix)) ||
    (settings.numericPlaces !== undefined && !NUMERIC_PLACES.includes(settings.numericPlaces))) {
    throw new Error('数值转换配置无效');
  }
  const session = new BaseConversionSession();
  session.mode = settings.mode;
  session.width = settings.width;
  session.radix = settings.radix;
  session.signed = settings.signed;
  session.word = new Word(undefined, session.width);
  session.floatWidth = settings.floatWidth;
  session.floatRadix = settings.floatRadix;
  session.numeric.changePlaces(settings.numericPlaces === undefined ? 32 : settings.numericPlaces);
  session.numeric.changeRadix(settings.numericRadix === undefined ? 10 : settings.numericRadix);
  return session;
}

/** 可用于调试状态，保留当前草稿；写历史应使用 historyRecordOf 清理非活动模式草稿。 */
export function recordOf(session: BaseConversionSession): BaseConversionRecord {
  return { kind: 'programmer', version: 2, settings: settingsOf(session),
    bits: session.word.format(16), expression: session.expression, flags: session.flags, carry: session.carry,
    floatBits: session.floatBits.toString(16), floatText: session.floatText,
    numericSourceText: session.numeric.sourceText, numericSourceRadix: session.numeric.sourceRadix };
}

export function historyRecordOf(session: BaseConversionSession): BaseConversionRecord {
  const record = recordOf(session);
  // 历史只保存已确认模式的输入，另一模式以最近有效位模式恢复。
  if (session.mode !== 'integer') record.expression = session.word.format(session.radix, session.signed, false);
  if (session.mode !== 'float') record.floatText = session.floatRadix === 10 ?
    decodeFloat(session.floatBits, session.floatWidth).decimal : session.floatBits.toString(session.floatRadix);
  return record;
}

// 历史位模式为结果权威来源，不重新计算表达式，以保留精确值、标志和 NaN payload。
export function restoreRecord(json: string): BaseConversionSession {
  const record = JSON.parse(json) as BaseConversionRecord;
  if (!record || record.kind !== 'programmer' || ![1, 2].includes(record.version) ||
    typeof record.expression !== 'string' || record.expression.length > 1024 ||
    typeof record.floatText !== 'string' || record.floatText.length > 768 ||
    typeof record.bits !== 'string' || !/^[0-9A-F]{1,16}$/.test(record.bits) ||
    typeof record.floatBits !== 'string' || !/^[0-9A-F]{1,16}$/.test(record.floatBits) ||
    ![0, 1].includes(record.carry) || !record.flags ||
    ![record.flags.cf, record.flags.of, record.flags.zf, record.flags.sf].every((flag: number) => [-1, 0, 1].includes(flag))) {
    throw new Error('历史记录格式不受支持');
  }
  if (record.version === 1 && record.settings && record.settings.mode === 'numeric') {
    throw new Error('旧版历史不包含数值转换');
  }
  if (record.version === 2 && (typeof record.numericSourceText !== 'string' ||
    typeof record.numericSourceRadix !== 'number' || !NUMERIC_RADICES.includes(record.numericSourceRadix))) {
    throw new Error('数值历史缺少精确输入来源');
  }
  const session = restoreSettings(record.settings);
  if (record.version === 2) {
    // 从原输入恢复精确有理数，再切到当时显示进制，绝不解析带省略的小数显示。
    session.numeric.changeRadix(record.numericSourceRadix!);
    session.numeric.replaceInput(record.numericSourceText!);
    session.numeric.confirm();
    session.numeric.changeRadix(record.settings.numericRadix === undefined ? 10 : record.settings.numericRadix);
  }
  session.word = Word.parse(record.bits, 16, session.width);
  session.floatBits = Natural.parse(record.floatBits, 16);
  if (session.floatBits.bits.length > session.floatWidth) throw new Error('历史位模式超出字长');
  session.expression = record.expression;
  session.floatText = record.floatText;
  const flags = new Flags();
  flags.cf = record.flags.cf; flags.of = record.flags.of; flags.zf = record.flags.zf; flags.sf = record.flags.sf;
  session.flags = flags;
  session.previousFlags = flags;
  session.carry = record.carry;
  return session;
}
