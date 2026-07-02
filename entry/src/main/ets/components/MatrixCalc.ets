/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file MatrixCalc.ets
 * @description 矩阵与线性代数核心业务面板组件
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/3 02:32
 */

import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';

// 6行5列的矩阵专属统一键盘数组
const matrixButtons: Array<string> = [
  'M⁻¹', 'Mᵀ', 'det', 'rref', 'eig',
  'Dim', '↑', 'a/b', 'AC', '⌫',
  '←', '↓', '→', '(', ')',
  '7', '8', '9', '×', '÷',
  '4', '5', '6', '+', '−',
  '1', '2', '3', '0', '='
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
    .borderRadius(14)
    .width('100%')
    .height('100%')
    // 优先使用现有的公共样式方法，矩阵特有按键可在配置中加兜底
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
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // 矩阵局部的多维状态，留待第二步填充具体数据结构
  @State matrixRows: number = 0;
  @State matrixCols: number = 0;
  @State focusedCellRow: number = -1;
  @State focusedCellCol: number = -1;

  private handleButtonClick(btn: string) {
    let action = getActionId(btn);
    // 触发马达震动反馈
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    // TODO: 下一步实现按键的具体分发逻辑（如输入数字、移动光标、呼出Dim弹窗、触发C++矩阵计算等）
    if (btn === 'Dim') {
      // 触发呼出维度选择弹窗逻辑
    }
  }

  build() {
    Column() {
      // ================= 显示区=================
      Column() {
        // 上半部分：LaTeX 表达式显示区
        Column() {
          // TODO: 挂载 FormulaScreen 或自定义的矩阵公式显示组件
          Text('矩阵表达式显示区 (TODO)')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        // 下半部分：动态矩阵网格编辑区
        Column() {
          if (this.matrixRows === 0 || this.matrixCols === 0) {
            // 空状态占位提示
            Column() {
              Text('点击键盘上的 \"Dim\" 按钮创建矩阵')
                .fontSize(15)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ bottom: 8 })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height('100%')
          } else {
            // TODO: 根据选定维度动态渲染真实可输入的数字网格
            Text(`已创建 ${this.matrixRows} × ${this.matrixCols} 矩阵`)
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
          }
        }
        .width('100%')
        .layoutWeight(2)
        .backgroundColor($r('sys.color.background_primary'))
        .border({ width: { top: 0.5 }, color: $r('sys.color.comp_divider') })
      }
      .height('50%')
      .width('100%')
      .backgroundColor($r('sys.color.background_secondary'))

      // ================= 键盘区域 =================
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
      .rowsGap(10)
      .columnsGap(8)
      .padding({ left: 10, right: 10, top: 8, bottom: 0 })
      .width('100%')
      .height('50%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .padding({ bottom: this.navBarHeight }) // 避让系统底部导航条
    }
    .width('100%')
    .height('100%')
  }
}