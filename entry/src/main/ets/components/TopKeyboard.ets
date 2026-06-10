// entry/src/main/ets/components/TopKeyboard.ets
import { topButtons, topShiftButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs, CombinationOptions, PermutationOptions } from '../utils/CalculatorConfigs';
import { keyContextMenuRegistry, CustomMenuItem } from '../utils/CalculatorConfigs';
import { vibrator } from '@kit.SensorServiceKit'; // 新增：引入系统级震动马达

@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;

  // 读取全局震动配置
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  // 手动控制菜单的弹出状态
  @State isMenuShow: boolean = false;

  // 光标长按定时器
  private startDelayTimer: number = -1;
  private repeatMoveTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  MenuBuilder() {
    Menu() {
      ForEach(keyContextMenuRegistry[this.btn as string] || [], (item: CustomMenuItem) => {
        MenuItem({ content: item.value })
          .onClick(() => {
            this.isMenuShow = false; // 点击后立刻收起弹窗，状态归位
            this.onMenuSelect(item.actionCode);
          })
      })
    }
  }

  build() {
    Column() {
      if (this.btnIndex >= 6) {
        Row() {
          if (typeof topShiftButtons[this.btnIndex] === 'string') {
            Text(topShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(topShiftButtons[this.btnIndex]))
              .fontSize(15)
              .fontColor('#ffac8100')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            Image(topShiftButtons[this.btnIndex] as Resource)
              .width(24)
              .height(24)
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

      Button() {
        if (this.btn === 'nCr') {
          Image(CombinationOptions[this.combSelect].icon).width('100%').height(36).objectFit(ImageFit.Contain).fillColor($r('sys.color.font_secondary'))
        } else if (this.btn === 'nPr') {
          Image(PermutationOptions[this.permSelect].icon).width('100%').height(36).objectFit(ImageFit.Contain).fillColor($r('sys.color.font_secondary'))
        } else if (typeof this.btn === 'string') {
          Text(this.btn).fontFamily(getFontFamily(this.btn)).fontSize(getFontSize(this.btn)).fontWeight(FontWeight.Medium).fontColor(getFontColor(this.btn))
        } else {
          Image(this.btn).width(36).height(36).fillColor($r('sys.color.font_secondary'))
        }
      }
      .type(ButtonType.Normal)
      .borderRadius(12)
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 2, right: 2, top: 0, bottom: 0 })
      .backgroundColor(getBgColor(this.btn, this.isShift))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
      .borderColor($r('app.color.btn_highlight'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .stateStyles({
        pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
        normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
      })
      .onClick(() => {
        if (this.btn === '⇧Shift') {
          this.isShift = !this.isShift;
          return;
        }
        if (this.isShift && topShiftButtons[this.btnIndex] !== '') {
          this.onKeyPress(topShiftButtons[this.btnIndex]);
          this.isShift = false;
        } else {
          this.onKeyPress(this.btn);
        }
      })

      .onTouch((event: TouchEvent) => {
        if (this.btn === '⇦' || this.btn === '⇨') {
          if (event.type === TouchType.Down) {
            // 清理可能存在的残留定时器
            clearTimeout(this.startDelayTimer);
            clearInterval(this.repeatMoveTimer);

            // 长按判定：500ms
            this.startDelayTimer = setTimeout(() => {
              this.repeatMoveTimer = setInterval(() => {
                this.onKeyPress(this.btn as string);
              }, 80); // 80毫秒
            }, 500);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            // 手指抬起或滑走瞬间停下
            clearTimeout(this.startDelayTimer);
            clearInterval(this.repeatMoveTimer);
          }
        }
      })

      // —— 程序化状态控制与极速长按手势 ——
      .bindContextMenu(this.isMenuShow, this.MenuBuilder, {
        onDisappear: () => {
          this.isMenuShow = false; // 监听点击空白处关闭的事件，防止状态不同步
        }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 300 })
          .onAction(() => {
            if (typeof this.btn === 'string' && keyContextMenuRegistry[this.btn]) {
              // 1. 触发像点按一样干脆的马达震动 (sharp)
              if (this.hapticFeedback) {
                vibrator.startVibration({
                  type: 'preset',
                  effectId: 'haptic.effect.sharp',
                  count: 1
                }, { usage: 'touch' }).catch(() => {});
              }
              // 2. 展开毛玻璃菜单
              this.isMenuShow = true;
            }
          })
      )
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct TopKeyboard {
  @Link isShift: boolean;
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    Grid() {
      ForEach(topButtons, (btn: string | Resource, index: number) => {
        GridItem() {
          TopKeyItem({
            btn: btn,
            btnIndex: index,
            isShift: $isShift,
            onKeyPress: this.onKeyPress,
            onMenuSelect: this.onMenuSelect
          })
        }
      })
    }
    .rowsTemplate('8fr 10fr 10fr 10fr 10fr')
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
    .rowsGap(4)
    .columnsGap(5)
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .clip(false)
    .width('100%')
    .height('55%')
  }
}