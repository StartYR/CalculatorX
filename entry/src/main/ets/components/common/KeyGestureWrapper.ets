/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file KeyGestureWrapper.ets
 * @description 全能按键基类：统管连续触发、原生菜单、滑动气泡与直出 Shift 等复杂手势状态机
 * @author 易睿 (Yi Rui)
 * @date 2026/7/28 20:26
 */

import { display } from '@kit.ArkUI'; // 用于获取屏幕宽度
import { HapticUtils } from '../../utils/HapticUtils';
import { icon_power2, icon_sqrtx, icon_sqrt3 } from '../../utils/CalculatorConfigs';

export type LongPressStrategy = 'CONTINUOUS' | 'NATIVE_MENU' | 'SLIDE_BUBBLE' | 'DIRECT_SHIFT' | 'NONE';

export interface MenuItem {
  value: string | Resource;
  actionCode: string;
}

// ================= 内部长按逻辑配置字典 =================
const CONTINUOUS_KEYS = ['⌫', '⇦', '⇨'];

const BUBBLE_REGISTRY: Record<string, MenuItem[]> = {
  'sin': [
    { value: 'csc', actionCode: 'csc' },
    { value: 'csc⁻¹', actionCode: 'csc⁻¹' },
    { value: 'sinh', actionCode: 'sinh' },
    { value: 'sinh⁻¹', actionCode: 'sinh⁻¹' }
  ],
  'cos': [
    { value: 'sec', actionCode: 'sec' },
    { value: 'sec⁻¹', actionCode: 'sec⁻¹' },
    { value: 'cosh', actionCode: 'cosh' },
    { value: 'cosh⁻¹', actionCode: 'cosh⁻¹' }
  ],
  'tan': [
    { value: 'cot', actionCode: 'cot' },
    { value: 'cot⁻¹', actionCode: 'cot⁻¹' },
    { value: 'tanh', actionCode: 'tanh' },
    { value: 'tanh⁻¹', actionCode: 'tanh⁻¹' }
  ],
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
  ],
  'sqrt': [
    { value: icon_sqrt3, actionCode: 'sqrt3' },
    { value: icon_sqrtx, actionCode: 'sqrtx' }
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
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;

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
  @State private bubbleOffsetX: number = 0; // 记录触碰边缘时的 X 轴平移补偿量
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
            // 使用 Stack 统一包裹背景，内部按类型渲染
            Stack() {
              if (typeof item.value === 'string') {
                // 如果是文本，渲染 Text
                Text(item.value)
                  .fontSize(15)
                  .fontWeight(this.activeBubbleIndex === index ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.activeBubbleIndex === index ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
              } else {
                // 如果是 SVG 资源，渲染 Image
                Image(item.value)
                  .width(24) // 图标稍微调小一点，防止撑满边框
                  .height(24)
                  .fillColor(this.activeBubbleIndex === index ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                  .draggable(false) // 顺手禁掉气泡内图标的系统原生拖拽！
              }
            }
            .width(52) // 统一选项宽度
            .height(40) // 统一选项高度
            .backgroundColor(this.activeBubbleIndex === index ? $r('sys.color.comp_background_emphasize') : 'transparent')
            .borderRadius(12)
            .animation({ duration: 150, curve: Curve.EaseInOut })
          })
        }
        .width(BUBBLE_REGISTRY[this.actionId].length * 52 + 4) // 宽度计算：选项数 * 52(单选项宽) + 8(左右各4的padding)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius(14)
        .padding(2)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .offset({ x: this.bubbleOffsetX, y: -55 })
        .zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
    // 动态获取按键宽度，作为滑动坐标换算的基准
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.btnWidth = newValue.width as number;

      // 气泡边缘碰撞检测
      if (BUBBLE_REGISTRY[this.actionId]) {
        let globalX = newValue.globalPosition.x as number; // 按钮在屏幕上的绝对 X 坐标
        let bubbleWidth = BUBBLE_REGISTRY[this.actionId].length * 52 + 8;
        let btnCenterX = globalX + (this.btnWidth / 2); // 按钮的中心点绝对坐标

        let bubbleLeft = btnCenterX - (bubbleWidth / 2); // 气泡理论上的左边缘坐标
        let bubbleRight = btnCenterX + (bubbleWidth / 2); // 气泡理论上的右边缘坐标

        try {
          // 获取当前屏幕的宽度 (将像素 px 转换为 vp)
          let screenWidth = px2vp(display.getDefaultDisplaySync().width);
          let edgeMargin = 12; // 留出 12vp 的安全边距，避免气泡死死贴着屏幕边缘

          if (bubbleLeft < edgeMargin) {
            // 如果左边溢出了，强制往右推
            this.bubbleOffsetX = edgeMargin - bubbleLeft;
          } else if (bubbleRight > screenWidth - edgeMargin) {
            // 如果右边溢出了，强制往左推
            this.bubbleOffsetX = (screenWidth - edgeMargin) - bubbleRight;
          } else {
            // 如果很安全，无需平移
            this.bubbleOffsetX = 0;
          }
        } catch (e) {
          this.bubbleOffsetX = 0;
        }
      }
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

          HapticUtils.playVibration(this.actionId, this.hapticFeedback, this.vibrationCurve);

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
          let startX = (this.btnWidth / 2) - (bubbleWidth / 2) + this.bubbleOffsetX;

          // 碰撞检测：只有当手指移动到按键上方区域 (y < -5) 时，才触发选项高亮

          let relativeX = touchX - startX;
          let hoverIndex = Math.floor(relativeX / itemWidth);

          // 边缘吸附：如果手指滑到了最左侧外面，强制锁定为第 0 个选项
          if (hoverIndex < 0) {
            hoverIndex = 0;
          }
          // 如果手指滑到了最右侧外面，强制锁定为最后一个选项
          else if (hoverIndex >= itemCount) {
            hoverIndex = itemCount - 1;
          }

          // 只要索引发生变化（跨越了选项边界），就更新高亮并触发震动
          if (this.lastHoverIndex !== hoverIndex) {
            this.activeBubbleIndex = hoverIndex;
            this.lastHoverIndex = hoverIndex;

            HapticUtils.playVibration('slide_tick', this.hapticFeedback, this.vibrationCurve);
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