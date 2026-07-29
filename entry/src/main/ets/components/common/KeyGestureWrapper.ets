/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file KeyGestureWrapper.ets
 * @description 全能按键基类：统管连续触发、原生菜单、滑动气泡与直出 Shift 等复杂手势状态机
 * @author 易睿 (Yi Rui)
 * @date 2026/7/28 20:26
 */

import { vibrator } from '@kit.SensorServiceKit';

export type LongPressStrategy = 'CONTINUOUS' | 'NATIVE_MENU' | 'SLIDE_BUBBLE' | 'DIRECT_SHIFT' | 'NONE';

export interface MenuItem {
  value: string;
  actionCode: string;
}

// ================= 内部长按逻辑配置字典 =================
const CONTINUOUS_KEYS = ['⌫', '⇦', '⇨'];

const BUBBLE_REGISTRY: Record<string, MenuItem[]> = {
  'cases': [
    { value: '3行', actionCode: 'cases_3' },
    { value: '4行', actionCode: 'cases_4' },
    { value: '5行', actionCode: 'cases_5' },
    { value: '6行', actionCode: 'cases_6' }
  ],
  'S⇄D': [
    { value: '小数', actionCode: 'LONG_SD_DEC' },
    { value: '分数', actionCode: 'LONG_SD_FRAC' },
    { value: '带分数', actionCode: 'LONG_SD_MIXED' },
    { value: '度分秒', actionCode: 'LONG_SD_DMS' }
  ]
};

const NATIVE_MENU_REGISTRY: Record<string, MenuItem[]> = {
  'Ans': [{ value: '清除历史记录', actionCode: 'CLEAR_HISTORY' }]
};

// ================= 纯手势逻辑组件 =================
@Component
export struct KeyGestureWrapper {
  // --- 核心参数 ---
  actionId: string = '';
  targetBtn: string | Resource = '';
  shiftBtn: string | Resource = '';
  moduleType: string = 'standard';
  @Link isShiftMode: boolean;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  @BuilderParam customUI: () => void;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  // --- 内部状态机变量 ---
  @State private btnWidth: number = 0; // 用于计算碰撞热区

  // 原生菜单状态
  @State private isNativeMenuShow: boolean = false;

  // 气泡菜单状态
  @State private isBubbleVisible: boolean = false;
  @State private activeBubbleIndex: number = -1; // 当前高亮的选项索引
  private lastHoverIndex: number = -1; // 用于防抖和触发切换震动

  private startDelayTimer: number = -1;
  private repeatMoveTimer: number = -1;
  private currentStrategy: LongPressStrategy = 'NONE';

  private resolveStrategy(): LongPressStrategy {
    if (CONTINUOUS_KEYS.includes(this.actionId)) return 'CONTINUOUS';
    if (BUBBLE_REGISTRY[this.actionId]) return 'SLIDE_BUBBLE';
    if (NATIVE_MENU_REGISTRY[this.actionId]) return 'NATIVE_MENU';
    if (this.shiftBtn !== '') return 'DIRECT_SHIFT';
    return 'NONE';
  }

  @Builder
  NativeMenuBuilder() {
    Menu() {
      ForEach(NATIVE_MENU_REGISTRY[this.actionId] || [], (item: MenuItem) => {
        MenuItem({ content: item.value })
          .onClick(() => {
            this.isNativeMenuShow = false;
            this.onMenuSelect(item.actionCode);
          })
      })
    }
  }

