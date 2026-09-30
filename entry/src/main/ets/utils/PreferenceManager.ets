/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file PreferenceManager.ets
 * @description 首选项缓存读写、串行提交与启动配置注入
 * * @author StartYi
 * @date 2026/7/24 21:13
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { PreferenceConfigs } from './CalculatorConfigs';
import Logger from './Logger';
import { PREFERENCE_SETTINGS, normalizePreference } from './PreferenceDefaults';
import type { PreferenceSetting } from './PreferenceDefaults';

export interface PreferenceReadResult {
  ok: boolean;
  exists: boolean;
  value: preferences.ValueType;
}

export interface PreferenceCommitResult {
  ok: boolean;
  pending: boolean;
}

export interface PreferenceEntry {
  key: string;
  value: preferences.ValueType;
}

interface PendingPreference {
  value: preferences.ValueType;
  deleted: boolean;
}

export class PreferenceManager {
  // 保存全局的 Preferences 实例，避免每次调用都去 getPreferencesSync
  private static instance: preferences.Preferences | null = null;
  private static pending: Map<string, PendingPreference> = new Map();
  private static committing: Promise<PreferenceCommitResult> | undefined = undefined;
  private static saveTimer: number = -1;
  private static saveCallbacks: Set<() => void> = new Set();

  public static registerSave(callback: () => void): void {
    PreferenceManager.saveCallbacks.add(callback);
  }

  public static unregisterSave(callback: () => void): void {
    PreferenceManager.saveCallbacks.delete(callback);
  }

  /** 后台先收集模块防抖中的最新快照，再提交首选项缓存。 */
  public static savePending(): void {
    PreferenceManager.saveCallbacks.forEach((callback: () => void): void => {
      try { callback(); } catch (_) { Logger.error('[PreferenceManager] 收集待保存状态失败'); }
    });
    void PreferenceManager.commit();
  }

  /**
   * 1. 全局初始化 (建议在 EntryAbility.ets 的 onCreate 或 onWindowStageCreate 中调用一次)
   */
  public static init(context: common.UIAbilityContext): boolean {
    try {
      if (!PreferenceManager.instance) {
        PreferenceManager.instance = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
      }
      if (PreferenceManager.pending.size > 0) PreferenceManager.scheduleCommit();
      return true;
    } catch (_) {
      Logger.error('[PreferenceManager] 初始化失败，保留待保存内容');
      return false;
    }
  }

  /**
   * 2. 写入配置并自动落盘 (UI 层只需调这个)
   */
  public static set(key: string, value: preferences.ValueType): void {
    PreferenceManager.stage(key, value);
    PreferenceManager.scheduleCommit();
  }

  /** 同轮多键只安排一次提交；不提供事务，关联业务字段应保存为一份快照。 */
  public static setMany(entries: PreferenceEntry[]): void {
    entries.forEach((entry: PreferenceEntry): void => PreferenceManager.stage(entry.key, entry.value));
    PreferenceManager.scheduleCommit();
  }

  /** 先更新可读取的缓存，提交时机交给调用方；未初始化或写缓存失败也保留待保存值。 */
  public static stage(key: string, value: preferences.ValueType): void {
    const current = PreferenceManager.read(key, value);
    if (current.ok && current.exists && current.value === value) return;
    PreferenceManager.pending.set(key, { value: value, deleted: false });
    try {
      PreferenceManager.instance?.putSync(key, value);
    } catch (_) {
      Logger.error(`[PreferenceManager] 写缓存失败，等待重试: ${key}`);
    }
  }

  public static remove(key: string): void {
    PreferenceManager.pending.set(key, { value: '', deleted: true });
    PreferenceManager.scheduleCommit();
  }

  private static scheduleCommit(): void {
    if (PreferenceManager.saveTimer !== -1) return;
    // 仅合并同一轮事件中的写入；输入防抖由各模块安排。
    PreferenceManager.saveTimer = setTimeout((): void => {
      PreferenceManager.saveTimer = -1;
      void PreferenceManager.commit();
    }, 0);
  }

  /** 等待已接受的修改落盘；失败保留最新内容，下一次操作或前台恢复可再次提交。 */
  public static commit(): Promise<PreferenceCommitResult> {
    if (PreferenceManager.saveTimer !== -1) {
      clearTimeout(PreferenceManager.saveTimer);
      PreferenceManager.saveTimer = -1;
    }
    if (PreferenceManager.committing) return PreferenceManager.committing;
    const task = PreferenceManager.flushPending();
    PreferenceManager.committing = task;
    // 清理回调先注册，等待者继续操作时不会复用已经结束的提交。
    void task.then((): void => { PreferenceManager.committing = undefined; });
    return task;
  }

  private static async flushPending(): Promise<PreferenceCommitResult> {
    const instance = PreferenceManager.instance;
    if (!instance) {
      Logger.error('[PreferenceManager] 尚未初始化，待保存内容继续保留');
      return { ok: false, pending: PreferenceManager.pending.size > 0 };
    }
    try {
      while (PreferenceManager.pending.size > 0) {
        const batch = new Map(PreferenceManager.pending);
        batch.forEach((entry: PendingPreference, key: string): void => {
          if (entry.deleted) instance.deleteSync(key);
          else instance.putSync(key, entry.value);
        });
        await instance.flush();
        // 提交期间同一个键可能又被编辑；只移除本轮确实保存的那一版。
        batch.forEach((entry: PendingPreference, key: string): void => {
          if (PreferenceManager.pending.get(key) === entry) PreferenceManager.pending.delete(key);
        });
      }
      return { ok: true, pending: false };
    } catch (_) {
      Logger.error('[PreferenceManager] 落盘失败，保留最新内容等待重试');
      return { ok: false, pending: PreferenceManager.pending.size > 0 };
    }
  }

  /**
   * 3. 读取配置 (如果有需要的话)
   */
  public static get(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return PreferenceManager.read(key, defaultValue).value;
  }

  /** 缺失键与读取失败不同；迁移代码不能在读取失败后将默认数据回写磁盘。 */
  public static read(key: string, defaultValue: preferences.ValueType): PreferenceReadResult {
    const pending = PreferenceManager.pending.get(key);
    if (pending) return { ok: true, exists: !pending.deleted, value: pending.deleted ? defaultValue : pending.value };
    const instance = PreferenceManager.instance;
    if (!instance) return { ok: false, exists: false, value: defaultValue };
    try {
      return { ok: true, exists: instance.hasSync(key), value: instance.getSync(key, defaultValue) };
    } catch (_) {
      Logger.error(`[PreferenceManager] 读取失败: ${key}`);
      return { ok: false, exists: false, value: defaultValue };
    }
  }

  /**
   * 4. 启动时调用：将磁盘中的数据全部同步到内存 (AppStorage)
   */
  public static loadAllToAppStorage(): void {
    if (!PreferenceManager.instance) {
      Logger.error(`[PreferenceManager] 无法同步到 AppStorage，未初始化！`);
    }
    PREFERENCE_SETTINGS.forEach((setting: PreferenceSetting): void => {
      const value = PreferenceManager.get(setting.key, setting.defaultValue);
      AppStorage.setOrCreate(setting.key, normalizePreference(setting, value as Object));
    });
  }
}
