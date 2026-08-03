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
import { GraphFunctionItem } from './GraphingTypes';
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
  // 精准控制底座键盘与引擎显示折叠的核心状态
  @State isKeyboardShow: boolean = false;

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

    getContext(this).eventHub.on('temp_graph_ast_ready', (reqId: number, rawLatex: string, ast: string) => {
      if (reqId >= 0 && reqId < this.functionList.length) {
        let oldItem = this.functionList[reqId];
        let newItem: GraphFunctionItem = {
          id: oldItem.id,
          latex: rawLatex,
          base64: oldItem.base64,
          color: oldItem.color,
          isVisible: oldItem.isVisible,
          ast: ast
        };
        this.functionList[reqId] = newItem;
        this.saveFunctions();
      }
    });

    getContext(this).eventHub.on('response_graph_base64_ready', (reqId: number, base64: string) => {
      if (reqId >= 0 && reqId < this.functionList.length) {
        let oldItem = this.functionList[reqId];
        let newItem: GraphFunctionItem = {
          id: oldItem.id,
          latex: oldItem.latex,
          base64: base64,
          color: oldItem.color,
          isVisible: oldItem.isVisible,
          ast: oldItem.ast
        };
        this.functionList[reqId] = newItem;
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

  // ==================== 拦截“确定”和“关闭”按键 ====================
  private handleButtonClick = (btn: string | Resource) => {
    // 拦截“确定”按键：充当收起键盘坞和触发截图提取的指令
    if (btn === '确定' || btn === '关闭') {
      if (this.isKeyboardShow) {
        getContext(this).eventHub.emit('request_graphing_data', this.activeIndex);
      }
      this.isKeyboardShow = false; // 折叠底层键盘坞
      return;
    }
    let action = getLocalActionId(btn);
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
      isKeyboardShow: $isKeyboardShow,
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

      Column({ space: 10 }) {
        ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
          if (item.isVisible) {
            Row({ space: 8 }) {
              Circle({ width: 10, height: 10 })
                .fill(item.color)
              Text(`y${"₁₂₃₄₅".charAt(index)} = `)
                .fontSize(20)
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
                  .fontColor($r('sys.color.font_secondary'))
                  .fontStyle(FontStyle.Italic)
              }
            }
            .padding({ top: 8, bottom: 8, left: 12, right: 12 })
            .backgroundColor(Color.Transparent)
            // .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })

            .borderRadius(12)
            .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 12 })
            .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
          }
        }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.base64.slice(-20)}_${item.isVisible}`)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 80, left: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.isEditSheetShow, this.EditPanelBuilder(), {
      height: '78%',
      dragBar: true,
      backgroundColor: $r('sys.color.background_secondary'),

      // 在即将关闭时抢救数据
      onWillDisappear: () => {
        // 关闭动画开始，让引擎提取最后一次输入的数据
        if (this.isKeyboardShow) {
          getContext(this).eventHub.emit('request_graphing_data', this.activeIndex);
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