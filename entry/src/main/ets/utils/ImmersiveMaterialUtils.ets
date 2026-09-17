import deviceInfo from '@ohos.deviceInfo';
import { uiMaterial } from '@kit.ArkUI';

export function createSheetMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR
    });
  }

  return undefined;
}
