import { webview } from '@kit.ArkWeb';
import { CalculationTestBridge } from '../utils/CalculationTestBridge';
import { common } from '@kit.AbilityKit';
import { PreferenceManager } from '../../../main/ets/utils/PreferenceManager';

@Entry
@Component
struct CalculationTestPage {
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    PreferenceManager.init(getContext(this) as common.UIAbilityContext);
    CalculationTestBridge.attach(this.controller);
  }

  build() {
    Column() {
      Web({
        src: $rawfile('calculator.html'),
        controller: this.controller
      })
        .javaScriptAccess(true)
        .onPageEnd(() => {
          CalculationTestBridge.markReady();
        })
    }
    .width('100%')
    .height('100%')
  }
}
