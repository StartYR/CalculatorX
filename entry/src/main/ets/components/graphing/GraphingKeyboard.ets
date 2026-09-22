/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file GraphingKeyboard.ets
 * @description 图形计算器专属键盘组件及按键配置
 * @author StartYi
 * @date 2026/8/3 19:46
 */
import { HapticUtils } from '../../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor } from '../../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../../utils/CalculatorConfigs';
import {
  icon_sqrt, icon_sqrt3, icon_sqrtx, icon_power2, icon_power3,
  icon_power, icon_fraction, icon_abs, icon_backspace
} from '../../utils/CalculatorConfigs';
import { KeyGestureWrapper } from '../common/KeyGestureWrapper';
import { FunctionType } from './GraphingTypes'; // 引入函数类型进行动态感知
import { KeyboardKeyRole } from '../common/keyboard/KeyboardKeyTypes';
import { resolveKeyboardKeyRole } from '../common/keyboard/KeyboardVisualPolicy';
import { KeyboardKeySurface } from '../common/keyboard/KeyboardKeySurface';
import deviceInfo from '@ohos.deviceInfo';

// ==================== 按键布局配置 ====================

// Shift 层：移除了固定的 t 和 θ，将最后两个坑位彻底留空，维持矩阵稳定
export const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  icon_sqrt3, icon_abs, icon_power3, '', '', 'lg',
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '', ''
];

// 核心新增：基于当前激活的函数类型，动态生成主键盘矩阵
export function getDynamicTopButtons(type: FunctionType | undefined): Array<string | Resource> {
  const base: Array<string | Resource> = [
    '⇧Shift', '(', '⇦', '⇨', ')', '⌨⇩',
    icon_sqrt, icon_sqrtx, icon_power2, icon_power,'log', 'ln',
    'sin', 'cos', 'tan', icon_fraction
  ];

  switch(type) {
    case FunctionType.PARAMETRIC:
      return [...base, 't', '']; // 独占 t
    case FunctionType.POLAR:
      return [...base, 'θ', '']; // 独占 θ
    case FunctionType.IMPLICIT:
      return [...base, 'x', 'y']; // 双未知数拉满
    case FunctionType.POINT:
      return [...base, '', '']; // 纯净点坐标，清空未知数
    case FunctionType.NORMAL:
    default:
      return [...base, 'x', '']; // 默认普通函数独占 x
  }
}

export const bottomButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'π', 'e', '确定'
];

function getLocalFontColor(btn: string | Resource): ResourceColor {
  if (btn === 'π' || btn === 'e') return getFontColor('0');
  if (btn === '确定') return getFontColor('=');
  return getFontColor(btn);
}

function getLocalFontSize(btn: string | Resource): number {
  if (btn === 'π' || btn === 'e') return getFontSize('0');
  if (btn === 't' || btn === 'θ' || btn === 'x' || btn === 'y') return getFontSize('0');
  return getFontSize(btn);
}

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

function getGraphingKeyboardKeyRole(btn: string | Resource): KeyboardKeyRole {
  return resolveKeyboardKeyRole(btn, ['确定'], ['π', 'e']);
}

