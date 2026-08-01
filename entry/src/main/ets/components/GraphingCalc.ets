/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCalc.ets
 * @description 图形计算器主组件，负责坐标系渲染、手势交互和编辑面板管理
 * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:51
 */
/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCalc.ets
 * @description 图形计算器主组件，负责坐标系渲染、手势交互和编辑面板管理 (隐藏键盘坞终极架构)
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';
import {
  icon_sqrt, icon_sqrt3, icon_sqrtx, icon_power2, icon_power3,
  icon_power, icon_fraction, icon_abs, icon_backspace
} from '../utils/CalculatorConfigs';
import { KeyGestureWrapper } from './common/KeyGestureWrapper';
import mediaquery from '@ohos.mediaquery';
import { GRAPHING_COLORS } from '../utils/CalculatorConfigs';
import { EngineService, CalcConfig } from '../utils/EngineService';

// ==================== 函数项数据结构 ====================
export interface GraphFunctionItem {
  id: string;
  latex: string;
  base64: string;
  color: string;
  isVisible: boolean;
  ast?: string;
}

// ==================== 按键布局配置 ====================
const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  icon_sqrt3, icon_abs, icon_power3, '', '', 'lg',
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '', ''
];
const topButtons: Array<string | Resource> = [
  '⇧Shift', '', '⇦', '⇨', '(', ')',
  icon_sqrt, icon_sqrtx, icon_power2, icon_power,'log', 'ln',
  'sin', 'cos', 'tan', icon_fraction, 'x', 'θ'
];
const bottomButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'π', 'e', '确定'
];

function getLocalFontColor(btn: string | Resource): ResourceColor {
  if (btn === '=') return getFontColor('+');
  if (btn === 'π' || btn === 'e') return getFontColor('0');
  return getFontColor(btn);
}

function getLocalBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  if (btn === '=') return getBgColor('+', false);
  if (btn === 'π' || btn === 'e') return getBgColor('0', false);
  return getBgColor(btn, isShift);
}

