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
import { FunctionType } from './GraphingTypes';

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

// ==================== 函数类型选择弹窗 ====================
@CustomDialog
export struct FunctionTypeDialog {
  controller?: CustomDialogController;
  onTypeSelected: (type: FunctionType) => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text("选择函数类型")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .margin({ top: 16, bottom: 8 })

      List({ space: 12 }) {
        ListItem() {
          Button("普通函数 f(x)", { type: ButtonType.Normal })
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(12)
            .onClick(() => {
              this.onTypeSelected(FunctionType.NORMAL);
              this.controller?.close(); // 极致效率：点击即关闭并执行
            })
        }
        ListItem() {
          Button("参数方程 x(t), y(t)", { type: ButtonType.Normal })
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(12)
            .onClick(() => {
              this.onTypeSelected(FunctionType.PARAMETRIC);
              this.controller?.close();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('90%')
    .backgroundColor($r('sys.color.background_primary'))
    .borderRadius(24)
  }
}

@Component
export struct GraphingEditSheet {
  @Link functionList: GraphFunctionItem[];
  @Link activeIndex: number;
  @Link activeSubTarget: number; // 接收子焦点状态
  @Link isKeyboardShow: boolean;
  @Link isShift: boolean;
  @Link isDarkModeUI: boolean;

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';

  // 焦点切换辅助函数
  private switchEditorFocus(index: number, subTarget: number, targetLatex: string) {
    if (this.activeIndex === index && this.activeSubTarget === subTarget && this.isKeyboardShow) return;
    if (this.isKeyboardShow) {
      // 🔒 核心修复：冻结即将失去焦点的状态！
      let magicId = this.activeIndex + (this.activeSubTarget * 10000);
      getContext(this).eventHub.emit('request_graphing_data', magicId);
    }
    this.activeIndex = index;
    this.activeSubTarget = subTarget;
    this.isKeyboardShow = true;
    getContext(this).eventHub.emit('wake_web_engines');
    getContext(this).eventHub.emit('load_latex_to_editor', targetLatex || '');
  }

  // 接收从外层传入的回调，保持原有逻辑调用形式不变
  saveFunctions: () => void = () => {};
  handleButtonClick: (btn: string | Resource) => void = () => {};
  handleButtonLongPress: (actionCode: string) => void = () => {};

  // 弹窗控制器的实例化
  dialogController: CustomDialogController = new CustomDialogController({
    builder: FunctionTypeDialog({
      onTypeSelected: (type: FunctionType) => {
        if (this.functionList.length >= 5) return;

        let usedColors = this.functionList.map(item => item.color);
        let nextColor = GRAPHING_COLORS.find(color => !usedColors.includes(color)) || GRAPHING_COLORS[0];

        this.functionList.push({
          id: Date.now().toString(),
          type: type,
          latex: '', base64: '', latex2: '', base64_2: '',
          tMin: -10, tMax: 10, // 默认参数范围 0 到 2π
          color: nextColor, isVisible: true
        });

        this.activeIndex = this.functionList.length - 1;
        this.isKeyboardShow = true;
        this.saveFunctions();
        getContext(this).eventHub.emit('wake_web_engines');
        getContext(this).eventHub.emit('load_latex_to_editor', '');
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

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
                      color: item.color,
                      isVisible: !item.isVisible, // 唯一改变的状态
                      type: item.type,            // 必须带上类型
                      latex: item.latex,
                      base64: item.base64,
                      ast: item.ast,
                      latex2: item.latex2,        // 必须带上第二表达式
                      base64_2: item.base64_2,
                      ast2: item.ast2,
                      tMin: item.tMin,            // 必须带上定义域
                      tMax: item.tMax
                    };
                    this.functionList[index] = newItem;
                    this.saveFunctions();
                  })

                /// 右侧内容区
                Column() {
                  if (item.type === FunctionType.PARAMETRIC) {
                    // --- 参数方程：极其清晰的三排纵向布局 ---
                    Column({ space: 8 }) {
                      // 1. x(t)
                      Row() {
                        Text("x(t) = ").fontColor($r('sys.color.font_primary')).fontSize(16).fontWeight(FontWeight.Medium)
                        if (item.base64) {
                          Image(item.base64).height(36).objectFit(ImageFit.Contain)
                            .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                        } else {
                          Text((this.activeIndex === index && this.activeSubTarget === 0 && this.isKeyboardShow) ? "正在编辑..." : "点击此处编辑...")
                            .fontColor($r('sys.color.font_secondary')).height(36)
                        }
                      }.width('100%').justifyContent(FlexAlign.Start)

                      // 2. y(t)
                      Row() {
                        Text("y(t) = ").fontColor($r('sys.color.font_primary')).fontSize(16).fontWeight(FontWeight.Medium)
                        if (item.base64_2) {
                          Image(item.base64_2).height(36).objectFit(ImageFit.Contain)
                            .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                        } else {
                          Text((this.activeIndex === index && this.activeSubTarget === 1 && this.isKeyboardShow) ? "正在编辑..." : "点击此处编辑...")
                            .fontColor($r('sys.color.font_secondary')).height(36)
                        }
                      }.width('100%').justifyContent(FlexAlign.Start)
                      .onClick((event) => {
                        // 点 y(t) 时，不要触发下方外层的 ListItem 点击事件
                        this.switchEditorFocus(index, 1, item.latex2 || '');
                      })

                      // 3. 定义域
                      Row() {
                        Text("定义域: ").fontColor($r('sys.color.font_secondary')).fontSize(14)

                        TextInput({ text: item.tMin?.toString() })
                          .width(60)
                          .height(28)
                          .fontSize(14)
                          .type(InputType.Normal)
                          .textAlign(TextAlign.Center) // 文字居中，视觉更平衡
                          .padding({ top: 0, bottom: 0, left: 4, right: 4 })
                          .onChange((val) => { item.tMin = parseFloat(val) || 0; this.saveFunctions(); })

                        Text(" ≤ t ≤ ").fontColor($r('sys.color.font_secondary')).fontSize(14)

                        TextInput({ text: item.tMax?.toString() })
                          .width(60)
                          .height(28)
                          .fontSize(14)
                          .type(InputType.Normal)
                          .textAlign(TextAlign.Center) // 文字居中
                          .padding({ top: 0, bottom: 0, left: 4, right: 4 })
                          .onChange((val) => { item.tMax = parseFloat(val) || 0; this.saveFunctions(); })
                      }
                      .width('100%').justifyContent(FlexAlign.Start).margin({ top: 4 })
                    }
                  } else {
                    // --- 普通显函数布局：加上直观的 f(x) 前缀 ---
                    Row() {
                      Text("f(x) = ").fontColor($r('sys.color.font_primary')).fontSize(16).fontWeight(FontWeight.Medium)
                      if (item.base64) {
                        Image(item.base64).height(36).objectFit(ImageFit.Contain)
                          .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                      } else {
                        Text((this.activeIndex === index && this.activeSubTarget === 0 && this.isKeyboardShow) ? "正在编辑..." : "点击此处编辑表达式...")
                          .fontColor($r('sys.color.font_secondary')).height(36)
                      }
                    }.width('100%').justifyContent(FlexAlign.Start)
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
              // 作为兜底点击，任何未被阻断的点击（比如点到空白处、点到 x(t)），都默认编辑第 0 号主表达式
              this.switchEditorFocus(index, 0, item.latex);
            })
          }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.isVisible}_${item.latex2 || ''}_${item.base64_2?.length || 0}`)

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
                  let magicId = this.activeIndex + (this.activeSubTarget * 10000);
                  getContext(this).eventHub.emit('request_graphing_data', magicId);
                }

                // 唤起弹窗，让用户选择要创建的函数类型，剩下的新建逻辑移交给了 Dialog！
                this.dialogController.open();
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