/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEditSheet.ets
 * @description 图形计算器编辑面板组件：管理函数列表、键盘坞以及编辑交互
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

import { FormulaScreen } from '../FormulaScreen';
import { GRAPHING_COLORS, getActionId } from '../../utils/CalculatorConfigs';
import { GraphFunctionItem } from './GraphingTypes';
import { TopKeyItem, BottomKeyItem, topButtons, bottomButtons } from './GraphingKeyboard';

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

@Component
export struct GraphingEditSheet {
  @Link functionList: GraphFunctionItem[];
  @Link activeIndex: number;
  @Link isKeyboardShow: boolean;
  @Link isShift: boolean;
  @Link isDarkModeUI: boolean;

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';

  // 接收从外层传入的回调，保持原有逻辑调用形式不变
  saveFunctions: () => void = () => {};
  handleButtonClick: (btn: string | Resource) => void = () => {};
  handleButtonLongPress: (actionCode: string) => void = () => {};

  @Builder
  DeleteAction(index: number) {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        // 垃圾桶图标
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(24)
          .fontColor([Color.White])
      }
      .width(40)
      .height(40)
      .backgroundColor('#FF3B30')
      .shadow({ radius: 8, color: '#33FF3B30', offsetY: 4 }) // 增加悬浮阴影
      .onClick(() => {
        if (this.functionList.length > 1) {
          // 引入 UniversalHistoryList 同款摩擦力弹簧动画
          animateTo({ duration: 350, curve: Curve.Friction }, () => {
            this.functionList.splice(index, 1);
            if (this.activeIndex >= this.functionList.length) {
              this.activeIndex = this.functionList.length - 1;
            }
          });
          this.saveFunctions(); // 数据落盘
        }
      })
    }
    .height('100%')
    .padding({ left: 16, right: 24 }) // 给删除按钮留出贴边的视觉缓冲
    .justifyContent(FlexAlign.Center)
  }

  build() {
    // ==================== 终极重构：Stack 层叠布局 + Translate 动画 ====================
    Stack({ alignContent: Alignment.Bottom }) {

      // ---------- 第 1 层：全屏列表与顶部标题 ----------
      Column() {
        // 顶部指示区
        Row() {
          Text("编辑函数图像")
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .padding({ left: 24, right: 0, top: 24, bottom: 16 })

        // 展示列表
        List({ space: 8 }) {
          ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
            ListItem() {
              Row() {
                // 左侧颜色标识
                Circle({ width: 14, height: 14 })
                  .fill(item.isVisible ? item.color : $r('sys.color.comp_divider'))
                  .margin({ right: 14 })
                  .onClick(() => {
                    let newItem: GraphFunctionItem = {
                      id: item.id,
                      latex: item.latex,
                      base64: item.base64,
                      color: item.color,
                      isVisible: !item.isVisible,
                      ast: item.ast
                    };
                    this.functionList[index] = newItem;
                    this.saveFunctions();
                  })

                // 右侧内容区
                Column() {
                  if (item.base64) {
                    Row() {
                      Image(item.base64)
                        .height(36)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined) // 深色模式下的颜色反转
                    }
                    .width('100%')
                    .justifyContent(FlexAlign.Start)
                  } else {
                    Text((this.activeIndex === index && this.isKeyboardShow) ? "正在编辑..." : "点击此处编辑表达式...")
                      .fontColor($r('sys.color.font_secondary'))
                      .width('100%')
                      .textAlign(TextAlign.Start)
                  }
                }
                .layoutWeight(1)
                .padding({ top: 12, bottom: 12 }) // 增加上下的呼吸感
              }
              .width('100%')
              .padding({ left: 16, right: 16 }) // 内部卡片的内边距
              // 选中态与未选中态的背景色切换
              .backgroundColor((this.activeIndex === index && this.isKeyboardShow) ? $r('sys.color.comp_background_tertiary') : $r('sys.color.background_primary'))
              .borderRadius(16) // 与历史记录一致的 16 圆角
            }
            .padding({ left: 16, right: 16 })
            .swipeAction({
              end: { builder: () => { this.DeleteAction(index) } },
              edgeEffect: SwipeEdgeEffect.Spring // 引入弹性回弹效果
            })
            .onClick(() => {
              if (this.activeIndex === index && this.isKeyboardShow) return;

              if (this.isKeyboardShow) {
                getContext(this).eventHub.emit('request_graphing_data', this.activeIndex);
              }

              this.activeIndex = index;
              this.isKeyboardShow = true;
              getContext(this).eventHub.emit('wake_web_engines');
              getContext(this).eventHub.emit('load_latex_to_editor', item.latex);
            })
          }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.base64.slice(-20)}_${item.isVisible}`)

          // 底部添加按钮
          ListItem() {
            // 1. 状态降级：动态切换文案
            Button(this.functionList.length >= 5 ? "已达数量上限 (5/5)" : "+ 添加新的函数", { type: ButtonType.Normal })
              .backgroundColor(Color.Transparent)
              // 2. 状态降级：动态切换颜色 (达上限时置灰)
              .fontColor(this.functionList.length >= 5 ? $r('sys.color.font_tertiary') : $r('sys.color.brand'))
              .borderRadius(50)
              .width('100%')
              .height(48)
              .onClick(() => {
                // 3. 如果达到 5 条，拦截点击事件
                if (this.functionList.length >= 5) return;

                if (this.isKeyboardShow) {
                  getContext(this).eventHub.emit('request_graphing_data', this.activeIndex);
                }

                // 4. 智能颜色回收池：遍历当前已存在的颜色，找出第一个没被占用的颜色
                let usedColors = this.functionList.map(item => item.color);
                let nextColor = GRAPHING_COLORS.find(color => !usedColors.includes(color)) || GRAPHING_COLORS[0];

                this.functionList.push({
                  id: Date.now().toString(),
                  latex: '', base64: '', color: nextColor, isVisible: true
                });

                this.activeIndex = this.functionList.length - 1;
                this.isKeyboardShow = true;
                this.saveFunctions();
                getContext(this).eventHub.emit('wake_web_engines');
                getContext(this).eventHub.emit('load_latex_to_editor', '');
              })
          }
          .padding({ left: 48, right: 48 }) // 保持对齐
        }
        .layoutWeight(1)
        .width('100%')
        // 保留跟随键盘上推的底部边距
        .padding({ top: 4, bottom: this.isKeyboardShow ? 520 : 4 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      }
      .width('100%')
      .height('100%')

      // ---------- 第 2 层：悬浮键盘坞 (常驻内存，仅做物理位移) ----------
      Column() {
        // 常驻底部的 WebView：永远存活，永远不会被裁切高度
        FormulaScreen({ moduleType: 'graphing' })
          .width('100%')
          .height(64)
          .backgroundColor($r('sys.color.comp_background_primary'))

        Grid() {
          ForEach(topButtons, (btn: string | Resource, index: number) => {
            GridItem() {
              TopKeyItem({
                btn: btn, btnIndex: index, isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }.zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
          })
        }
        .rowsTemplate('33fr 40fr 40fr').columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(6).columnsGap(4).padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false).width('100%').height(200)

        Grid() {
          ForEach(bottomButtons, (btn: string | Resource) => {
            GridItem() {
              BottomKeyItem({
                btn: btn, isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }.zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr').columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8).columnsGap(6).padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false).width('100%').height(250)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .padding({ bottom: this.navBarHeight - 8})
      // 核心魔法：100% 位移。为 0 时在屏幕内，为 '100%' 时刚好完全滑出屏幕底部边界。
      .translate({ y: this.isKeyboardShow ? 0 : '100%' })
      // 极其丝滑的阻尼弹簧动画曲线
      .animation({ duration: 300, curve: Curve.FastOutSlowIn })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    // 裁剪掉 Stack 溢出底部边缘的部分，避免影响其他 UI
    .clip(true)
  }
}