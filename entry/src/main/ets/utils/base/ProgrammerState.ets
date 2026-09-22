/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ProgrammerState.ets
 * @description 程序员偏好和历史扩展槽的版本化数据契约
 */
import { ProgrammerSession } from './ProgrammerSession';
import { Word, Flags } from './ProgrammerEngine';
import { Natural } from './Natural';
import { decodeFloat } from './Ieee754';

export interface ProgrammerSettings {
  mode: string;
  radix: number;
  width: number;
  signed: boolean;
  floatWidth: number;
  floatRadix: number;
}

export interface ProgrammerRecord {
  kind: string;
  version: number;
  settings: ProgrammerSettings;
  bits: string;
  expression: string;
  flags: Flags;
  carry: number;
  floatBits: string;
  floatText: string;
}

export class ProgrammerMemory {
  static session: ProgrammerSession | undefined = undefined;
}

export function settingsOf(session: ProgrammerSession): ProgrammerSettings {
  return { mode: session.mode, radix: session.radix, width: session.width, signed: session.signed,
    floatWidth: session.floatWidth, floatRadix: session.floatRadix };
}

export function restoreSettings(settings: ProgrammerSettings): ProgrammerSession {
  if (!settings || !['integer', 'float'].includes(settings.mode) || ![2, 8, 10, 16].includes(settings.radix) ||
    ![8, 16, 32, 64].includes(settings.width) || typeof settings.signed !== 'boolean' ||
    ![16, 32, 64].includes(settings.floatWidth) || ![2, 10, 16].includes(settings.floatRadix)) {
    throw new Error('程序员配置无效');
  }
  const session = new ProgrammerSession();
  session.mode = settings.mode;
  session.width = settings.width;
  session.radix = settings.radix;
  session.signed = settings.signed;
  session.word = new Word(undefined, session.width);
  session.floatWidth = settings.floatWidth;
  session.floatRadix = settings.floatRadix;
  return session;
}

export function recordOf(session: ProgrammerSession): ProgrammerRecord {
  return { kind: 'programmer', version: 1, settings: settingsOf(session),
    bits: session.word.format(16), expression: session.expression, flags: session.flags, carry: session.carry,
    floatBits: session.floatBits.toString(16), floatText: session.floatText };
}

export function historyRecordOf(session: ProgrammerSession): ProgrammerRecord {
  const record = recordOf(session);
  // 历史只保存已确认模式的输入，另一模式以最近有效位模式恢复。
  if (session.mode !== 'integer') record.expression = session.word.format(session.radix, session.signed, false);
  if (session.mode !== 'float') record.floatText = session.floatRadix === 10 ?
    decodeFloat(session.floatBits, session.floatWidth).decimal : session.floatBits.toString(session.floatRadix);
  return record;
}

export function restoreRecord(json: string): ProgrammerSession {
  const record = JSON.parse(json) as ProgrammerRecord;
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
