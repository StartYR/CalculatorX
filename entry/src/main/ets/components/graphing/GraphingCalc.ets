/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCalc.ets
 * @description 图形计算器主组件，负责组合画布、手势状态以及编辑面板
 * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:51
 */

import mediaquery from '@ohos.mediaquery';
import { HapticUtils } from '../../utils/HapticUtils';
import { getActionId, GRAPHING_COLORS, PreferenceConfigs } from '../../utils/CalculatorConfigs';
import { PreferenceManager } from '../../utils/PreferenceManager';
import { GraphFunctionItem, FunctionType } from './GraphingTypes';
import { GraphingCanvas } from './GraphingCanvas';
import { GraphingEditSheet } from './GraphingEditSheet';

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

// ==================== 图形计算器主组件 ====================
@Component
export struct GraphingCalc {
  // ---------- 编辑面板与键盘状态 ----------
  @State isEditSheetShow: boolean = false;
  @State isKeyboardShow: boolean = false; // 精准控制底座键盘与引擎显示折叠的核心状态
  @State activeSubTarget: number = 0; // 0 代表主表达式x(t)或f(x), 1 代表伴生表达式y(t)

  @State isSmallKeyboardShow: boolean = false; // 小键盘展开状态

  @StorageLink(PreferenceConfigs.KEY_GRAPHING_FUNCTIONS) graphingFunctionsJson: string = '[]';
  @State functionList: GraphFunctionItem[] = [];
  @State activeIndex: number = 0;

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @State @Watch('onShiftChange') isShift: boolean = false;

  @StorageProp('colorModeIndex') colorModeIndex: number = 2;
  @State isDarkModeUI: boolean = false;
  private darkMediaQuery: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('(dark-mode: true)');

  // 统一的深浅色判断逻辑
  private onColorModeChange() {
    if (this.colorModeIndex === 1) {
      this.isDarkModeUI = true;
    } else if (this.colorModeIndex === 2) {
      this.isDarkModeUI = this.darkMediaQuery.matches;
    } else {
      this.isDarkModeUI = false;
    }
  }

  private onDarkModeChange = (mediaQueryResult: mediaquery.MediaQueryResult) => {
    if (this.colorModeIndex === 2) {
      this.isDarkModeUI = mediaQueryResult.matches;
    }
  }

  aboutToAppear() {
    try {
      let parsedList = JSON.parse(this.graphingFunctionsJson) as GraphFunctionItem[];
      if (parsedList.length === 0) {
        parsedList = [{ id: Date.now().toString(), latex: '', base64: '', color: GRAPHING_COLORS[0], isVisible: true }];
      }
      this.functionList = parsedList;
    } catch (e) {
      this.functionList = [{ id: Date.now().toString(), latex: '', base64: '', color: GRAPHING_COLORS[0], isVisible: true }];
    }

    this.darkMediaQuery.on('change', this.onDarkModeChange);
    this.onColorModeChange();

    getContext(this).eventHub.on('screen_shift_consumed', () => {
      this.isShift = false;
    });

    getContext(this).eventHub.on('temp_graph_ast_ready', (encodedReqId: number, rawLatex: string, ast: string) => {

      let targetIndex = encodedReqId % 10000;
      let targetSubTarget = Math.floor(encodedReqId / 10000);

      if (targetIndex >= 0 && targetIndex < this.functionList.length) {
        let oldItem = this.functionList[targetIndex];
        let newItem: GraphFunctionItem = {
          id: oldItem.id, color: oldItem.color, isVisible: oldItem.isVisible, type: oldItem.type,
          tMin: oldItem.tMin, tMax: oldItem.tMax,
          latex: oldItem.latex, base64: oldItem.base64, ast: oldItem.ast,
          latex2: oldItem.latex2, base64_2: oldItem.base64_2, ast2: oldItem.ast2
        };

        if (targetSubTarget === 1) {
          newItem.latex2 = rawLatex;
          newItem.ast2 = ast;
        } else {
          newItem.latex = rawLatex;
          newItem.ast = ast;
        }

        this.functionList[targetIndex] = newItem;
        this.saveFunctions();
      }
    });

    getContext(this).eventHub.on('response_graph_base64_ready', (encodedReqId: number, base64: string) => {

      let targetIndex = encodedReqId % 10000;
      let targetSubTarget = Math.floor(encodedReqId / 10000);

      if (targetIndex >= 0 && targetIndex < this.functionList.length) {
        let oldItem = this.functionList[targetIndex];
        let newItem: GraphFunctionItem = {
          id: oldItem.id, color: oldItem.color, isVisible: oldItem.isVisible, type: oldItem.type,
          tMin: oldItem.tMin, tMax: oldItem.tMax,
          latex: oldItem.latex, base64: oldItem.base64, ast: oldItem.ast,
          latex2: oldItem.latex2, base64_2: oldItem.base64_2, ast2: oldItem.ast2
        };

        if (targetSubTarget === 1) {
          newItem.base64_2 = base64;
        } else {
          newItem.base64 = base64;
        }

        this.functionList[targetIndex] = newItem;
        this.saveFunctions();
      }
    });

    getContext(this).eventHub.on('open_graphing_edit_sheet', () => {
      this.isEditSheetShow = true;
    });
  }

