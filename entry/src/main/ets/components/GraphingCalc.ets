/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file GraphingCalc.ets
 * @description 请在此处输入文件描述...
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:51
 */
/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingCalc.ets
 * @description 函数图像模块 - 原生 Canvas 自适应坐标系与手势引擎
 * @author 易睿 (Yi Rui)
 * @date 2026
 */

@Component
export struct GraphingCalc {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 画布的物理尺寸
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 0;

  // 核心视图状态（触发 @Watch 进行极低开销的路径重绘，绝不重新实例化 Canvas 组件）
  @State @Watch('requestDraw') viewScale: number = 80;    // 缩放比例（1个单位刻度占用多少物理像素）
  @State @Watch('requestDraw') offsetX: number = 0;   // 坐标原点相对屏幕中心的 X 偏移量
  @State @Watch('requestDraw') offsetY: number = 0;   // 坐标原点相对屏幕中心的 Y 偏移量

  // 手势过程中的临时状态，用于增量计算
  private lastOffsetX: number = 0;
  private lastOffsetY: number = 0;
  private lastViewScale: number = 80;

  // 底部编辑抽屉的控制开关
  @State isEditSheetShow: boolean = false;

  aboutToAppear() {
    getContext(this).eventHub.on('open_graphing_edit_sheet', () => {
      this.isEditSheetShow = true;
    });
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('open_graphing_edit_sheet');
  }

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

    // 1. 清空画布，准备重绘
    ctx.clearRect(0, 0, width, height);

    // 计算物理原点位置 (画布中心 + 偏移量)
    let originX = width / 2 + this.offsetX;
    let originY = height / 2 + this.offsetY;

    // 2. 动态网格步长算法（根据当前的 scale，计算出最舒适的 1, 2, 5, 0.1, 0.5 序列）
    // 假设相邻两个刻度的最小像素距离为 60
    let minSpacingPx = 70;
    let rawStep = minSpacingPx / this.viewScale;
    let magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
    let residual = rawStep / magnitude;

    let step = magnitude;
    if (residual > 5) step = 10 * magnitude;
    else if (residual > 2) step = 5 * magnitude;
    else if (residual > 1) step = 2 * magnitude;

    // 3. 绘制次级网格线 (浅灰色)
    ctx.lineWidth = 1;
    ctx.strokeStyle = '#E0E0E0'; // 适配深浅色模式的话，后续可通过主题变量切换
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
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#333333';
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
    ctx.font = '48px sans-serif';
    ctx.fillStyle = '#666666';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';

    let toFixedNum = step < 1 ? Math.abs(Math.floor(Math.log10(step))) : 0;

    // X轴数字
    for (let x = startX; x <= xMax; x += step) {
      if (Math.abs(x) < step / 2) continue; // 跳过原点 0
      let px = originX + x * this.viewScale;
      let textY = (originY >= 0 && originY <= height) ? originY + 5 : 5;
      // 保持数字始终在可见区域内（贴边吸附效果可以后续加强）
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
  }

  // ============== 手势事件处理器 ==============

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

    // 简易处理：补偿由于缩放导致的中心偏移 (若要实现完美的指尖跟随缩放，需要结合 event.pinchCenterX)
    this.viewScale = newScale;
  }

  private handlePinchEnd() {
    this.lastViewScale = this.viewScale;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 底层：全屏画布
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

      // 2. 顶层：图例列表 (悬浮在左上角)
      Column({ space: 10 }) {
        Row() {
          Text("y₁ = ")
            .fontSize(20).fontColor(Color.Black).fontWeight(FontWeight.Medium)
          Text("waiting for input...")
            .fontSize(20).fontColor(Color.Gray).fontStyle(FontStyle.Italic)
        }
        .padding(10).backgroundColor('#AAFFFFFF').borderRadius(8)
        .shadow({ radius: 4, color: '#33000000', offsetY: 2 })

        // （此处的编辑按钮已移除）
      }
      // top 留出 90 的距离以避开状态栏和 TopBar
      .margin({ top: 90, left: 20 })

      // 3. TODO: 绑定 Sheet 用于弹出原有的 FormulaScreen 键盘
      // .bindSheet($$this.isEditSheetShow, this.EditPanelBuilder(), { ... })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5') // 护眼背景
  }
}