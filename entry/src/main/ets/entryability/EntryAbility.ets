import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
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

    // 1. 获取首选项实例
    let prefs = preferences.getPreferencesSync(this.context, { name: PreferenceConfigs.STORE_NAME });

    // 2. 读取所有配置项，若不存在则赋予默认值
    let modeIndex = prefs.getSync(PreferenceConfigs.KEY_COLOR_MODE, 2) as number;               // 颜色模式 (0: 浅色, 1: 深色, 2: 跟随系统)
    let vibCurve = prefs.getSync(PreferenceConfigs.KEY_VIBRATION_CURVE, 0) as number;           // 振动风格 (0: 自定义, 1: 清脆, 2: 轻柔)
    let isRad = prefs.getSync(PreferenceConfigs.KEY_IS_RAD, false) as boolean;                  // 角度/弧度制 (false: 角度 Deg, true: 弧度 Rad)
    // let vibIntensity = prefs.getSync(PreferenceConfigs.KEY_VIBRATION_INTENSITY, 50) as number;  // 振动强度 (自定义模式下的具体强度值)
    let decPrecision = prefs.getSync(PreferenceConfigs.KEY_DECIMAL_PRECISION, 16) as number;    // 小数精度 (16位通常代表自动，或最大支持的位数)
    let ansOutMode = prefs.getSync(PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, 0) as number;      // 答案输出模式 (0: 自动模式, 1: 小数模式)
    let combSelect = prefs.getSync(PreferenceConfigs.KEY_COMBINATION_SELECT, 1) as number;      // 组合计数排列样式 (当前为UI占位)
    let permSelect = prefs.getSync(PreferenceConfigs.KEY_PERMUTATION_SELECT, 1) as number;      // 排列计数样式 (当前为UI占位)
    let haptic = prefs.getSync(PreferenceConfigs.KEY_HAPTIC_FEEDBACK, true) as boolean;         // 触控按键全局震动开关 (true: 开启, false: 关闭)

    // 3. 将数据同步到内存 AppStorage 中，供全局 UI 消费
    AppStorage.setOrCreate(PreferenceConfigs.KEY_COLOR_MODE, modeIndex);                        // 注入全局颜色模式
    AppStorage.setOrCreate(PreferenceConfigs.KEY_VIBRATION_CURVE, vibCurve);                    // 注入全局振动风格
    AppStorage.setOrCreate(PreferenceConfigs.KEY_IS_RAD, isRad);                                // 注入全局角度/弧度制
    // AppStorage.setOrCreate(PreferenceConfigs.KEY_VIBRATION_INTENSITY, vibIntensity);            // 注入全局振动强度
    AppStorage.setOrCreate(PreferenceConfigs.KEY_DECIMAL_PRECISION, decPrecision);              // 注入全局小数精度
    AppStorage.setOrCreate(PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, ansOutMode);               // 注入全局答案输出模式
    AppStorage.setOrCreate(PreferenceConfigs.KEY_COMBINATION_SELECT, combSelect);               // 注入全局组合样式
    AppStorage.setOrCreate(PreferenceConfigs.KEY_PERMUTATION_SELECT, permSelect);               // 注入全局排列样式
    AppStorage.setOrCreate(PreferenceConfigs.KEY_HAPTIC_FEEDBACK, haptic);                      // 注入全局震动总开关

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