import deviceInfo from '@ohos.deviceInfo';
import { uiMaterial } from '@kit.ArkUI';

export function isImmersiveMaterialAvailable(): boolean {
  return deviceInfo.apiAvailable('26.0.0');
}

export function createSheetMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR
    });
  }

  return undefined;
}

export function createDialogMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK
    });
  }

  return undefined;
}

export function createMenuMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK
    });
  }

  return undefined;
}
