/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ImmersiveVisualModifiers.ets
 * @description 按用途统一沉浸光感表面、显式关闭及低版本传统外观
 * @author StartYi
 * @date 2026/10/30 19:10
 */

import deviceInfo from '@ohos.deviceInfo';

import { createTopBarMaterial, createSearchMaterial, createMenuMaterial } from '../../utils/ImmersiveMaterialUtils';

/** 只管理表面；调用方须将普通 Row 放在系统支持的标题栏或底部 TabBar 区域。 */
export class ImmersiveToolbarRowModifier implements AttributeModifier<RowAttribute> {
  constructor(private globalEnabled: boolean = true) {}

  applyNormalAttribute(instance: RowAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.globalEnabled) {
        // 切回光感时撤销传统描边和阴影，避免双重表面叠加。
        instance.backgroundColor(Color.Transparent);
        instance.borderWidth(0);
        instance.shadow({ radius: 0 });
        instance.systemMaterial(createTopBarMaterial());
        return;
      }
      instance.systemMaterial(createTopBarMaterial(false));
    }
    instance.backgroundColor($r('sys.color.comp_background_secondary'));
    instance.border({ width: 0.5, color: $r('sys.color.comp_divider') });
    instance.shadow(ShadowStyle.OUTER_DEFAULT_SM);
  }
}

/** 标题栏按钮保留独立的传统毛玻璃配色，不与胶囊行的回退外观混用。 */
export class ImmersiveToolbarButtonModifier implements AttributeModifier<ButtonAttribute> {
  constructor(private globalEnabled: boolean = true) {}

  applyNormalAttribute(instance: ButtonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.globalEnabled) {
        instance.buttonStyle(ButtonStyleMode.TEXTUAL);
        instance.backgroundColor(Color.Transparent);
        instance.backgroundBlurStyle(BlurStyle.NONE);
        instance.borderWidth(0);
        instance.shadow({ radius: 0 });
        instance.systemMaterial(createTopBarMaterial());
        return;
      }
      instance.systemMaterial(createTopBarMaterial(false));
    }
    instance.buttonStyle(ButtonStyleMode.EMPHASIZED);
    instance.backgroundColor('#54ffffff');
    instance.backgroundBlurStyle(BlurStyle.COMPONENT_THICK);
    instance.border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 });
    instance.shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 });
  }
}

export class ImmersiveSearchModifier implements AttributeModifier<SearchAttribute> {
  constructor(private globalEnabled: boolean = true) {}

  applyNormalAttribute(instance: SearchAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.globalEnabled) {
        instance.borderWidth(0);
        instance.backgroundColor(Color.Transparent);
        instance.backgroundBlurStyle(BlurStyle.NONE);
        instance.systemMaterial(createSearchMaterial());
        return;
      }
      instance.systemMaterial(createSearchMaterial(false));
    }
    instance.borderWidth(0.1);
    instance.borderColor($r('sys.color.comp_divider'));
    instance.backgroundColor(Color.Transparent);
    instance.backgroundBlurStyle(BlurStyle.Thin);
  }
}

/** Select 本体沿用系统样式，此适配器仅控制展开菜单的材质。 */
export class ImmersiveSelectMenuModifier implements AttributeModifier<SelectAttribute> {
  constructor(private globalEnabled: boolean = true) {}

  applyNormalAttribute(instance: SelectAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.menuSystemMaterial(createMenuMaterial(this.globalEnabled));
    }
  }
}
