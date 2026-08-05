/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file TopBar.ets
 * @description 顶部悬浮控制栏（搭载动态状态岛）
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

import Logger from '../utils/Logger'

// 定义模块名称映射
const MODULE_TITLES: Record<string, string> = {
  'scientific': '科学计算',
  'basic': '基础计算',
  'matrix': '矩阵与向量',
  'graphing': '函数图像',
  'equation': '方程求解',
  'statistics': '统计分析',
  'unit': '单位转换',
  'base': '进制转换',
  'exchange': '汇率'
};

@Component
export struct TopBar {
  @Prop isShift: boolean = false;
  @Prop isRad: boolean = false;
  @Prop currentModule: string = 'scientific';

  onMenuClick?: () => void;
  onHistoryClick?: () => void;
  onUndoClick?: () => void;
  onRedoClick?: () => void;

  build() {
    // 顶部悬浮控制栏
    Row() {
      // ================= 左侧组合：菜单 + 撤销 =================
      Row({ space: 8 }) {
        // 1. 设置菜单按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.slider_horizontal_2_1'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(44)
        .height(32)
        .backgroundColor('#54ffffff')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
        .onClick(() => { if (this.onMenuClick) this.onMenuClick(); })
        if (!(this.currentModule === 'graphing'|| this.currentModule === 'basic')) {
          // 2. 撤销按钮
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(36)
          .height(32)
          .backgroundColor('#54ffffff')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
          .shadow({
            radius: 32,
            color: '#25000000',
            offsetX: 3,
            offsetY: 6
          })
          .onClick(() => {
            if (this.onUndoClick) this.onUndoClick();
          })
        }
      }

      // ================= 中间：动态状态岛 =================
      Row() {
        if (this.isShift) {
          // 1. Shift 激活状态 (当前模块必须支持 Shift 才可显示)
          Text('⇧ SHIFT')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
            .transition({ type: TransitionType.All, translate: { y: 15 }, opacity: 0 })
        } else {
          // 2. 常规状态：动态提取模块名称
          Row({ space: 6 }) {
            // 通过字典派发对应的中文标题
            Text(MODULE_TITLES[this.currentModule] || 'CalcX')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))

            // 角度制徽章
            if (['scientific'].includes(this.currentModule)) {
              Text(this.isRad ? 'RAD' : 'DEG')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_secondary'))
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(4)
            }
          }
          .transition({ type: TransitionType.All, translate: { y: -15 }, opacity: 0 })
        }
      }
      .layoutWeight(1) // 占满中间剩余空间
      .height(32)
      .justifyContent(FlexAlign.Center) // 居中
      .clip(true)                       // 动画裁剪边界
      .animation({ duration: 300, curve: Curve.Friction }) // 状态切换动画

      // ================= 右侧组合：重做 + 历史 =================

      Row({ space: 8 }) {
        // 3. 重做按钮
        if (!(this.currentModule === 'graphing'|| this.currentModule === 'basic')) {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrowshape_turn_up_right'))
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(36)
          .height(32)
          .backgroundColor('#54ffffff')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
          .shadow({
            radius: 32,
            color: '#25000000',
            offsetX: 3,
            offsetY: 6
          })
          .onClick(() => {
            if (this.onRedoClick) this.onRedoClick();
          })
        }
        // 4. 动态切换：函数图像模块显示“编辑”，其他模块显示“历史”
        if (this.currentModule === 'graphing') {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil')) // 系统的编辑图标
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(44)
          .height(32)
          .backgroundColor('#54ffffff')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
          .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
          .onClick(() => {
            // 抛出全局事件，通知 GraphingCalc 唤起面板
            Logger.info('[TopBar] 打开编辑面板');
            getContext(this).eventHub.emit('open_graphing_edit_sheet');
            Logger.info('[TopBar] 编辑面板打开结束');
          })
        } else {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(44)
          .height(32)
          .backgroundColor('#54ffffff')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
          .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
          .onClick(() => { if (this.onHistoryClick) this.onHistoryClick(); })
        }
      }
    }
    .width('100%')
    .padding({ top: 36, left: 12, right: 12 })
  }
}