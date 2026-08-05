/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCanvas.ets
 * @description 图形计算器画布组件：负责坐标系渲染、引擎对接与手势交互
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

import mediaquery from '@ohos.mediaquery';
import { EngineService, CalcConfig } from '../../utils/EngineService';
import { GraphFunctionItem } from './GraphingTypes';
import Logger  from '../../utils/Logger';

@Component
export struct GraphingCanvas {
  @Link functionList: GraphFunctionItem[];

  private isRenderPending: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  @State viewScale: number = 80;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @StorageProp('colorModeIndex')
  colorModeIndex: number = 2;
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
    this.requestDraw(); // 触发画布重绘
  }

  private onDarkModeChange = (mediaQueryResult: mediaquery.MediaQueryResult) => {
    if (this.colorModeIndex === 2) {
      this.isDarkModeUI = mediaQueryResult.matches;
      this.requestDraw();
    }
  }

  // 独立的事件监听器，避免影响父组件的注销逻辑
  private onAstReady = () => {
    this.requestDraw();
  }

  aboutToAppear() {
    this.darkMediaQuery.on('change', this.onDarkModeChange);
    this.onColorModeChange();

    // 监听 AST 准备就绪事件，触发重绘
    getContext(this).eventHub.on('temp_graph_ast_ready', this.onAstReady);
  }

  aboutToDisappear() {
    this.darkMediaQuery.off('change', this.onDarkModeChange);
    getContext(this).eventHub.off('temp_graph_ast_ready', this.onAstReady);
  }

  private requestDraw() {
    if (this.canvasWidth === 0 || this.canvasHeight === 0) return;

    // 核心节流逻辑：如果当前帧已经有一个绘制任务在排队了，直接丢弃后续冗余请求
    if (this.isRenderPending) {
      return;
    }

    this.isRenderPending = true;

    // 向系统申请在下一次屏幕物理刷新时（约 16ms 后）统一执行一次绘制
    setTimeout(() => {
      this.drawCoordinateSystem();  // 绘图逻辑
      this.isRenderPending = false; // 画完后解锁，准备接收下一帧的请求
    });
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

      // 打包大 JSON，把类型和伴生表达式全传给 C++
      let payload = JSON.stringify({
        type: funcItem.type || 0,
        ast: funcItem.ast || "0",
        ast2: funcItem.ast2 || "0",
        tMin: funcItem.tMin !== undefined ? funcItem.tMin : -10.0,
        tMax: funcItem.tMax !== undefined ? funcItem.tMax : 10.0,
        yMin: yMin,
        yMax: yMax
      });

      // 传入 payload
      let points = EngineService.calculateGraphPoints(payload, config) as Float64Array;
      if (!points || points.length === 0) continue;

      ctx.beginPath();

      // 拦截独立点 (只有 2 个坐标)，直接画一个实心小圆点
      if (points.length === 2) {
        let mathX = points[0];
        let mathY = points[1];
        if (Number.isFinite(mathX) && Number.isFinite(mathY)) {
          let px = originX + mathX * this.viewScale;
          let py = originY - mathY * this.viewScale;
          ctx.fillStyle = funcItem.color;
          ctx.arc(px, py, 6, 0, 2 * Math.PI); // 画一个半径为 6 的圆
          ctx.fill();
        }
        continue; // 画完点直接进入下一个函数的渲染
      }

      // --- 连线渲染逻辑 ---
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = funcItem.color;

      let isFirstPoint = true;

      for (let p = 0; p < points.length; p += 2) {
        let mathX = points[p];
        let mathY = points[p + 1];

        // 如果底层传来了 NaN，说明这里是断崖/奇点，切断连线
        if (!Number.isFinite(mathY) || !Number.isFinite(mathX)) {
          isFirstPoint = true;
          continue;
        }

        // 使用底层的 mathX 和 mathY 映射物理像素
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

  // ==================== 手势交互状态 (纯增量架构) ====================
  // 彻底抛弃 lastOffsetX/Y 和 lastViewScale
  private panPrevX: number = 0;
  private panPrevY: number = 0;
  private pinchPrevScale: number = 1;

  // 核心避震器标志
  private justEndedPinch: boolean = false;

  // ==================== 手势交互处理 ====================

  // --- 拖拽处理 (Pan) ---
  private handlePanStart(event: GestureEvent) {
    this.panPrevX = event.offsetX;
    this.panPrevY = event.offsetY;
    this.justEndedPinch = false;
  }

  private handlePanUpdate(event: GestureEvent) {
    // 吸收单指抬起时的“重心跳跃”
    if (this.justEndedPinch) {
      // 只重置基准点，不移动画面，吸收跳跃
      this.panPrevX = event.offsetX;
      this.panPrevY = event.offsetY;
      this.justEndedPinch = false;
      return;
    }

    // 1. 计算这一帧的微小增量
    let deltaX = event.offsetX - this.panPrevX;
    let deltaY = event.offsetY - this.panPrevY;

    // 2. 直接累加到当前偏移量上
    this.offsetX += deltaX;
    this.offsetY += deltaY;

    // 3. 更新上一帧的状态
    this.panPrevX = event.offsetX;
    this.panPrevY = event.offsetY;

    this.requestDraw();
  }

  private handlePanEnd() {}

  // --- 缩放处理 (Pinch) ---
  private handlePinchStart(event: GestureEvent) {
    this.pinchPrevScale = 1; // 每次缩放开始，scale 的基准都是 1
  }

  private handlePinchUpdate(event: GestureEvent) {
    // 1. 计算这一帧的缩放微小比例 (增量倍数)
    let ratio = event.scale / this.pinchPrevScale;

    // 2. 预计算新 Scale 并应用极值限制
    let newScale = this.viewScale * ratio;
    if (newScale < 0.00001) {
      newScale = 0.00001;
      ratio = newScale / this.viewScale; // 如果触底，修正真实的 ratio
    }
    if (newScale > 10000000) {
      newScale = 10000000;
      ratio = newScale / this.viewScale; // 如果触顶，修正真实的 ratio
    }

    // 3. 几何补偿：把画面拉回手指下方
    let cx = event.pinchCenterX;
    let cy = event.pinchCenterY;
    let dx = cx - this.canvasWidth / 2;
    let dy = cy - this.canvasHeight / 2;

    this.offsetX = dx - (dx - this.offsetX) * ratio;
    this.offsetY = dy - (dy - this.offsetY) * ratio;

    // 4. 更新状态
    this.viewScale = newScale;
    this.pinchPrevScale = event.scale;

    this.requestDraw();
  }

  private handlePinchEnd() {
    // 通知 PanGesture 开启避震，拦截重心跳跃
    this.justEndedPinch = true;
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
            PanGesture()
              .onActionStart((event: GestureEvent) => this.handlePanStart(event))
              .onActionUpdate((event: GestureEvent) => this.handlePanUpdate(event))
              .onActionEnd(() => this.handlePanEnd()),
            PinchGesture()
              .onActionStart((event: GestureEvent) => this.handlePinchStart(event))
              .onActionUpdate((event: GestureEvent) => this.handlePinchUpdate(event))
              .onActionEnd(() => this.handlePinchEnd())
          )
        )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}