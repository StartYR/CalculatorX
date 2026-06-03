import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData'; // 官方首选项核心库

const DOMAIN = 0x0000;
const PREF_STORE_NAME = 'CalcX_Preferences'; // 官方建议统一定义 Store 名称

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 1. 【官方规范】获取首选项实例
    let options: preferences.Options = { name: PREF_STORE_NAME };
    let prefs = preferences.getPreferencesSync(this.context, options);

    // 2. 【官方规范】同步获取数据，如果磁盘没有，则返回默认值 2 (跟随系统)
    let currentModeIndex = prefs.getSync('colorModeIndex', 2) as number;

    // 3. 将真实数据注入 AppStorage，供 Settings.ets 双向绑定显示
    AppStorage.setOrCreate('colorModeIndex', currentModeIndex);

    // 4. 立即计算并应用全局颜色模式
    let targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (currentModeIndex === 0) {
      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (currentModeIndex === 1) {
      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    this.context.getApplicationContext().setColorMode(targetColorMode);

    // 5. 加载页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      windowStage.getMainWindow().then(mainWindow => {
        mainWindow.setWindowLayoutFullScreen(true);
        let avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        AppStorage.setOrCreate('navBarHeight', px2vp(avoidArea.bottomRect.height));

        mainWindow.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            AppStorage.setOrCreate('navBarHeight', px2vp(data.area.bottomRect.height));
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
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}