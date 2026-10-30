/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ImmersiveSegmentedControl.ets
 * @description 带滑动胶囊高亮和双路径表面的受控选项栏
 * @author StartYi
 * @date 2026/10/30 19:20
 */

import { HapticUtils } from '../../utils/HapticUtils';
import { ImmersiveToolbarRowModifier } from './ImmersiveVisualModifiers';

export interface ImmersiveSegmentOption {
  label: ResourceStr;
  semanticId: string;
  // 正权重同时决定按钮和高亮的宽度，避免字体宽度影响选中底色对齐。
  weight: number;
}

@Component
struct SegmentButton {
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @Prop label: ResourceStr = '';
  @Prop selected: boolean = false;
  @Prop buttonHeight: number = 30;
  semanticId: string = '';
  onActivate: () => void = () => {};

  private labelText(): string {
    return typeof this.label === 'string' ? this.label : getContext(this).resourceManager.getStringSync(this.label.id);
  }

  build() {
    Button(this.labelText())
      .width('100%')
      .height(this.buttonHeight)
      .padding({ left: 4, right: 4 })
      .id(this.semanticId)
      .accessibilityText(this.labelText() + (this.selected ? '，已选中' : ''))
      .fontSize(13)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selected ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
        this.onActivate();
      })
  }
}

/**
 * 选中状态由调用方持有；只对装饰层做动画，不延迟业务回调或保存第二份选中状态。
 * 此组件不接管布局：启用光感时须位于标题栏或横向底部 TabBar，并由父容器预留阴影空间。
 */
@Component
export struct ImmersiveSegmentedControl {
  @Prop selectedIndex: number = 0;
  @Prop options: ImmersiveSegmentOption[] = [];
  @Prop controlHeight: number = 38;
  @Prop slideDuration: number = 220;
  @Prop globalEnabled: boolean = true;
  onSelect: (index: number) => void = () => {};

  private totalWeight(): number {
    return this.options.reduce((total: number, option: ImmersiveSegmentOption): number => total + option.weight, 0);
  }

  private highlightWidth(): string {
    const total = this.totalWeight();
    // 空选项或暂时失效的选中索引不绘制高亮，避免异步更新选项时越界。
    if (total <= 0 || this.selectedIndex < 0 || this.selectedIndex >= this.options.length) return '0%';
    return `${this.options[this.selectedIndex].weight / total * 100}%`;
  }

  private highlightOffset(): string {
    const total = this.totalWeight();
    if (total <= 0 || this.selectedIndex < 0 || this.selectedIndex >= this.options.length) return '0%';
    let precedingWeight = 0;
    for (let index = 0; index < this.selectedIndex; index++) precedingWeight += this.options[index].weight;
    return `${precedingWeight / total * 100}%`;
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width(this.highlightWidth())
          .height('100%')
          .borderRadius((this.controlHeight - 8) / 2)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .position({ x: this.highlightOffset(), y: 0 })
          .animation({ duration: this.slideDuration, curve: Curve.EaseInOut })
          .hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('no')
        Row() {
          ForEach(this.options, (option: ImmersiveSegmentOption, index: number) => {
            SegmentButton({
              label: option.label,
              selected: this.selectedIndex === index,
              buttonHeight: this.controlHeight - 8,
              semanticId: option.semanticId,
              onActivate: () => this.onSelect(index)
            }).layoutWeight(option.weight)
          }, (option: ImmersiveSegmentOption) => option.semanticId)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height(this.controlHeight)
    .padding(4)
    .borderRadius(this.controlHeight / 2)
    .attributeModifier(new ImmersiveToolbarRowModifier(this.globalEnabled))
  }
}
