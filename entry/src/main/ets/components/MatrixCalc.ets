/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file MatrixCalc.ets
 * @description 矩阵与线性代数核心业务面板组件
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/3 02:32
 */

/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file MatrixCalc.ets
 * @description 矩阵与线性代数核心业务面板组件
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';

// 6行5列的矩阵专属统一键盘数组
const matrixButtons: Array<string> = [
  'M⁻¹', 'Mᵀ', 'det', 'rref', 'eig',
  'Dim', '↑', 'a/b', 'AC', '⌫',
  '←', '↓', '→', '(', ')',
  '7', '8', '9', '÷', '(-)',
  '4', '5', '6', '×', '−',
  '1', '2', '3', '+', '='
];

@Component
struct MatrixKeyItem {
  btn: string = '';
  onKeyPress: (btn: string) => void = () => {};

  build() {
    Button() {
      Text(this.btn)
        .fontFamily(getFontFamily(this.btn))
        .fontSize(getFontSize(this.btn))
        .fontWeight(FontWeight.Medium)
        .fontColor(getFontColor(this.btn))
    }
    .type(ButtonType.Normal)
    .borderRadius(16) // 严格照搬 BottomKeyItem 的圆角
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 }) // 严格照搬 BottomKeyItem 的内边距
    .backgroundColor(getBgColor(this.btn, false))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .stateStyles({
      pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(() => {
      this.onKeyPress(this.btn);
    })
  }
}

@Component
export struct MatrixCalc {
  // 严格照搬 ScientificCalc 的全局状态注入
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // 矩阵维度的局部状态 (留待下一步弹窗注入)
  @State matrixRows: number = 0;
  @State matrixCols: number = 0;

  private handleButtonClick(btn: string) {
    let action = getActionId(btn);
    // 触发马达震动反馈，完全复用科学计算器的震感链路
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    if (btn === 'Dim') {
      // TODO: 触发呼出维度选择弹窗逻辑
    } else {
      // TODO: 将按键动作通过 eventHub 分发给 FormulaScreen 和底部的矩阵网格
      // getContext(this).eventHub.emit('screen_handle_action', action, false);
    }
  }

  build() {
    Column() {
      // ================= 1. 大显示区与网格编辑区 (高度扩张至 %) =================
      Column() {
        // 上半部：公式展示区
        // 严格照搬，直接挂载万能屏幕，确保完美的顶部安全区避让与 LaTeX 渲染
        FormulaScreen({ moduleType: 'matrix' })
          .height('50%')
          .width('100%')

        // 下半部：动态矩阵网格编辑区 (目前为空状态占位)
        Column() {
          if (this.matrixRows === 0 || this.matrixCols === 0) {
            Text('点击键盘上的 \"Dim\" 按钮创建矩阵')
              .fontSize(15)
              .fontColor($r('sys.color.font_tertiary'))
          } else {
            // TODO: 渲染真实输入网格
            Text(`已创建 ${this.matrixRows} × ${this.matrixCols} 矩阵`)
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
          }
        }
        .height('50%')
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.background_primary'))
        .border({ width: { top: 0.5 }, color: $r('sys.color.comp_divider') })
      }
      .width('100%')
      .height('55%')

      // ================= 2. 矮键盘区域 (高度压缩至 55%) =================
      // 严格照搬 ScientificCalc：父级 Column 负责背景色与 navBarHeight 避让
      Column() {
        Grid() {
          ForEach(matrixButtons, (btn: string) => {
            GridItem() {
              MatrixKeyItem({
                btn: btn,
                onKeyPress: (b: string): void => { this.handleButtonClick(b); }
              })
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        // 严格照搬 ScientificCalc 的间距参数
        .rowsGap(8)
        .columnsGap(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('45%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .padding({ bottom: this.navBarHeight }) // 精确打在父级容器上
    }
    .width('100%')
    .height('100%')
  }
}