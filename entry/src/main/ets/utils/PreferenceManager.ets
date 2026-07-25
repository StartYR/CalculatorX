/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file PreferenceManager.ets
 * @description 请在此处输入文件描述...
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 21:13
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { PreferenceConfigs } from './CalculatorConfigs';
import Logger from './Logger'

export class PreferenceManager {
  // 保存全局的 Preferences 实例，避免每次调用都去 getPreferencesSync
  private static instance: preferences.Preferences | null = null;

  /**
   * 1. 全局初始化 (建议在 EntryAbility.ets 的 onCreate 或 onWindowStageCreate 中调用一次)
   */
  public static init(context: common.UIAbilityContext): void {
    if (!PreferenceManager.instance) {
      PreferenceManager.instance = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
      Logger.info(`[PreferenceManager] 初始化成功`);
    }
  }

  /**
   * 2. 写入配置并自动落盘 (UI 层只需调这个)
   */
  public static set(key: string, value: preferences.ValueType): void {
    if (!PreferenceManager.instance) {
      Logger.error(`[PreferenceManager] 未初始化！`);
      return;
    }
    try {
      PreferenceManager.instance.putSync(key, value);
      PreferenceManager.instance.flush(); // 自动落盘
    } catch (err) {
      Logger.error(`[PreferenceManager] 保存配置失败: ${key}, 错误: ${err}`);
    }
  }

  /**
   * 3. 读取配置 (如果有需要的话)
   */
  public static get(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    if (!PreferenceManager.instance) return defaultValue;
    return PreferenceManager.instance.getSync(key, defaultValue);
  }

  /**
   * 4. 启动时调用：将磁盘中的数据全部同步到内存 (AppStorage)
   */
  public static loadAllToAppStorage(): void {
    if (!PreferenceManager.instance) {
      Logger.error(`[PreferenceManager] 无法同步到 AppStorage，未初始化！`);
      return;
    }
    AppStorage.setOrCreate('isRad', PreferenceManager.get(PreferenceConfigs.KEY_IS_RAD, false));
    AppStorage.setOrCreate('hapticFeedback', PreferenceManager.get(PreferenceConfigs.KEY_HAPTIC_FEEDBACK, true));
    AppStorage.setOrCreate('vibrationCurve', PreferenceManager.get(PreferenceConfigs.KEY_VIBRATION_CURVE, 0));
    AppStorage.setOrCreate('decimalPrecision', PreferenceManager.get(PreferenceConfigs.KEY_DECIMAL_PRECISION, 6));
    AppStorage.setOrCreate('colorModeIndex', PreferenceManager.get(PreferenceConfigs.KEY_COLOR_MODE, 2));
    AppStorage.setOrCreate('answerOutputMode', PreferenceManager.get(PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, 0));
    AppStorage.setOrCreate(PreferenceConfigs.KEY_COMBINATION_SELECT, PreferenceManager.get(PreferenceConfigs.KEY_COMBINATION_SELECT, 1));
    AppStorage.setOrCreate(PreferenceConfigs.KEY_PERMUTATION_SELECT, PreferenceManager.get(PreferenceConfigs.KEY_PERMUTATION_SELECT, 1));

    Logger.info(`[PreferenceManager] 所有配置已成功加载到 AppStorage`);
  }
}