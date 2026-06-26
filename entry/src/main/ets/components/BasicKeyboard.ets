/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file BasicKeyboard.ets
 * @description 基础计算器键盘组件，5x4 经典大按键
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 02:28
 */

import { basicButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';

@Component
struct BasicKeyItem {
  btn: string | Resource = '';
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  // 连删定时器
  private startDelayTimer: number = -1;
  private repeatDeleteTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Button() {
      if (typeof this.btn === 'string') {
        Text(this.btn)
          .fontFamily(getFontFamily(this.btn))
          .fontSize(getFontSize(this.btn) + 2) // 基础键盘按键大，字号适当微调放大 2vp 提升视觉饱满度
          .fontWeight(FontWeight.Medium)
          .fontColor(getFontColor(this.btn))
      } else {
        Image(this.btn)
          .width(48)
          .height(40)
          .fillColor(getFontColor(this.btn))
      }
    }
    .type(ButtonType.Normal)
    .borderRadius(20) // 更大更圆润的卡片倒角，贴合基础键盘的商务/现代感
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
    .backgroundColor(getBgColor(this.btn, false))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .stateStyles({
      pressed: { .opacity(0.75).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(() => {
      this.onKeyPress(this.btn as string);
    })
    // ================== 退格键独家定制的连删触摸回路 ==================
    .onTouch((event: TouchEvent) => {
      if (this.btn === '⌫') {
        if (event.type === TouchType.Down) {
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);

          // 开启长按判定：500ms 后启动疯狂连发模式
          this.startDelayTimer = setTimeout(() => {
            this.repeatDeleteTimer = setInterval(() => {
              this.onKeyPress(this.btn as string);
            }, 80); // 80毫秒删一个
          }, 500);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          // 手指抬起或滑走：瞬间切断机枪回路
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);
        }
      }
    })
  }
}

@Component
export struct BasicKeyboard {
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Grid() {
      ForEach(basicButtons, (btn: string | Resource) => {
        GridItem() {
          BasicKeyItem({
            btn: btn,
            onKeyPress: this.onKeyPress
          })
        }
      })
    }
    .rowsTemplate('1fr 1fr 1fr 1fr 1fr') // 5行
    .columnsTemplate('1fr 1fr 1fr 1fr')   // 4列
    .rowsGap(14)    // 显式加大间距，全面优化防误触手感
    .columnsGap(12)
    .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    .clip(false)
    .width('100%')
    .height('55%') // 占据屏幕下方约 62% 的黄金高度，饱满且舒适
  }
}