function getLocalFontSize(btn: string | Resource): number {
  if (btn === 'π' || btn === 'e') return getFontSize('0');
  return getFontSize(btn);
}

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    Column() {
      if (this.btnIndex >= 6) {
        Row() {
          if (typeof topShiftButtons[this.btnIndex] === 'string') {
            Text(topShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(topShiftButtons[this.btnIndex]))
              .fontSize(17)
              .fontColor('#ffac8100')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
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

      Row() {
        KeyGestureWrapper({
          actionId: getLocalActionId(this.btn),
          targetBtn: this.btn,
          shiftBtn: topShiftButtons[this.btnIndex] || '',
          moduleType: 'graphing',
          isShiftMode: $isShift,
          onKeyPress: this.onKeyPress,
          onMenuSelect: this.onMenuSelect
        }) {
          Button() {
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
          .type(ButtonType.Normal)
          .borderRadius(12)
          .width('100%')
          .height('100%')
          .padding({ left: 2, right: 2 })
          .backgroundColor(getLocalBgColor(this.btn, this.isShift))
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
          .borderColor($r('app.color.btn_highlight'))
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .stateStyles({
            pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
            normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
          })
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
struct BottomKeyItem {
  btn: string | Resource = '';
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

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
      Button() {
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
      .type(ButtonType.Normal)
      .borderRadius(16)
      .width('100%')
      .height('100%')
      .padding({ left: 4, right: 4 })
      .backgroundColor(getLocalBgColor(this.btn, false))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
      .borderColor($r('app.color.btn_highlight'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .stateStyles({
        pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
        normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
      })
    }
  }
}

// ==================== 图形计算器主组件 ====================
@Component
export struct GraphingCalc {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  @State @Watch('requestDraw') viewScale: number = 80;
  @State @Watch('requestDraw') offsetX: number = 0;
  @State @Watch('requestDraw') offsetY: number = 0;
  @StorageProp('colorModeIndex')
  @Watch('requestDraw') colorModeIndex: number = 2;
  @State isDarkModeUI: boolean = false;

  private lastOffsetX: number = 0;
  private lastOffsetY: number = 0;
  private lastViewScale: number = 80;

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
    this.requestDraw(); // 触发画布重绘
  }

  private onDarkModeChange = (mediaQueryResult: mediaquery.MediaQueryResult) => {
    if (this.colorModeIndex === 2) {
      this.isDarkModeUI = mediaQueryResult.matches;
      this.requestDraw();
    }
  }

  // ---------- 编辑面板与键盘状态 ----------
  @State isEditSheetShow: boolean = false;
  // 新增：精准控制底座键盘与引擎显示折叠的核心状态
  @State isKeyboardShow: boolean = false;

  @StorageLink(PreferenceConfigs.KEY_GRAPHING_FUNCTIONS) graphingFunctionsJson: string = '[]';
  @State functionList: GraphFunctionItem[] = [];
  @State activeIndex: number = 0;

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @State @Watch('onShiftChange') isShift: boolean = false;

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
        this.functionList[reqId].latex = rawLatex;
        this.functionList[reqId].ast = ast;
        this.functionList.splice(reqId, 1, this.functionList[reqId]);
        this.saveFunctions();
        this.requestDraw();
      }
    });

    getContext(this).eventHub.on('response_graph_base64_ready', (reqId: number, base64: string) => {
      if (reqId >= 0 && reqId < this.functionList.length) {
        this.functionList[reqId].base64 = base64;
        this.functionList.splice(reqId, 1, this.functionList[reqId]);
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

  private saveFunctions() {
    this.graphingFunctionsJson = JSON.stringify(this.functionList);
  }

  private requestDraw() {
    if (this.canvasWidth === 0 || this.canvasHeight === 0) return;
    this.drawCoordinateSystem();
  }

  private drawCoordinateSystem() {
    let ctx = this.context;
    let width = this.canvasWidth;
    let height = this.canvasHeight;

    let isDark = this.colorModeIndex === 1;
    if (this.colorModeIndex === 2) {
      try { isDark = getContext(this).resourceManager.getConfigurationSync().colorMode === 0; } catch (e) {}
    }

    let gridColor = isDark ? '#333333' : '#E0E0E0';
    let axisColor = isDark ? '#888888' : '#333333';
    let textColor = isDark ? '#AAAAAA' : '#666666';

    ctx.clearRect(0, 0, width, height);
    let originX = width / 2 + this.offsetX;
    let originY = height / 2 + this.offsetY;

    let minSpacingPx = 40;
    let rawStep = minSpacingPx / this.viewScale;
    let magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
    let residual = rawStep / magnitude;

    let step = magnitude;
    if (residual > 5) step = 10 * magnitude;
    else if (residual > 2) step = 5 * magnitude;
    else if (residual > 1) step = 2 * magnitude;

    ctx.lineWidth = 1;
    ctx.strokeStyle = gridColor;
    ctx.beginPath();

    let xMin = (0 - originX) / this.viewScale;
    let xMax = (width - originX) / this.viewScale;
    let yMin = (originY - height) / this.viewScale;
    let yMax = (originY - 0) / this.viewScale;

    let startX = Math.ceil(xMin / step) * step;
    for (let x = startX; x <= xMax; x += step) {
      let px = originX + x * this.viewScale;
      ctx.moveTo(px, 0); ctx.lineTo(px, height);
    }
    let startY = Math.ceil(yMin / step) * step;
    for (let y = startY; y <= yMax; y += step) {
      let py = originY - y * this.viewScale;
      ctx.moveTo(0, py); ctx.lineTo(width, py);
    }
    ctx.stroke();

    ctx.lineWidth = 1.5;
    ctx.strokeStyle = axisColor;
    ctx.beginPath();
    if (originY >= 0 && originY <= height) { ctx.moveTo(0, originY); ctx.lineTo(width, originY); }
    if (originX >= 0 && originX <= width) { ctx.moveTo(originX, 0); ctx.lineTo(originX, height); }
    ctx.stroke();

    ctx.font = '36px sans-serif';
    ctx.fillStyle = textColor;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';

    let toFixedNum = step < 1 ? Math.abs(Math.floor(Math.log10(step))) : 0;

    for (let x = startX; x <= xMax; x += step) {
      if (Math.abs(x) < step / 2) continue;
      let px = originX + x * this.viewScale;
      let textY = (originY >= 0 && originY <= height) ? originY + 5 : 5;
      if (originY > height - 20) textY = height - 25;
      ctx.fillText(Number(x.toFixed(toFixedNum)).toString(), px, textY);
    }

    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    for (let y = startY; y <= yMax; y += step) {
      if (Math.abs(y) < step / 2) continue;
      let py = originY - y * this.viewScale;
      let textX = (originX >= 0 && originX <= width) ? originX - 8 : width - 8;
      if (originX < 30) textX = 35;
      ctx.fillText(Number(y.toFixed(toFixedNum)).toString(), textX, py);
    }

    if (originX >= -20 && originX <= width + 20 && originY >= -20 && originY <= height + 20) {
      ctx.textAlign = 'right';
      ctx.textBaseline = 'top';
      ctx.fillText('0', originX - 8, originY + 8);
    }

    let pointsCount = Math.floor(width);
    if (pointsCount < 100) pointsCount = 100;

    for (let i = 0; i < this.functionList.length; i++) {
      let funcItem = this.functionList[i];
      if (!funcItem.isVisible || !funcItem.ast || funcItem.ast.includes('"Error"')) continue;

      let config: CalcConfig = {
        isRad: AppStorage.get<boolean>('isRad') || false,
        precision: -1,
        mode: 3,
        xMin: xMin, xMax: xMax, pointsCount: pointsCount
      };

      let points = EngineService.calculateGraphPoints(funcItem.ast, config);
      if (!points || points.length === 0) continue;

      ctx.beginPath();
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = funcItem.color;

      let stepX = (xMax - xMin) / (pointsCount - 1);
      let isFirstPoint = true;

      for (let p = 0; p < pointsCount; p++) {
        let mathY = points[p];
        if (Number.isNaN(mathY)) {
          isFirstPoint = true;
          continue;
        }

        let mathX = xMin + p * stepX;
        let px = originX + mathX * this.viewScale;
        let py = originY - mathY * this.viewScale;

        if (isFirstPoint) {
          ctx.moveTo(px, py);
          isFirstPoint = false;
        } else {
          ctx.lineTo(px, py);
        }
      }
      ctx.stroke();
    }
  }

  private handlePanUpdate(event: GestureEvent) {
    this.offsetX = this.lastOffsetX + event.offsetX;
    this.offsetY = this.lastOffsetY + event.offsetY;
  }
  private handlePanEnd() {
    this.lastOffsetX = this.offsetX;
    this.lastOffsetY = this.offsetY;
  }
  private handlePinchUpdate(event: GestureEvent) {
    let newScale = this.lastViewScale * event.scale;
    if (newScale < 0.00001) newScale = 0.00001;
    if (newScale > 10000000) newScale = 10000000;
    this.viewScale = newScale;
  }
  private handlePinchEnd() {
    this.lastViewScale = this.viewScale;
  }

  onShiftChange() {
    getContext(this).eventHub.emit('event_shift_change', this.isShift);
  }

  // ==================== 修改：专机拦截“确定”按键 ====================
  private handleButtonClick(btn: string | Resource) {
    // 拦截“确定”按键：充当收起键盘坞和触发截图提取的指令
    if (btn === '确定') {
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

  private handleButtonLongPress(actionCode: string) {
    getContext(this).eventHub.emit('screen_handle_action', actionCode, this.isShift);
  }

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
          // 引入 UniversalHistoryList 同款摩擦力弹簧动画[cite: 5]
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

  @Builder
  EditPanelBuilder() {
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

        // 纯净展示列表
        List({ space: 8 }) {
          ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
            ListItem() {
              Row() {
                // 左侧颜色标识 (参考历史记录左侧图标的边距)
                Circle({ width: 14, height: 14 })
                  .fill(item.isVisible ? item.color : $r('sys.color.comp_divider'))
                  .margin({ right: 14 })
                  .onClick(() => {
                    item.isVisible = !item.isVisible;
                    this.functionList.splice(index, 1, item);
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
              .backgroundColor((this.activeIndex === index && this.isKeyboardShow) ? $r('sys.color.comp_background_primary') : Color.Transparent)
              .borderRadius(16) // 与历史记录一致的 16 圆角
            }
            // ★ 核心魔法：这一层 padding 把内容往里挤，但 ListItem 依然占满全屏！
            .padding({ left: 16, right: 16 })
            .swipeAction({
              end: { builder: () => { this.DeleteAction(index) } }, // 绑定新的滑动块
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
                // 3. 物理阻断：如果达到 5 条，拦截点击事件
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.canvasWidth = newValue.width as number;
          this.canvasHeight = newValue.height as number;
          this.requestDraw();
        })
        .onReady(() => { this.requestDraw(); })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PanGesture().onActionUpdate((event: GestureEvent) => this.handlePanUpdate(event)).onActionEnd(() => this.handlePanEnd()),
            PinchGesture().onActionUpdate((event: GestureEvent) => this.handlePinchUpdate(event)).onActionEnd(() => this.handlePinchEnd())
          )
        )

      Column({ space: 10 }) {
        ForEach(this.functionList, (item: GraphFunctionItem, index: number) => {
          if (item.isVisible) {
            Row({ space: 8 }) {
              Circle({ width: 10, height: 10 }).fill(item.color)
              Text(`y${index + 1} = `).fontSize(20).fontColor($r('sys.color.font_primary')).fontWeight(FontWeight.Medium)

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
            .backgroundColor('#40ffffff')
            .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })
            .borderRadius(12)
            .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 12 })
            .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
          }
        }, (item: GraphFunctionItem) => `${item.id}_${item.latex}_${item.base64.length}_${item.base64.slice(-20)}_${item.isVisible}`)
      }
      .margin({ top: 80, left: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.isEditSheetShow, this.EditPanelBuilder(), {
      height: '95%',
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