  aboutToDisappear() {
    this.darkMediaQuery.off('change', this.onDarkModeChange);
    getContext(this).eventHub.off('open_graphing_edit_sheet');
    getContext(this).eventHub.off('screen_shift_consumed');
    getContext(this).eventHub.off('temp_graph_ast_ready');
    getContext(this).eventHub.off('response_graph_base64_ready');
  }

  private saveFunctions = () => {
    // 更新内存与 UI
    this.graphingFunctionsJson = JSON.stringify(this.functionList);
    // 调用 PreferenceManager，将数据真正写入磁盘
    PreferenceManager.set(PreferenceConfigs.KEY_GRAPHING_FUNCTIONS, this.graphingFunctionsJson);
  }

  onShiftChange() {
    getContext(this).eventHub.emit('event_shift_change', this.isShift);
  }

  // ==================== 拦截"确定"和"⌨⇩"按键 ====================
  private handleButtonClick = (btn: string | Resource) => {
    let action = getLocalActionId(btn);
    // 拦截"确定"按键：充当收起键盘坞和触发截图提取的指令
    if (btn === '确定' || btn === '⌨⇩') {
      HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
      if (this.isKeyboardShow) {
        let magicId = this.activeIndex + (this.activeSubTarget * 10000);
        getContext(this).eventHub.emit('request_graphing_data', magicId);
      }
      this.isKeyboardShow = false; // 折叠底层键盘坞
      return;
    }
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
    getContext(this).eventHub.emit('screen_handle_action', action, this.isShift);
  }

  private handleButtonLongPress = (actionCode: string) => {
    getContext(this).eventHub.emit('screen_handle_action', actionCode, this.isShift);
  }

