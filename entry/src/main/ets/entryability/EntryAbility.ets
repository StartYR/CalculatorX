/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file EntryAbility.ets
 * @description 应用主入口 Ability，负责初始化全局首选项配置并注入 AppStorage
* * @author StartYi
 * @date 2026
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PreferenceConfigs } from '../utils/CalculatorConfigs'; // 引入配置常数

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    PreferenceManager.init(this.context);
    PreferenceManager.loadAllToAppStorage();
    const modeIndex = AppStorage.get<number>(PreferenceConfigs.KEY_COLOR_MODE) ?? 2;
    let pendingFormula = '';
    if (this.context.applicationInfo.debug) {
      const saved = PreferenceManager.get(PreferenceConfigs.KEY_CLI_PENDING_FORMULA, '');
      if (typeof saved === 'string' && saved.startsWith('1:')) {
        pendingFormula = saved;
        PreferenceManager.remove(PreferenceConfigs.KEY_CLI_PENDING_FORMULA);
      }
    }
    AppStorage.setOrCreate(PreferenceConfigs.KEY_CLI_PENDING_FORMULA, pendingFormula);

    // 4. 颜色模式应用
    let targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (modeIndex === 0) {
      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (modeIndex === 1) {
      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    this.context.getApplicationContext().setColorMode(targetColorMode);

    // 5. 加载主渲染视图
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }

      windowStage.getMainWindow().then(mainWindow => {
        mainWindow.setWindowLayoutFullScreen(true);
        let navigationAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        let systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        AppStorage.setOrCreate('navBarHeight', px2vp(navigationAvoidArea.bottomRect.height));
        AppStorage.setOrCreate('statusBarHeight', px2vp(systemAvoidArea.topRect.height));

        mainWindow.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            AppStorage.setOrCreate('navBarHeight', px2vp(data.area.bottomRect.height));
          } else if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            AppStorage.setOrCreate('statusBarHeight', px2vp(data.area.topRect.height));
          }
        });
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full screen. Cause: %{public}s', JSON.stringify(err));
      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    PreferenceManager.init(this.context);
    void PreferenceManager.commit();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    PreferenceManager.savePending();
  }
}
