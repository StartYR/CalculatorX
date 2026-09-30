/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file PreferenceDefaults.ets
 * @description 启动设置的唯一默认值与基本类型校验
 * @author StartYi
 * @date 2026/09/30 14:00
 */
import { PreferenceConfigs } from './CalculatorConfigs';

export interface PreferenceSetting {
  key: string;
  defaultValue: boolean | number | string;
  min?: number;
  max?: number;
  values?: string[];
}

export class PreferenceDefaults {
  static readonly IS_RAD: boolean = true;
  static readonly DECIMAL_PRECISION: number = 6;
}

// 有效存量值优先，异常键单独回退；默认值不会自动回写磁盘。
export const PREFERENCE_SETTINGS: PreferenceSetting[] = [
  { key: PreferenceConfigs.KEY_PRIVACY_VERSION, defaultValue: 0, min: 0, max: 99999999 },
  { key: PreferenceConfigs.KEY_IS_RAD, defaultValue: PreferenceDefaults.IS_RAD },
  { key: PreferenceConfigs.KEY_HAPTIC_FEEDBACK, defaultValue: true },
  { key: PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL, defaultValue: false },
  { key: PreferenceConfigs.KEY_VIBRATION_CURVE, defaultValue: 0, min: 0, max: 3 },
  { key: PreferenceConfigs.KEY_DECIMAL_PRECISION, defaultValue: PreferenceDefaults.DECIMAL_PRECISION, min: 0, max: 16 },
  { key: PreferenceConfigs.KEY_COLOR_MODE, defaultValue: 2, min: 0, max: 2 },
  { key: PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, defaultValue: 0, min: 0, max: 1 },
  { key: PreferenceConfigs.KEY_COMBINATION_SELECT, defaultValue: 1, min: 0, max: 4 },
  { key: PreferenceConfigs.KEY_PERMUTATION_SELECT, defaultValue: 1, min: 0, max: 4 },
  { key: PreferenceConfigs.KEY_STARTUP_PAGE, defaultValue: 0, min: 0, max: 9 },
  { key: PreferenceConfigs.KEY_LAST_USED_MODULE, defaultValue: 'scientific',
    values: ['scientific', 'basic', 'matrix', 'graphing', 'equation', 'statistics', 'unit', 'base', 'exchange'] },
  { key: PreferenceConfigs.KEY_GRAPHING_FUNCTIONS, defaultValue: '[]' }
];

export function normalizePreference(setting: PreferenceSetting, value: Object): boolean | number | string {
  if (typeof value !== typeof setting.defaultValue) return setting.defaultValue;
  if (typeof value === 'number') {
    if (!Number.isInteger(value) || (setting.min !== undefined && value < setting.min) ||
      (setting.max !== undefined && value > setting.max)) return setting.defaultValue;
    return value;
  }
  if (typeof value === 'string') {
    return setting.values && !setting.values.includes(value) ? setting.defaultValue : value;
  }
  return value as boolean;
}
