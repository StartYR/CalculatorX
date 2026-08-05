/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingEditSheet.ets
 * @description 图形计算器编辑面板：管理函数列表、状态流转及键盘交互中枢
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

import { FormulaScreen } from '../FormulaScreen';
import { GRAPHING_COLORS, getActionId } from '../../utils/CalculatorConfigs';
import { GraphFunctionItem, FunctionType } from './GraphingTypes';
import { TopKeyItem, BottomKeyItem, getDynamicTopButtons, bottomButtons, DomainKeyboard } from './GraphingKeyboard';
import { LengthMetrics } from '@kit.ArkUI';

const MAX_FUNCTIONS = 10; // 面板支持的最大函数数量上限

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
              this.controller?.close(); // 极致效率：点击即关闭并执行回调
            })
        }

        ListItem() {
          Button("极坐标方程 r(θ)", { type: ButtonType.Normal })
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(12)
            .onClick(() => {
              this.onTypeSelected(FunctionType.POLAR);
              this.controller?.close();
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

        ListItem() {
          Button("隐函数 f(x,y)", { type: ButtonType.Normal })
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(12)
            .onClick(() => {
              this.onTypeSelected(FunctionType.IMPLICIT);
              this.controller?.close();
            })
        }

        ListItem() {
          Button("点 (x, y)", { type: ButtonType.Normal })
            .width('100%')
            .height(48)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .borderRadius(12)
            .onClick(() => {
              this.onTypeSelected(FunctionType.POINT);
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

// ==================== 主编辑面板组件 ====================
@Component
export struct GraphingEditSheet {
  @Link functionList: GraphFunctionItem[];
  @Link activeIndex: number;
  @Link activeSubTarget: number; // 焦点追踪：0为主表达式，1为第二表达式
  @Link isKeyboardShow: boolean;
  @Link isSmallKeyboardShow: boolean;
  @Link isShift: boolean;
  @Link isDarkModeUI: boolean;

  // --- 定义域专属状态机 ---
  @State editDomainIndex: number = -1;
  @State editDomainField: 'tMin' | 'tMax' | '' = '';
  @State editDomainStr: string = '';
  @State currentCaretStart: number = 0; // 光标起始追踪
  @State currentCaretEnd: number = 0;   // 光标结束追踪

  // 扩展到 10 个控制器，完美匹配 MAX_FUNCTIONS 的上限，杜绝越界崩溃
  private tMinControllers: TextInputController[] = [
    new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(),
    new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController()
  ];
  private tMaxControllers: TextInputController[] = [
    new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(),
    new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController(), new TextInputController()
  ];

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';
  private listScroller: Scroller = new Scroller();

  aboutToAppear() {
    getContext(this).eventHub.on('force_close_domain_keyboard', () => {
      if (this.editDomainIndex !== -1) {
        let activeController = this.editDomainField === 'tMin' ? this.tMinControllers[this.editDomainIndex] : this.tMaxControllers[this.editDomainIndex];
        activeController?.stopEditing();
        this.editDomainIndex = -1;
        this.isSmallKeyboardShow = false; // 状态归位
      }
    });
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('force_close_domain_keyboard');
  }

  // 键盘动态布局辅助函数
  private getActiveFunctionType(): FunctionType | undefined {
    if (this.activeIndex >= 0 && this.activeIndex < this.functionList.length) {
      return this.functionList[this.activeIndex].type;
    }
    return undefined;
  }

  private isSingleVariableMode(): boolean {
    let type = this.getActiveFunctionType();
    // 显函数、参数方程、极坐标，拉长占位变量
    return type === FunctionType.NORMAL || type === FunctionType.PARAMETRIC || type === FunctionType.POLAR;
  }

  // ==================== 核心构建器 (Builder) 提取 ====================

  /**
   * @description 通用表达式输入行构建器
   * @param label 表达式前缀标签 (如 "x(t) = ")
   * @param base64Data 表达式渲染生成的图片数据
   * @param subTarget 焦点目标索引 (0 or 1)
   * @param placeholder 缺省时的占位提示文案
   * @param targetLatex 目标编辑器的底层 LaTeX 源码
   * @param index 当前卡片在列表中的索引
   */
  @Builder
  ExpressionRowBuilder(label: string, base64Data: string | undefined, subTarget: number, placeholder: string, targetLatex: string, index: number) {
    Row() {
      Text(label)
        .fontColor($r('sys.color.font_primary'))
        .fontSize(22)
        .fontFamily('Cambria Math')
        .fontWeight(FontWeight.Medium)
      if (base64Data) {
        Image(base64Data)
          .height(36)
          .objectFit(ImageFit.Contain)
          .flexShrink(1)
          .colorFilter(this.isDarkModeUI ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
      } else {
        Text((this.activeIndex === index && this.activeSubTarget === subTarget && this.isKeyboardShow) ? "正在编辑..." : placeholder)
          .fontColor($r('sys.color.font_secondary'))
          .height(36)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      this.switchEditorFocus(index, subTarget, targetLatex || '');
    })
  }

  /**
   * @description 通用定义域输入行构建器
   * @param variableSymbol 变量符号 (如 "t" 或 "θ")
   * @param item 当前函数的完整数据对象
   * @param index 当前卡片在列表中的索引
   */
  @Builder
  DomainRowBuilder(variableSymbol: string, item: GraphFunctionItem, index: number) {
    Row() {
      Text("定义域: ").fontColor($r('sys.color.font_secondary')).fontSize(14)

      TextInput({
        text: (this.editDomainIndex === index && this.editDomainField === 'tMin') ? this.editDomainStr : item.tMin?.toString(),
        controller: this.tMinControllers[index]
      })
        .width(60).height(28).fontSize(14).textAlign(TextAlign.Center)
        .padding({ top: 0, bottom: 0, left: 4, right: 4 })
        .customKeyboard(this.DomainKeyboardBuilder())
        .onFocus(() => { this.handleDomainFocus(index, 'tMin', item); })
        .onBlur(() => {
          this.editDomainIndex = -1;
          this.isSmallKeyboardShow = false;
        })
        .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
          this.currentCaretStart = selectionStart;
          this.currentCaretEnd = selectionEnd;
        })

      Text(` ≤ ${variableSymbol} ≤ `)
        .fontColor($r('sys.color.font_secondary')).fontSize(14).fontFamily('Cambria Math')

      TextInput({
        text: (this.editDomainIndex === index && this.editDomainField === 'tMax') ? this.editDomainStr : item.tMax?.toString(),
        controller: this.tMaxControllers[index]
      })
        .width(60).height(28).fontSize(14).textAlign(TextAlign.Center)
        .padding({ top: 0, bottom: 0, left: 4, right: 4 })
        .customKeyboard(this.DomainKeyboardBuilder())
        .onFocus(() => { this.handleDomainFocus(index, 'tMax', item); })
        .onBlur(() => {
          this.editDomainIndex = -1;
          this.isSmallKeyboardShow = false;
        })
        .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
          this.currentCaretStart = selectionStart;
          this.currentCaretEnd = selectionEnd;
        })
    }
    .width('100%').justifyContent(FlexAlign.Start).margin({ top: 4 })
  }

  // --- 纯净小键盘构建器 (含防并发篡改的光标追踪机制) ---
  @Builder
  DomainKeyboardBuilder() {
    DomainKeyboard({
      onKeyPress: (btn: string | Resource) => {
        let activeController = this.editDomainField === 'tMin' ? this.tMinControllers[this.editDomainIndex] : this.tMaxControllers[this.editDomainIndex];

        if (btn === '确定') {
          activeController?.stopEditing();
          this.editDomainIndex = -1;
          this.isSmallKeyboardShow = false;
        } else if (btn === 'AC') {
          this.editDomainStr = '0';
          this.currentCaretStart = 1;
          this.currentCaretEnd = 1;
          this.syncDomainValue();
          setTimeout(() => { activeController?.caretPosition(1); }, 20);
        } else if (typeof btn !== 'string') {
          // 光标感知的退格删除逻辑
          let targetCaret = this.currentCaretStart;

          if (this.currentCaretStart === this.currentCaretEnd) {
            if (this.currentCaretStart > 0) {
              let startStr = this.editDomainStr.substring(0, this.currentCaretStart - 1);
              let endStr = this.editDomainStr.substring(this.currentCaretStart);
              this.editDomainStr = startStr + endStr;
              targetCaret = this.currentCaretStart - 1;
            }
          } else {
            let startStr = this.editDomainStr.substring(0, this.currentCaretStart);
            let endStr = this.editDomainStr.substring(this.currentCaretEnd);
            this.editDomainStr = startStr + endStr;
            targetCaret = this.currentCaretStart;
          }

          this.currentCaretStart = targetCaret;
          this.currentCaretEnd = targetCaret;

          if (this.editDomainStr === '' || this.editDomainStr === '-') {
            this.syncDomainValue(0);
          } else {
            this.syncDomainValue();
          }

          // 延迟等待 ArkUI 渲染完毕，强制修正光标位置
          setTimeout(() => { activeController?.caretPosition(targetCaret); }, 20);

        } else {
          // 光标感知的文本插入逻辑
          let targetCaret = this.currentCaretStart;
          let insertStr = (btn === '−') ? '-' : (btn as string);

          if (this.editDomainStr === '0' && insertStr !== '.') {
            this.editDomainStr = insertStr;
            targetCaret = 1;
          } else {
            let startStr = this.editDomainStr.substring(0, this.currentCaretStart);
            let endStr = this.editDomainStr.substring(this.currentCaretEnd);
            this.editDomainStr = startStr + insertStr + endStr;
            targetCaret = this.currentCaretStart + insertStr.length;
          }

          this.currentCaretStart = targetCaret;
          this.currentCaretEnd = targetCaret;
          this.syncDomainValue();

          setTimeout(() => { activeController?.caretPosition(targetCaret); }, 20);
        }
      }
    })
  }

  // ==================== 状态同步与焦点调度逻辑 ====================

  /**
   * @description 强制绑定上下文的定义域值同步
   * @param fallback 解析失败时的兜底默认值
   */
  private syncDomainValue = (fallback: number = Number.NaN) => {
    if (this.editDomainIndex >= 0 && this.editDomainIndex < this.functionList.length) {
      let item = this.functionList[this.editDomainIndex];
      let val = Number.isNaN(fallback) ? (parseFloat(this.editDomainStr) || 0) : fallback;

      if (this.editDomainField === 'tMin') {
        item.tMin = val;
      } else if (this.editDomainField === 'tMax') {
        item.tMax = val;
      }

      this.functionList.splice(this.editDomainIndex, 1, item); // 强制触发视图级刷新
      this.saveFunctions();
    }
  }

  /**
   * @description 定义域输入框获焦时的综合调度
   */
  private handleDomainFocus = (index: number, field: 'tMin' | 'tMax', item: GraphFunctionItem) => {
    // 互斥：如果主键盘正开启，立刻保存数据并收起主键盘
    if (this.isKeyboardShow) {
      let magicId = this.activeIndex + (this.activeSubTarget * 10000);
      getContext(this).eventHub.emit('request_graphing_data', magicId);
      this.isKeyboardShow = false;
    }

    this.editDomainIndex = index;
    this.editDomainField = field;
    this.editDomainStr = (field === 'tMin' ? item.tMin : item.tMax)?.toString() || '0';
    this.isSmallKeyboardShow = true;

    // 智能滚动对齐
    setTimeout(() => {
      this.listScroller.scrollToIndex(index, true, ScrollAlign.START);
    }, 100);
  }

  /**
   * @description 主编辑器焦点切换核心逻辑
   */
  private switchEditorFocus(index: number, subTarget: number, targetLatex: string) {
    // 互斥：如果小键盘正开启，强制收起并失焦
    if (this.editDomainIndex !== -1) {
      let activeController = this.editDomainField === 'tMin' ? this.tMinControllers[this.editDomainIndex] : this.tMaxControllers[this.editDomainIndex];
      activeController?.stopEditing();
      this.editDomainIndex = -1;
      this.isSmallKeyboardShow = false;
    }

    if (this.activeIndex === index && this.activeSubTarget === subTarget && this.isKeyboardShow) return;

    // 冻结并保存即将失去焦点的编辑状态
    if (this.isKeyboardShow) {
      let magicId = this.activeIndex + (this.activeSubTarget * 10000);
      getContext(this).eventHub.emit('request_graphing_data', magicId);
    }

    this.activeIndex = index;
    this.activeSubTarget = subTarget;
    this.isKeyboardShow = true;

    // 唤起底层 CAS 引擎链路并注入源码
    getContext(this).eventHub.emit('wake_web_engines');
    getContext(this).eventHub.emit('load_latex_to_editor', targetLatex || '');

    setTimeout(() => {
      this.listScroller.scrollToIndex(index, true, ScrollAlign.START);
    }, 100);
  }

  // 接收从外层传入的回调，保持原有逻辑调用形式不变
  saveFunctions: () => void = () => {};
  handleButtonClick: (btn: string | Resource) => void = () => {};
  handleButtonLongPress: (actionCode: string) => void = () => {};

  // 弹窗控制器初始化
  dialogController: CustomDialogController = new CustomDialogController({
    builder: FunctionTypeDialog({
      onTypeSelected: (type: FunctionType) => {
        if (this.functionList.length >= MAX_FUNCTIONS) return;

        let usedColors = this.functionList.map(item => item.color);
        let nextColor = GRAPHING_COLORS.find(color => !usedColors.includes(color)) || GRAPHING_COLORS[0];

        this.functionList.push({
          id: Date.now().toString(),
          type: type,
          latex: '', base64: '', latex2: '', base64_2: '',
          tMin: -10, tMax: 10,
          color: nextColor, isVisible: true
        });

        this.activeIndex = this.functionList.length - 1;
        this.isKeyboardShow = true;
        this.saveFunctions();
        getContext(this).eventHub.emit('wake_web_engines');
        getContext(this).eventHub.emit('load_latex_to_editor', '');

        // 滑动到顶端
        setTimeout(() => {
          this.listScroller.scrollToIndex(this.activeIndex, true, ScrollAlign.START);
        }, 100);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  // --- 左滑删除专属组件 ---
  @Builder
  DeleteAction(index: number) {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(24)
          .fontColor([Color.White])
      }
      .width(40)
      .height(40)
      .backgroundColor('#FF3B30')
      .shadow({ radius: 8, color: '#33FF3B30', offsetY: 4 })
      .onClick(() => {
        // 提前记录删除前的状态分布，为后续的状态转移做准备
        let isDeletingActive = (this.activeIndex === index);
        let isDeletingAboveActive = (index < this.activeIndex);

        let isDeletingDomain = (this.editDomainIndex === index);
        let isDeletingAboveDomain = (index < this.editDomainIndex);

        // 允许完全清空列表
        animateTo({ duration: 350, curve: Curve.Friction }, () => {
          this.functionList.splice(index, 1);

          // 边界 1：如果列表空了，全面重置状态并收起所有键盘
          if (this.functionList.length === 0) {
            this.activeIndex = -1;
            this.isKeyboardShow = false;
            this.editDomainIndex = -1;
            this.isSmallKeyboardShow = false;
          } else {
            // 💡 核心状态转移逻辑 (主键盘)：
            if (isDeletingActive) {
              // 删除了正在编辑的项：失去焦点，直接收起键盘，切断数据污染链条！
              this.activeIndex = -1;
              this.isKeyboardShow = false;
            } else if (isDeletingAboveActive) {
              // 删除了上方项：当前编辑的项在数组中的索引 -1，必须同步调整 activeIndex 才能锁死原目标
              this.activeIndex -= 1;
            } else if (this.activeIndex >= this.functionList.length) {
              // 兜底防越界
              this.activeIndex = this.functionList.length - 1;
            }

            // 💡 核心状态转移逻辑 (定义域小键盘)：
            if (isDeletingDomain) {
              // 删除了正在编辑定义域的项：收起小键盘
              this.editDomainIndex = -1;
              this.isSmallKeyboardShow = false;
            } else if (isDeletingAboveDomain) {
              // 焦点跟随上移
              this.editDomainIndex -= 1;
            }
          }
        });
        this.saveFunctions(); // 数据持久化落盘
      })
    }
    .height('100%')
    .padding({ left: 16, right: 24 })
    .justifyContent(FlexAlign.Center)
  }

  // ==================== UI 渲染骨架 ====================
  build() {
    Stack({ alignContent: Alignment.Bottom }) {

      // ---------- 第 1 层：全屏列表与顶部标题 ----------
      Column() {
        Row() {
          Text("编辑函数图像")
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .padding({ left: 24, right: 0, top: 24, bottom: 16 })
        .backgroundColor('rgba(255, 255, 255, 0.00)')

        List({ space: 8, scroller: this.listScroller }) {
          ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
            ListItem() {
              Row() {
                // 左侧色彩与显隐控制单元
                Circle({ width: 14, height: 14 })
                  .fill(item.isVisible ? item.color : $r('sys.color.comp_divider'))
                  .margin({ right: 14 })
                  .onClick(() => {
                    let newItem: GraphFunctionItem = {
                      id: item.id, color: item.color, type: item.type,
                      isVisible: !item.isVisible, // 唯一改变的状态
                      latex: item.latex, base64: item.base64, ast: item.ast,
                      latex2: item.latex2, base64_2: item.base64_2, ast2: item.ast2,
                      tMin: item.tMin, tMax: item.tMax
                    };
                    this.functionList[index] = newItem;
                    this.saveFunctions();
                  })

                // 右侧动态表达式加载区 (重构后极其清爽的判断分支)
                Column() {
                  if (item.type === FunctionType.PARAMETRIC) {
                    Column({ space: 8 }) {
                      this.ExpressionRowBuilder("x(t) = ", item.base64, 0, "点击此处编辑...", item.latex || '', index)
                      this.ExpressionRowBuilder("y(t) = ", item.base64_2, 1, "点击此处编辑...", item.latex2 || '', index)
                      this.DomainRowBuilder("t", item, index)
                    }
                  } else if (item.type === FunctionType.POLAR) {
                    Column({ space: 8 }) {
                      this.ExpressionRowBuilder("r(θ) = ", item.base64, 0, "点击此处编辑...", item.latex || '', index)
                      this.DomainRowBuilder("θ", item, index)
                    }
                  } else if (item.type === FunctionType.IMPLICIT) {
                    this.ExpressionRowBuilder("f(x,y): ", item.base64, 0, "点击此处编辑方程...", item.latex || '', index)
                  } else if (item.type === FunctionType.POINT) {
                    Column({ space: 8 }) {
                      this.ExpressionRowBuilder("x = ", item.base64, 0, "点击此处编辑 x 坐标...", item.latex || '', index)
                      this.ExpressionRowBuilder("y = ", item.base64_2, 1, "点击此处编辑 y 坐标...", item.latex2 || '', index)
                    }
                  } else {
                    // 普通显函数兜底
                    this.ExpressionRowBuilder("f(x) = ", item.base64, 0, "点击此处编辑表达式...", item.latex || '', index)
                  }
                }
                .layoutWeight(1)
                .padding({ top: 12, bottom: 12 })
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor((this.activeIndex === index && this.isKeyboardShow) ? $r('sys.color.comp_background_tertiary') : $r('sys.color.background_primary'))
              .borderRadius(16)
            }
            .padding({ left: 16, right: 16 })
            .swipeAction({
              end: { builder: () => { this.DeleteAction(index) } },
              edgeEffect: SwipeEdgeEffect.Spring
            })
            .onClick(() => {
              // 兜底点击：点击空白区域时，默认选中第一行主表达式
              this.switchEditorFocus(index, 0, item.latex);
            })
          }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.isVisible}_${item.latex2 || ''}_${item.base64_2?.length || 0}`)

          // 列表尾部：新建函数挂载按钮
          ListItem() {
            Button(this.functionList.length >= MAX_FUNCTIONS ? `已达数量上限 (${MAX_FUNCTIONS}/${MAX_FUNCTIONS})` : "+ 添加新的函数",
              { type: ButtonType.Normal })
              .backgroundColor(Color.Transparent)
              .fontColor(this.functionList.length >= MAX_FUNCTIONS ? $r('sys.color.font_tertiary') : $r('sys.color.brand'))
              .borderRadius(50)
              .width('100%')
              .height(48)
              .onClick(() => {
                if (this.functionList.length >= MAX_FUNCTIONS) return;

                if (this.isKeyboardShow) {
                  let magicId = this.activeIndex + (this.activeSubTarget * 10000);
                  getContext(this).eventHub.emit('request_graphing_data', magicId);
                }
                this.dialogController.open();
              })
          }
          .padding({ left: 48, right: 48 })

          // 虚拟占位符：用于撑起软键盘遮挡空间
          ListItem() {
            Row()
              .width('100%')
              .height(this.isKeyboardShow ? 520 : (this.editDomainIndex !== -1 ? 270 : 16))
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ top: 4, bottom: 0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(12) })
      }
      .width('100%')
      .height('100%')

      // ---------- 第 2 层：悬浮键盘坞 (物理位移动画驱动) ----------
      Column() {
        // 常驻引擎通信与渲染枢纽 (隐藏式 WebView)
        FormulaScreen({ moduleType: 'graphing' })
          .width('100%')
          .height(64)
          .backgroundColor($r('sys.color.comp_background_primary'))

        Grid() {
          ForEach(getDynamicTopButtons(this.getActiveFunctionType()), (btn: string | Resource, index: number) => {
            // 💡 核心防线：如果是单变量模式，强行丢弃第 17 位的空占位符，防止高度坍塌
            if (!(index === 17 && this.isSingleVariableMode())) {
              GridItem() {
                TopKeyItem({
                  btn: btn, btnIndex: index, isShift: $isShift,
                  onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                  onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
                })
              }
              // 如果是单一未知数，横跨第 4 和第 5 列
              .columnStart((index === 16 && this.isSingleVariableMode()) ? 4 : undefined)
              .columnEnd((index === 16 && this.isSingleVariableMode()) ? 5 : undefined)
              .zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
            }
          })
        }
        .rowsTemplate('33fr 40fr 40fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(6)
        .columnsGap(4)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false)
        .width('100%')
        .height(200)

        Grid() {
          ForEach(bottomButtons, (btn: string | Resource) => {
            GridItem() {
              BottomKeyItem({
                btn: btn, isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }
            .zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8)
        .columnsGap(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false)
        .width('100%')
        .height(250)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .padding({ bottom: this.navBarHeight - 8})
      .borderRadius({ topLeft: 24, topRight: 24 })
      .clip(true)
      .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
      // 根据状态控制键盘物理隐退与展出
      .translate({ y: this.isKeyboardShow ? 0 : '100%' })
      .animation({ duration: 300, curve: Curve.FastOutSlowIn })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .clip(true)
  }
}