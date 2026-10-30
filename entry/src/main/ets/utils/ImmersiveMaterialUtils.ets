/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ImmersiveMaterialUtils.ets
 * @description 集中创建 API 26 沉浸光感材质，并为旧版本提供兼容降级
 * @author StartYi
 * @date 2026-09-18 13:55
 */

import deviceInfo from '@ohos.deviceInfo';
import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

import { KeyboardKeyRole } from '../components/common/keyboard/KeyboardKeyTypes';

let normalKeyboardMaterial: uiMaterial.Material | undefined = undefined;
let operatorKeyboardMaterial: uiMaterial.Material | undefined = undefined;
let dangerKeyboardMaterial: uiMaterial.Material | undefined = undefined;
let emphasisKeyboardMaterial: uiMaterial.Material | undefined = undefined;
let shiftKeyboardMaterial: uiMaterial.Material | undefined = undefined;
let activeShiftKeyboardMaterial: uiMaterial.Material | undefined = undefined;

/**
 * 检查当前设备是否支持沉浸光感材质，仅用于不直接引用新 API 的样式分支。
 *
 * @returns API 26.0.0 及以上返回 `true`
 */
export function isImmersiveMaterialAvailable(): boolean {
  return deviceInfo.apiAvailable('26.0.0');
}

/** 仅选择布局或传统样式；新 API 调用仍须在调用处使用直接正向版本保护。 */
export function isImmersiveMaterialEnabled(globalEnabled: boolean = true): boolean {
  return isImmersiveMaterialAvailable() && globalEnabled;
}

/** 全局关闭只影响生效状态，不改写用户保存的键盘偏好。 */
export function isKeyboardMaterialEnabled(keyboardEnabled: boolean, globalEnabled: boolean = true): boolean {
  return isImmersiveMaterialEnabled(globalEnabled) && keyboardEnabled;
}

/** HDS 自适应材质自 API 23 可用，沿用系统降级；关闭时显式使用 NONE。 */
export function createNavigationMaterial(globalEnabled: boolean = true): SystemMaterialParams {
  return {
    materialType: globalEnabled ? hdsMaterial.MaterialType.ADAPTIVE : hdsMaterial.MaterialType.NONE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}

/**
 * 创建用于 Sheet 的常规强度沉浸光感材质。
 *
 * 版本判断必须直接包围新 API 构造，以便 ArkTS 兼容性分析识别安全边界。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createSheetMaterial(globalEnabled: boolean = true): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    // undefined 会恢复系统默认材质，不能用于显式关闭光感。
    if (!globalEnabled) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR
    });
  }

  return undefined;
}

/**
 * 创建用于弹窗的高遮挡沉浸光感材质。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createDialogMaterial(globalEnabled: boolean = true): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (!globalEnabled) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK
    });
  }

  return undefined;
}

/**
 * 创建用于菜单的较厚沉浸光感材质。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createMenuMaterial(globalEnabled: boolean = true): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (!globalEnabled) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK
    });
  }

  return undefined;
}

/**
 * 创建用于搜索框的薄款沉浸光感材质。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createSearchMaterial(globalEnabled: boolean = true): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (!globalEnabled) return uiMaterial.Material.empty;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN
    });
  }

  return undefined;
}

/**
 * 创建用于 TopBar 按钮的超薄交互式沉浸光感材质。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createTopBarMaterial(globalEnabled: boolean = true): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (!globalEnabled) return uiMaterial.Material.empty;
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
 * 每类语义按键共用材质实例，避免为每个按键重复构造。
 *
 * @returns API 26 开启时返回材质，关闭时返回 `Material.empty`；低版本返回 `undefined`
 */
export function createKeyboardMaterial(
  role: KeyboardKeyRole,
  shiftActive: boolean = false,
  globalEnabled: boolean = true
): uiMaterial.Material | undefined {
  if (deviceInfo.apiAvailable('26.0.0')) {
    // 在缓存命中前处理关闭，避免已创建的材质绕过总开关。
    if (!globalEnabled) return uiMaterial.Material.empty;
    if (role === KeyboardKeyRole.FUNCTION || role === KeyboardKeyRole.OPERATOR) {
      if (!operatorKeyboardMaterial) {
        operatorKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: $r('app.color.keyboard_material_operator'),
          interactive: true,
          lightEffect: {}
        });
      }
      return operatorKeyboardMaterial;
    }

    if (role === KeyboardKeyRole.DANGER) {
      if (!dangerKeyboardMaterial) {
        dangerKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: $r('app.color.keyboard_material_danger'),
          interactive: true,
          lightEffect: {}
        });
      }
      return dangerKeyboardMaterial;
    }

    if (role === KeyboardKeyRole.EMPHASIS) {
      if (!emphasisKeyboardMaterial) {
        emphasisKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: $r('app.color.keyboard_material_emphasis'),
          interactive: true,
          lightEffect: {}
        });
      }
      return emphasisKeyboardMaterial;
    }

    if (role === KeyboardKeyRole.SHIFT && !shiftActive) {
      if (!shiftKeyboardMaterial) {
        shiftKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: $r('app.color.keyboard_material_shift'),
          interactive: true,
          lightEffect: {}
        });
      }
      return shiftKeyboardMaterial;
    }

    if (role === KeyboardKeyRole.SHIFT && shiftActive) {
      if (!activeShiftKeyboardMaterial) {
        activeShiftKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          materialColor: $r('app.color.keyboard_material_shift_active'),
          interactive: true,
          lightEffect: {}
        });
      }
      return activeShiftKeyboardMaterial;
    }

    if (!normalKeyboardMaterial) {
      normalKeyboardMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        interactive: true,
        lightEffect: {}
      });
    }

    return normalKeyboardMaterial;
  }

  return undefined;
}
