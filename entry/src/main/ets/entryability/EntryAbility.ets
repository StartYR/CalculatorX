import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // 获取主窗口并开启全屏沉浸式布局
      windowStage.getMainWindow().then(mainWindow => {
        // 1. 开启全屏布局（内容可以延伸到导航条下方）
        mainWindow.setWindowLayoutFullScreen(true);

        // 2. 获取导航条高度并存入全局变量，供页面组件使用
        let avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        let navBarHeight = px2vp(avoidArea.bottomRect.height); // px 转 vp
        AppStorage.setOrCreate('navBarHeight', navBarHeight);

        // 3. 监听导航条变化（比如设备旋转等场景）
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
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}