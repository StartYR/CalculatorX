import deviceInfo from '@ohos.deviceInfo';
import { PreferenceConfigs } from '../../../utils/CalculatorConfigs';

/**
 * 在完整传统组件树与完整沉浸组件树之间统一选择。
 */
@Component
export struct KeyboardRenderSwitch {
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;

  @BuilderParam legacyContent: () => void;
  @BuilderParam immersiveContent: () => void;

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.keyImmersiveMaterial) {
        this.immersiveContent()
      } else {
        this.legacyContent()
      }
    } else {
      this.legacyContent()
    }
  }
}