  @Builder
  EditPanelBuilder() {
    GraphingEditSheet({
      functionList: $functionList,
      activeIndex: $activeIndex,
      activeSubTarget: $activeSubTarget,
      isKeyboardShow: $isKeyboardShow,
      isSmallKeyboardShow: $isSmallKeyboardShow,
      isShift: $isShift,
      isDarkModeUI: $isDarkModeUI,
      saveFunctions: this.saveFunctions,
      handleButtonClick: this.handleButtonClick,
      handleButtonLongPress: this.handleButtonLongPress
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 挂载独立出来的 Canvas 画布组件
      GraphingCanvas({
        functionList: $functionList
      })

      // 左上角图例
      Column({ space: 10 }) {
        ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
          if (item.isVisible) {
            Row({ space: 8 }) {
              // 左侧统一的颜色标识点
              Circle({ width: 10, height: 10 })
                .fill(item.color)

              // 右侧：根据不同函数类型，动态渲染对应的表达式前缀与图片
              Column({ space: 4 }) {
                if (item.type === FunctionType.PARAMETRIC) {
                  // --- 参数方程 x(t), y(t) 双行布局 ---
                  Row() {
                    Text("x(t) = ")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                    if (item.base64) {
                      Image(item.base64)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("等待输入...")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }
                  }
                  Row() {
                    Text("y(t) = ")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                    if (item.base64_2) {
                      Image(item.base64_2)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("等待输入...")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }
                  }
                } else if (item.type === FunctionType.POLAR) {
                  // --- 极坐标 r(θ) 单行布局 ---
                  Row() {
                    Text("r(θ) = ")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                    if (item.base64) {
                      Image(item.base64)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("等待输入...")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }
                  }
                } else if (item.type === FunctionType.IMPLICIT) {
                  // --- 隐函数 f(x,y) 单行布局 ---
                  Row() {
                    Text("f(x,y): ")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                    if (item.base64) {
                      Image(item.base64)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("等待输入...")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }
                  }
                } else if (item.type === FunctionType.POINT) {
                  // --- 坐标点 (x,y) ---
                  Row() {
                    Text("(")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)

                    // x 坐标
                    if (item.base64) {
                      Image(item.base64)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("?")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }

                    Text(", ")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)

                    // y 坐标
                    if (item.base64_2) {
                      Image(item.base64_2)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("?")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }

                    Text(")")
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                  }
                } else {
                  // --- 默认：普通显函数 f(x) 单行布局 ---
                  Row() {
                    Text(`f(x) = `)
                      .fontSize(20)
                      .fontFamily('Cambria Math')
                      .fontColor($r('sys.color.font_primary'))
                      .fontWeight(FontWeight.Medium)
                    if (item.base64) {
                      Image(item.base64)
                        .height(24)
                        .objectFit(ImageFit.Contain)
                        .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                    } else {
                      Text("等待输入...")
                        .fontSize(20)
                        .fontFamily('Cambria Math')
                        .fontColor($r('sys.color.font_secondary'))
                        .fontStyle(FontStyle.Italic)
                    }
                  }
                }
              }
              .alignItems(HorizontalAlign.Start) // 确保多行表达式左对齐
            }
            .padding({ top: 8, bottom: 8, left: 12, right: 12 })
            .backgroundColor(Color.Transparent)
            // .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })

            .borderRadius(12)
            .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 12 })
            .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
            .hitTestBehavior(HitTestMode.None)
          }
        }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.isVisible}_${item.latex2 || ''}_${item.base64_2?.length || 0}`)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 80, left: 12 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.isEditSheetShow, this.EditPanelBuilder(), {
      height: '100%',
      dragBar: true,
      backgroundColor: $r('sys.color.background_secondary'),

      // --- 智能拦截返回行为 ---
      onWillDismiss: ((sheetDismiss: SheetDismiss) => {
        if (this.isKeyboardShow) {
          // 情况 A：主键盘开着 -> 抢救数据，收起主键盘，阻止面板关闭
          let magicId = this.activeIndex + (this.activeSubTarget * 10000);
          getContext(this).eventHub.emit('request_graphing_data', magicId);
          this.isKeyboardShow = false;
        } else if (this.isSmallKeyboardShow) {
          // 情况 B：小键盘开着 -> 广播信号让面板收起小键盘，阻止面板关闭
          getContext(this).eventHub.emit('force_close_domain_keyboard');
        } else {
          // 情况 C：都没开 -> 直接放行，关掉整个半模态窗口
          sheetDismiss.dismiss();
        }
      }),

      // 在即将关闭时抢救数据
      onWillDisappear: () => {
        // 关闭动画开始，让引擎提取最后一次输入的数据
        if (this.isKeyboardShow) {
          let magicId = this.activeIndex + (this.activeSubTarget * 10000);
          getContext(this).eventHub.emit('request_graphing_data', magicId);
        }
      },

      // 完全关闭后的安全清理
      onDisappear: () => {
        // 面板已经完全销毁，休眠引擎并重置状态
        getContext(this).eventHub.emit('sleep_web_engines');
        this.isKeyboardShow = false;
      }
    })
  }
}