  build() {
    // 使用 Stack 作为绝对坐标系，将气泡压在自定义 UI 之上
    Stack() {
      // 1. 外部传入的原汁原味按键 UI
      this.customUI()

      // 2. 长按滑动悬浮气泡 UI
      if (this.isBubbleVisible && BUBBLE_REGISTRY[this.actionId]) {
        Row() {
          ForEach(BUBBLE_REGISTRY[this.actionId], (item: MenuItem, index: number) => {
            Text(item.value)
              .fontSize(15)
              .fontWeight(this.activeBubbleIndex === index ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeBubbleIndex === index ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
              .backgroundColor(this.activeBubbleIndex === index ? $r('sys.color.comp_background_emphasize') : 'transparent')
              .width(52) // 单个选项宽度
              .height(40)
              .textAlign(TextAlign.Center)
              .borderRadius(8)
              // 动画过渡，让高亮背景色的切换更丝滑
              .animation({ duration: 150, curve: Curve.EaseInOut })
          })
        }
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(12)
        .padding(4)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        // 关键定位：让气泡的底部中心，锚定在按键的顶部中心
        .markAnchor({ x: '50%', y: '100%' })
        .position({ x: '50%', y: -8 }) // y: -8 代表距离按键顶部还有 8vp 的悬浮间隙
        .zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
    // 动态获取按键宽度，作为滑动坐标换算的基准
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.btnWidth = newValue.width as number;
    })
    .bindContextMenu(this.isNativeMenuShow, this.NativeMenuBuilder, {
      onDisappear: () => { this.isNativeMenuShow = false; }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.currentStrategy = this.resolveStrategy();

        clearTimeout(this.startDelayTimer);
        clearInterval(this.repeatMoveTimer);

        this.startDelayTimer = setTimeout(() => {
          if (this.currentStrategy === 'NONE') return;

          if (this.hapticFeedback) {
            vibrator.startVibration({ type: 'preset', effectId: 'haptic.effect.sharp', count: 1 }, { usage: 'touch' }).catch(() => {});
          }

          switch (this.currentStrategy) {
            case 'CONTINUOUS':
              this.repeatMoveTimer = setInterval(() => { this.onKeyPress(this.targetBtn); }, 80);
              break;
            case 'NATIVE_MENU':
              this.isNativeMenuShow = true;
              break;
            case 'SLIDE_BUBBLE':
              this.isBubbleVisible = true;
              break;
            case 'DIRECT_SHIFT':
              this.onKeyPress(this.shiftBtn);
              this.isBubbleVisible = true; // 借用变量作为标记，拦截短按
              break;
          }
        }, 300);

      } else if (event.type === TouchType.Move) {
        if (this.currentStrategy === 'SLIDE_BUBBLE' && this.isBubbleVisible) {
          // 获取相对当前按键左上角的局部坐标
          let touchX = event.touches[0].x;
          let touchY = event.touches[0].y;

          let items = BUBBLE_REGISTRY[this.actionId];
          let itemCount = items.length;
          let itemWidth = 52; // 与 UI 中设定的选项宽度一致
          let bubbleWidth = itemCount * itemWidth;

          // 计算气泡最左侧选项相对于按键左侧的 X 坐标起始点
          let startX = (this.btnWidth / 2) - (bubbleWidth / 2);

          // 碰撞检测：只有当手指移动到按键上方区域 (y < -5) 时，才触发选项高亮
          if (touchY < -5) {
            let relativeX = touchX - startX;
            let hoverIndex = Math.floor(relativeX / itemWidth);

            // 限制索引在有效范围内
            if (hoverIndex >= 0 && hoverIndex < itemCount) {
              if (this.lastHoverIndex !== hoverIndex) {
                this.activeBubbleIndex = hoverIndex;
                this.lastHoverIndex = hoverIndex;
                // 跨越选项时，触发轻微震动反馈 (Tick)
                if (this.hapticFeedback) vibrator.startVibration({ type: 'preset', effectId: 'haptic.effect.tick', count: 1 }, { usage: 'touch' }).catch(() => {});
              }
            } else {
              this.activeBubbleIndex = -1;
              this.lastHoverIndex = -1;
            }
          } else {
            this.activeBubbleIndex = -1;
            this.lastHoverIndex = -1;
          }
        }

      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        clearTimeout(this.startDelayTimer);
        clearInterval(this.repeatMoveTimer);

        if (this.currentStrategy === 'SLIDE_BUBBLE' && this.isBubbleVisible) {
          // 如果手指抬起时，正好停留在某个高亮的选项上，则发射对应的 Action
          if (this.activeBubbleIndex !== -1) {
            let items = BUBBLE_REGISTRY[this.actionId];
            this.onMenuSelect(items[this.activeBubbleIndex].actionCode);
          }
          // 状态重置
          this.isBubbleVisible = false;
          this.activeBubbleIndex = -1;
          this.lastHoverIndex = -1;
        }
        else if (this.currentStrategy === 'DIRECT_SHIFT' && this.isBubbleVisible) {
          this.isBubbleVisible = false;
        }
        else if (!this.isNativeMenuShow) {
          // 常规短按逻辑
          if (this.actionId === '⇧Shift') {
            this.isShiftMode = !this.isShiftMode;
          } else if (this.isShiftMode && this.shiftBtn !== '') {
            this.onKeyPress(this.shiftBtn);
            this.isShiftMode = false;
          } else {
            this.onKeyPress(this.targetBtn);
          }
        }
      }
    })
  }
}