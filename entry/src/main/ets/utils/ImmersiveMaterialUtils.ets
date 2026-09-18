/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ImmersiveMaterialUtils.ets
 * @description 封装 API 26 沉浸光感与材质能力检测及系统 Material 对象创建
 * @author StartYi
 * @date 2026/9/18 13:55
 */

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

export function createTopBarMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      colorInvert: true,
      interactive: true,
      lightEffect: {}
    });
  }

  return undefined;
}
