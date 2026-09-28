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
import { decodeFloat } from './Ieee754';

/** 跨启动偏好仅保存配置，不包含计算草稿、结果或进位输入。 */
export interface BaseConversionSettings {
  mode: string;
  radix: number;
  width: number;
  signed: boolean;
  floatWidth: number;
  floatRadix: number;
}

/**
 * 历史 extra_params 的版本 1 契约；整数与浮点位模式均用 HEX 文本避免 JSON 数值丢精度。
 * kind=programmer 与 version=1 是已存历史的兼容标识，不随内部类型名称变化。
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
}

/** 仅在进程内保留页面往返状态；应用重启后由偏好重建空会话。 */
export class BaseConversionMemory {
  static session: BaseConversionSession | undefined = undefined;
}

export function settingsOf(session: BaseConversionSession): BaseConversionSettings {
  return { mode: session.mode, radix: session.radix, width: session.width, signed: session.signed,
    floatWidth: session.floatWidth, floatRadix: session.floatRadix };
}

// 反序列化后仍需校验枚举与类型，避免持久化损坏进入位宽和进制运算。
export function restoreSettings(settings: BaseConversionSettings): BaseConversionSession {
  if (!settings || !['integer', 'float'].includes(settings.mode) || ![2, 8, 10, 16].includes(settings.radix) ||
    ![8, 16, 32, 64].includes(settings.width) || typeof settings.signed !== 'boolean' ||
    ![16, 32, 64].includes(settings.floatWidth) || ![2, 10, 16].includes(settings.floatRadix)) {
    throw new Error('程序员配置无效');
  }
  const session = new BaseConversionSession();
  session.mode = settings.mode;
  session.width = settings.width;
  session.radix = settings.radix;
  session.signed = settings.signed;
  session.word = new Word(undefined, session.width);
  session.floatWidth = settings.floatWidth;
  session.floatRadix = settings.floatRadix;
  return session;
}

/** 可用于调试状态，保留当前草稿；写历史应使用 historyRecordOf 清理非活动模式草稿。 */
export function recordOf(session: BaseConversionSession): BaseConversionRecord {
  return { kind: 'programmer', version: 1, settings: settingsOf(session),
    bits: session.word.format(16), expression: session.expression, flags: session.flags, carry: session.carry,
    floatBits: session.floatBits.toString(16), floatText: session.floatText };
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
  if (!record || record.kind !== 'programmer' || record.version !== 1 ||
    typeof record.expression !== 'string' || record.expression.length > 1024 ||
    typeof record.floatText !== 'string' || record.floatText.length > 768 ||
    typeof record.bits !== 'string' || !/^[0-9A-F]{1,16}$/.test(record.bits) ||
    typeof record.floatBits !== 'string' || !/^[0-9A-F]{1,16}$/.test(record.floatBits) ||
    ![0, 1].includes(record.carry) || !record.flags ||
    ![record.flags.cf, record.flags.of, record.flags.zf, record.flags.sf].every((flag: number) => [-1, 0, 1].includes(flag))) {
    throw new Error('历史记录格式不受支持');
  }
  const session = restoreSettings(record.settings);
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
