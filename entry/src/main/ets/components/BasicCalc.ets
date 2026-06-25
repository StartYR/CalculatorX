/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file BasicCalc.ets
 * @description 基础计算器独立业务面板插件
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 02:20
 */

import { BasicKeyboard } from './BasicKeyboard';

@Component
export struct BasicCalc {
  // 隔离的状态：属于基础计算器自己的输入内容
  @State inputExpress: string = '';

  // 响应按键点击的核心回调
  private handleKeyPress(btn: string | Resource) {
    // TODO: 接下来在这里处理基础按键逻辑（如数字输入、加减乘除、AC清除、⌫退格等）
    console.info(`基础按键点击: ${typeof btn === 'string' ? btn : 'Icon'}`);
  }

  build() {
    Column() {
      // ================= 1. 屏幕显示区 =================
      Column() {
        // 暂时用 Text 替代，稍后注入 Webview 后台暗房
        Text(this.inputExpress || '0')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.End)
          .width('100%')
          .padding({ left: 24, right: 24 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)
      .width('100%')

      // ================= 2. 独立基础键盘区 =================
      BasicKeyboard({
        onKeyPress: (btn: string | Resource) => {
          this.handleKeyPress(btn);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}