@Component
export struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  immersive: boolean = false;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  private KeyContentBuilder() {
    if (typeof this.btn === 'string') {
      Text(this.btn)
        .fontFamily(getFontFamily(this.btn))
        .fontSize(getLocalFontSize(this.btn))
        .fontWeight(FontWeight.Medium)
        .fontColor(getLocalFontColor(this.btn))
    } else {
      Image(this.btn)
        .width(36)
        .height(36)
        .fillColor($r('sys.color.font_secondary'))
        .draggable(false)
    }
  }

  build() {
    Column() {
      // 顶部 Shift 标识渲染逻辑
      if (this.btnIndex >= 6) {
        Row() {
          if (typeof topShiftButtons[this.btnIndex] === 'string' && topShiftButtons[this.btnIndex] !== '') {
            Text(topShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(topShiftButtons[this.btnIndex]))
              .fontSize(17)
              .fontColor('#ffac8100')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else if (typeof topShiftButtons[this.btnIndex] !== 'string') {
            Image(topShiftButtons[this.btnIndex] as Resource)
              .width(30)
              .height(30)
              .fillColor('#ffac8100')
              .objectFit(ImageFit.Contain)
          }
        }
        .width('100%')
        .height(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 1 })
      } else {
        Row().width('100%').height(6)
      }

      // 主按键渲染逻辑
      Row() {
        if (this.btn === '') {
          // 遇到空字符串时，渲染一个透明、禁用的占位符
          Button()
            .type(ButtonType.Normal)
            .borderRadius(12)
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .stateEffect(false)
        } else {
          KeyGestureWrapper({
            actionId: getLocalActionId(this.btn),
            targetBtn: this.btn,
            shiftBtn: topShiftButtons[this.btnIndex] || '',
            moduleType: 'graphing',
            isShiftMode: $isShift,
            onKeyPress: this.onKeyPress,
            onMenuSelect: this.onMenuSelect
          }) {
            KeyboardKeySurface({
              immersive: this.immersive,
              role: getGraphingKeyboardKeyRole(this.btn),
              shiftActive: this.isShift,
              keyBorderRadius: 12,
              horizontalPadding: 2
            }) {
              this.KeyContentBuilder()
            }
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct BottomKeyItem {
  btn: string | Resource = '';
  immersive: boolean = false;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  customRadius: number = 16;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  private KeyContentBuilder() {
    if (typeof this.btn === 'string') {
      Text(this.btn)
        .fontFamily(getFontFamily(this.btn))
        .fontSize(getLocalFontSize(this.btn))
        .fontWeight(FontWeight.Medium)
        .fontColor(getLocalFontColor(this.btn))
    } else {
      Image(this.btn)
        .width(48)
        .height(40)
        .fillColor(getFontColor(this.btn))
        .draggable(false)
    }
  }

  build() {
    KeyGestureWrapper({
      actionId: getLocalActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'graphing',
      isShiftMode: $isShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      KeyboardKeySurface({
        immersive: this.immersive,
        role: getGraphingKeyboardKeyRole(this.btn),
        keyBorderRadius: this.customRadius,
        horizontalPadding: 4
      }) {
        this.KeyContentBuilder()
      }
    }
  }
}

// ==================== 定义域专属纯净数字键盘 ====================
export const domainButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace,
  '4', '5', '6', 'AC',
  '1', '2', '3', '−', // 使用你已经处理好映射的优雅减号
  '0', '.', '确定'
];

@Component
export struct DomainKeyboard {
  // 占位状态，用于满足 BottomKeyItem 对 @Link isShift 的要求
  @State private isShift: boolean = false;
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;

  // 暴露给外部的回调，专门处理点击事件
  onKeyPress: (btn: string | Resource) => void = () => {};

  // --- 获取全局状态 ---
  @StorageProp('navBarHeight') navBarHeight: number = 0; // 用于底部避让
  @StorageProp('vibrationCurve') vibrationCurve: number = 0; // 震动反馈参数
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true; // 震动开关

  @Builder
  private DomainKeyGridBuilder(immersive: boolean) {
    Grid() {
      ForEach(domainButtons, (btn: string | Resource) => {
        GridItem() {
          BottomKeyItem({
            btn: btn,
            immersive: immersive,
            isShift: $isShift,
            customRadius: 36,
            onKeyPress: (b: string | Resource) => {
              let action = getActionId(b);
              HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
              this.onKeyPress(b);
            }
          })
        }
        .columnStart(btn === '0' ? 0 : undefined)
        .columnEnd(btn === '0' ? 1 : undefined)
      }, (btn: string | Resource) => typeof btn === 'string' ? btn : 'icon_backspace')
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr 1fr')
    .columnsGap(8)
    .rowsGap(8)
    .width('100%')
    .height(260)
    .padding({ left: 10, right: 10, top: 12, bottom: 8 })
  }

  @Builder
  private LegacyDomainKeyboardBuilder() {
    Column() {
      this.DomainKeyGridBuilder(false)
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .borderWidth(0.7)
    .borderColor($r('sys.color.comp_divider'))
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 16 })
  }

  @Builder
  private ImmersiveDomainKeyboardBarBuilder() {
    Column() {
      this.DomainKeyGridBuilder(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .borderWidth(0.7)
    .borderColor($r('sys.color.comp_divider'))
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 16 })
  }

  @Builder
  private ImmersiveDomainKeyboardLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column()
          .width('100%')
          .height('100%')
      }
      .tabBar(this.ImmersiveDomainKeyboardBarBuilder)
    }
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barHeight('100%')
    .width('100%')
    .height(260 + this.navBarHeight - 16)
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.keyImmersiveMaterial) {
        this.ImmersiveDomainKeyboardLayout()
      } else {
        this.LegacyDomainKeyboardBuilder()
      }
    } else {
      this.LegacyDomainKeyboardBuilder()
    }
  }
}
