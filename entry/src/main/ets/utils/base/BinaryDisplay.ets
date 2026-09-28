/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BinaryDisplay.ets
 * @description 二进制显示的固定 32 位分行，不改变数值文本
 * @author StartYi
 * @date 2026/09/29 22:00
 */

/** 符号、小数点和近似标记不占位数；末行不足 32 位时不补零，避免改变数值。 */
export function binaryRows(text: string): string[] {
  const rows: string[] = [];
  let row = '';
  let digits = 0;
  for (let index = 0; index < text.length; index++) {
    const character = text.charAt(index);
    const isDigit = character === '0' || character === '1';
    if (isDigit && digits === 32) {
      rows.push(row);
      row = '';
      digits = 0;
    }
    row += character;
    if (isDigit) digits++;
  }
  if (row.length > 0 || rows.length === 0) rows.push(row);
  return rows;
}
