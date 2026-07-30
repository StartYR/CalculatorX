/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCalc.ets
 * @description 图形计算器主组件，负责坐标系渲染、手势交互和编辑面板管理
 * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:51
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

// ==================== 按键样式适配函数 ====================
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

// ==================== 键盘子组件 ====================
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
      // Shift 功能提示区
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
        Row()
          .width('100%')
          .height(6)
      }

      // 主按键区域
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
  // ---------- 画布渲染引擎 ----------
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 画布的物理尺寸
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  // 核心视图状态（触发 @Watch 进行极低开销的路径重绘，绝不重新实例化 Canvas 组件）
  @State @Watch('requestDraw') viewScale: number = 80;    // 缩放比例（1个单位刻度占用多少物理像素）
  @State @Watch('requestDraw') offsetX: number = 0;   // 坐标原点相对屏幕中心的 X 偏移量
  @State @Watch('requestDraw') offsetY: number = 0;   // 坐标原点相对屏幕中心的 Y 偏移量

  // 获取全局深浅色配置，并监听变化触发画布重绘
  @StorageProp('colorModeIndex') @Watch('requestDraw') colorModeIndex: number = 2;

  // 手势过程中的临时状态，用于增量计算
  private lastOffsetX: number = 0;
  private lastOffsetY: number = 0;
  private lastViewScale: number = 80;

  // 系统深色模式的媒体查询监听器
  private darkMediaQuery: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('(dark-mode: true)');

  // 响应系统主题变化的回调函数
  private onDarkModeChange = (mediaQueryResult: mediaquery.MediaQueryResult) => {
    // 只有当设置为"跟随系统" (2) 时，系统级别的深浅切换才需要主动触发重绘
    if (this.colorModeIndex === 2) {
      this.requestDraw();
    }
  }

  // ---------- 编辑面板状态 ----------
  @State isEditSheetShow: boolean = false;

  // ---------- 键盘相关状态 ----------
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  @State @Watch('onShiftChange') isShift: boolean = false;

  // ---------- 生命周期 ----------
  aboutToAppear() {
    // 注册系统主题变化监听
    this.darkMediaQuery.on('change', this.onDarkModeChange);
    getContext(this).eventHub.on('open_graphing_edit_sheet', () => {
      this.isEditSheetShow = true;
    });
    // 监听 Shift 被消费的事件
    getContext(this).eventHub.on('screen_shift_consumed', () => {
      this.isShift = false;
    });
  }

  aboutToDisappear() {
    // 组件销毁时注销监听，防止内存泄漏
    this.darkMediaQuery.off('change', this.onDarkModeChange);
    getContext(this).eventHub.off('open_graphing_edit_sheet');
    getContext(this).eventHub.off('screen_shift_consumed');
  }

  // ---------- 重绘调度 ----------
  // 统一的重绘分发器
  private requestDraw() {
    if (this.canvasWidth === 0 || this.canvasHeight === 0) return;
    this.drawCoordinateSystem();
  }

  /**
   * 核心：自适应网格与坐标轴渲染引擎
   */
  private drawCoordinateSystem() {
    let ctx = this.context;
    let width = this.canvasWidth;
    let height = this.canvasHeight;

    // --- 深浅色模式判断 ---
    let isDark = this.colorModeIndex === 1;
    if (this.colorModeIndex === 2) {
      try {
        // 0 为 COLOR_MODE_DARK
        isDark = getContext(this).resourceManager.getConfigurationSync().colorMode === 0;
      } catch (e) {}
    }

    // 动态配色表
    let gridColor = isDark ? '#333333' : '#E0E0E0';
    let axisColor = isDark ? '#888888' : '#333333';
    let textColor = isDark ? '#AAAAAA' : '#666666';

    // 1. 清空画布，准备重绘
    ctx.clearRect(0, 0, width, height);

    // 计算物理原点位置 (画布中心 + 偏移量)
    let originX = width / 2 + this.offsetX;
    let originY = height / 2 + this.offsetY;

    // 2. 动态网格步长算法
    let minSpacingPx = 40;  // 相邻两个刻度的最小像素距离
    let rawStep = minSpacingPx / this.viewScale;
    let magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
    let residual = rawStep / magnitude;

    let step = magnitude;
    if (residual > 5) step = 10 * magnitude;
    else if (residual > 2) step = 5 * magnitude;
    else if (residual > 1) step = 2 * magnitude;

    // 3. 绘制次级网格线 (浅灰色)
    ctx.lineWidth = 1;
    ctx.strokeStyle = gridColor;
    ctx.beginPath();

    // 计算当前视野内可见的坐标范围
    let xMin = (0 - originX) / this.viewScale;
    let xMax = (width - originX) / this.viewScale;
    let yMin = (originY - height) / this.viewScale; // Y 轴屏幕向下为正，数学向上为正
    let yMax = (originY - 0) / this.viewScale;

    // 绘制 X 轴方向的网格 (垂直线)
    let startX = Math.ceil(xMin / step) * step;
    for (let x = startX; x <= xMax; x += step) {
      let px = originX + x * this.viewScale;
      ctx.moveTo(px, 0);
      ctx.lineTo(px, height);
    }
    // 绘制 Y 轴方向的网格 (水平线)
    let startY = Math.ceil(yMin / step) * step;
    for (let y = startY; y <= yMax; y += step) {
      let py = originY - y * this.viewScale;
      ctx.moveTo(0, py);
      ctx.lineTo(width, py);
    }
    ctx.stroke();

    // 4. 绘制主坐标轴 (X轴与Y轴的粗线)
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = axisColor;
    ctx.beginPath();
    // X轴
    if (originY >= 0 && originY <= height) {
      ctx.moveTo(0, originY);
      ctx.lineTo(width, originY);
    }
    // Y轴
    if (originX >= 0 && originX <= width) {
      ctx.moveTo(originX, 0);
      ctx.lineTo(originX, height);
    }
    ctx.stroke();

    // 5. 绘制坐标刻度数字
    ctx.font = '36px sans-serif';
    ctx.fillStyle = textColor;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';

    let toFixedNum = step < 1 ? Math.abs(Math.floor(Math.log10(step))) : 0;

    // X轴数字
    for (let x = startX; x <= xMax; x += step) {
      if (Math.abs(x) < step / 2) continue; // 跳过原点 0
      let px = originX + x * this.viewScale;
      let textY = (originY >= 0 && originY <= height) ? originY + 5 : 5;
      if (originY > height - 20) textY = height - 25;

      ctx.fillText(Number(x.toFixed(toFixedNum)).toString(), px, textY);
    }

    // Y轴数字
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    for (let y = startY; y <= yMax; y += step) {
      if (Math.abs(y) < step / 2) continue;
      let py = originY - y * this.viewScale;
      let textX = (originX >= 0 && originX <= width) ? originX - 8 : width - 8;
      if (originX < 30) textX = 35;

      ctx.fillText(Number(y.toFixed(toFixedNum)).toString(), textX, py);
    }

    // 原点 0
    if (originX >= -20 && originX <= width + 20 && originY >= -20 && originY <= height + 20) {
      ctx.textAlign = 'right';
      ctx.textBaseline = 'top';
      ctx.fillText('0', originX - 8, originY + 8);
    }
  }

  // ---------- 手势事件处理 ----------
  private handlePanUpdate(event: GestureEvent) {
    // 拖拽过程，只叠加增量
    this.offsetX = this.lastOffsetX + event.offsetX;
    this.offsetY = this.lastOffsetY + event.offsetY;
  }

  private handlePanEnd() {
    // 拖拽结束，固化当前偏移量
    this.lastOffsetX = this.offsetX;
    this.lastOffsetY = this.offsetY;
  }

  private handlePinchUpdate(event: GestureEvent) {
    // 以双指中心为缩放锚点，这需要结合偏移量计算，这里先提供简易的中心缩放
    let newScale = this.lastViewScale * event.scale;
    // 限制极限缩放倍率，防止数值溢出
    if (newScale < 0.00001) newScale = 0.00001;
    if (newScale > 10000000) newScale = 10000000;

    this.viewScale = newScale;
  }

  private handlePinchEnd() {
    this.lastViewScale = this.viewScale;
  }

  // ---------- 键盘事件处理 ----------
  onShiftChange() {
    getContext(this).eventHub.emit('event_shift_change', this.isShift);
  }

  private handleButtonClick(btn: string | Resource) {
    let action = getLocalActionId(btn);
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
    getContext(this).eventHub.emit('screen_handle_action', action, this.isShift);
  }

  private handleButtonLongPress(actionCode: string) {
    getContext(this).eventHub.emit('screen_handle_action', actionCode, this.isShift);
  }

  // ---------- 编辑面板抽屉构建器 ----------
  @Builder
  EditPanelBuilder() {
    Column() {
      // 顶部指示区
      Row() {
        Text("编辑函数图像 (y₁)")
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Button("绘制")
          .type(ButtonType.Capsule)
          .backgroundColor($r('sys.color.brand'))
          .height(28)
          .onClick(() => {
            // 点击绘制时主动收起抽屉，后续在这里获取 AST
            this.isEditSheetShow = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      // 公式编辑区
      FormulaScreen({ moduleType: 'graphing' })
        .layoutWeight(1)
        .width('100%')

      // 键盘区域
      Column() {
        // 顶部高级键盘
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
        .rowsTemplate('33fr 40fr 40fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(6).columnsGap(4).padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false).width('100%').height(200)

        // 底部基础键盘
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
        .rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8).columnsGap(6).padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false).width('100%').height(250)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .padding({ bottom: this.navBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  // ---------- 主界面构建 ----------
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 底层：全屏画布（坐标系渲染区域）
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.canvasWidth = newValue.width as number;
          this.canvasHeight = newValue.height as number;
          this.requestDraw();
        })
        .onReady(() => {
          this.requestDraw();
        })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PanGesture()
              .onActionUpdate((event: GestureEvent) => this.handlePanUpdate(event))
              .onActionEnd(() => this.handlePanEnd()),
            PinchGesture()
              .onActionUpdate((event: GestureEvent) => this.handlePinchUpdate(event))
              .onActionEnd(() => this.handlePinchEnd())
          )
        )

      // 2. 顶层：图例列表（悬浮在左上角）
      Column({ space: 10 }) {
        Row() {
          Text("y₁ = ")
            .fontSize(20)
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
          Text("waiting for input...")
            .fontSize(20)
            .fontColor($r('sys.color.font_secondary'))
            .fontStyle(FontStyle.Italic)
        }
        .padding({ top: 8, bottom: 8, left: 12, right: 12 })
        .backgroundColor(Color.Transparent)
        .borderRadius(12)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 12 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
      }
      // top 留出 90 的距离以避开状态栏和 TopBar
      .margin({ top: 80, left: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.isEditSheetShow, this.EditPanelBuilder(), {
      height: '95%',
      dragBar: true,
      backgroundColor: $r('sys.color.comp_background_tertiary'),
      onDisappear: () => {
        // 面板彻底消失时的回调（这里可触发 AST 的解析与画布重新连线绘制）
      }
    })
  }
}