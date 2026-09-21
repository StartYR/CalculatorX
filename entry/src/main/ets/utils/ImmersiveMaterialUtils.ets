/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ImmersiveMaterialUtils.ets
 * @description 集中创建 API 26 沉浸光感材质，并为旧版本提供兼容降级
 * @author StartYi
 * @date 2026-09-18 13:55
 */

import deviceInfo from '@ohos.deviceInfo';
import { uiMaterial } from '@kit.ArkUI';

let keyboardMaterial: uiMaterial.Material | undefined = undefined;

/**
 * 检查当前设备是否支持沉浸光感材质，仅用于不直接引用新 API 的样式分支。
 *
 * @returns API 26.0.0 及以上返回 `true`
 */
export function isImmersiveMaterialAvailable(): boolean {
  return deviceInfo.apiAvailable('26.0.0');
}

/**
 * 创建用于 Sheet 的常规强度沉浸光感材质。
 *
 * 版本判断必须直接包围新 API 构造，以便 ArkTS 兼容性分析识别安全边界。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
export function createSheetMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR
    });
  }

  return undefined;
}

/**
 * 创建用于弹窗的高遮挡沉浸光感材质。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
export function createDialogMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK
    });
  }

  return undefined;
}

/**
 * 创建用于菜单的较厚沉浸光感材质。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
export function createMenuMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK
    });
  }

  return undefined;
}

/**
 * 创建用于搜索框的薄款沉浸光感材质。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
export function createSearchMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN
    });
  }

  return undefined;
}

/**
 * 创建用于 TopBar 按钮的超薄交互式沉浸光感材质。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
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

/**
 * 创建用于计算按键的超薄交互式沉浸光感材质。
 *
 * 相同参数的按键共用材质实例，避免为每个按键重复构造。
 *
 * @returns 支持时返回材质实例，否则返回 `undefined`
 */
export function createKeyboardMaterial(): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (!keyboardMaterial) {
      keyboardMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        interactive: true,
        lightEffect: {}
      });
    }

    return keyboardMaterial;
  }

  return undefined;
}
