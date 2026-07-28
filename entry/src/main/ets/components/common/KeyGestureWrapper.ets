/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file KeyGestureWrapper.ets
 * @description 全能按键基类：统管连续触发、原生菜单、滑动气泡与直出 Shift 等复杂手势状态机
 * @author 易睿 (Yi Rui)
 * @date 2026/7/28 20:26
 */

import { vibrator } from '@kit.SensorServiceKit';

// ================= 全局长按策略枚举 =================
export type LongPressStrategy = 'CONTINUOUS' | 'NATIVE_MENU' | 'SLIDE_BUBBLE' | 'DIRECT_SHIFT' | 'NONE';

export interface MenuItem {
  value: string;
  actionCode: string;
}

// ================= 内部长按逻辑配置字典 =================
// 1. 连续触发名单 (80ms 连发)
const CONTINUOUS_KEYS = ['⌫', '⇦', '⇨'];

// 2. 悬浮气泡菜单字典 (支持滑动选择)
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

// 3. 原生系统菜单字典
const NATIVE_MENU_REGISTRY: Record<string, MenuItem[]> = {
  'Ans': [{ value: '清除历史记录', actionCode: 'CLEAR_HISTORY' }]
};

// ================= 纯逻辑组件 =================
@Component
export struct KeyGestureWrapper {
  // --- 核心纯逻辑参数 ---
  actionId: string = '';             // 当前按键的唯一标识符
  targetBtn: string | Resource = ''; // 原始按键值，用于短按发射
  shiftBtn: string | Resource = '';  // 对应的 Shift 态按键，用于触发 DIRECT_SHIFT
  moduleType: string = 'standard';   // 当前所处的计算模式
  @Link isShiftMode: boolean;        // 面板当前的 Shift 状态
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // --- UI 由外部完全接管 ---
  @BuilderParam customUI: () => void;

  // --- 回调 ---
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  // --- 内部状态机变量 ---
  @State private isNativeMenuShow: boolean = false;
  private startDelayTimer: number = -1;
  private repeatMoveTimer: number = -1;

  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private isBubbleTriggered: boolean = false;
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
    // 作为一个透明的容器，包裹外部传入的 UI，接管触摸事件
    Stack() {
      this.customUI()
    }
    .width('100%')
    .height('100%')
    .bindContextMenu(this.isNativeMenuShow, this.NativeMenuBuilder, {
      onDisappear: () => { this.isNativeMenuShow = false; }
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.touchStartX = event.touches[0].windowX;
        this.touchStartY = event.touches[0].windowY;
        this.isBubbleTriggered = false;
        this.currentStrategy = this.resolveStrategy();

        clearTimeout(this.startDelayTimer);
        clearInterval(this.repeatMoveTimer);

        this.startDelayTimer = setTimeout(() => {
          if (this.currentStrategy === 'NONE') return;

          if (this.hapticFeedback) {
            vibrator.startVibration({
              type: 'preset',
              effectId: 'haptic.effect.sharp',
              count: 1
            }, { usage: 'touch' }).catch(() => {});
          }

          switch (this.currentStrategy) {
            case 'CONTINUOUS':
              this.repeatMoveTimer = setInterval(() => { this.onKeyPress(this.targetBtn); }, 80);
              break;
            case 'NATIVE_MENU':
              this.isNativeMenuShow = true;
              break;
            case 'SLIDE_BUBBLE':
              this.isBubbleTriggered = true;
              let bubbleOptions = BUBBLE_REGISTRY[this.actionId];
              getContext(this).eventHub.emit('open_global_bubble', bubbleOptions, this.touchStartX, this.touchStartY);
              break;
            case 'DIRECT_SHIFT':
              this.onKeyPress(this.shiftBtn);
              this.isBubbleTriggered = true;
              break;
          }
        }, 300);

      } else if (event.type === TouchType.Move) {
        if (this.currentStrategy === 'SLIDE_BUBBLE' && this.isBubbleTriggered) {
          let currentX = event.touches[0].windowX;
          let currentY = event.touches[0].windowY;
          getContext(this).eventHub.emit('update_bubble_hover', currentX, currentY);
        }

      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        clearTimeout(this.startDelayTimer);
        clearInterval(this.repeatMoveTimer);

        if (this.currentStrategy === 'SLIDE_BUBBLE' && this.isBubbleTriggered) {
          getContext(this).eventHub.emit('close_and_resolve_bubble', (selectedActionCode: string) => {
            if (selectedActionCode) {
              this.onMenuSelect(selectedActionCode);
            }
          });
          this.isBubbleTriggered = false;
        }
        else if (this.currentStrategy === 'DIRECT_SHIFT' && this.isBubbleTriggered) {
          this.isBubbleTriggered = false;
        }
        else if (!this.isNativeMenuShow) {
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