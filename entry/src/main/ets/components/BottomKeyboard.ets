// entry/src/main/ets/components/BottomKeyboard.ets
import { bottomButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { keyContextMenuRegistry, CustomMenuItem, PreferenceConfigs } from '../utils/CalculatorConfigs';
import { vibrator } from '@kit.SensorServiceKit'; // 新增

@Component
struct BottomKeyItem {
  btn: string | Resource = '';
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  @State isMenuShow: boolean = false;

  private startDelayTimer: number = -1;
  private repeatDeleteTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};
  onContinuousDelete: () => void = () => {};

  @Builder
  MenuBuilder() {
    Menu() {
      ForEach(keyContextMenuRegistry[this.btn as string] || [], (item: CustomMenuItem) => {
        MenuItem({ content: item.value })
          .onClick(() => {

            this.isMenuShow = false;
            this.onMenuSelect(item.actionCode);
          })
      })
    }
  }

  build() {
    Button() {
      if (typeof this.btn === 'string') {
        Text(this.btn)
          .fontFamily(getFontFamily(this.btn))
          .fontSize(getFontSize(this.btn))
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
    .borderRadius(16)
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
    .backgroundColor(getBgColor(this.btn, false))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .stateStyles({
      pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(() => {
        this.onKeyPress(this.btn as string);
    })
    // 为退格键独家定制的连删触摸回路
    .onTouch((event: TouchEvent) => {
      if (this.btn === '⌫') {
        if (event.type === TouchType.Down) {
          // 清理可能存在的残留定时器
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);

          // 开启长按判定：500ms 后启动疯狂连发模式
          this.startDelayTimer = setTimeout(() => {
            this.repeatDeleteTimer = setInterval(() => {
              this.onKeyPress(this.btn as string);
            }, 80); // 80毫秒删一个
          }, 500);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          // 手指抬起或滑走：瞬间切断机枪！
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);
        }
      }
    })

    .bindContextMenu(this.isMenuShow, this.MenuBuilder, {
      onDisappear: () => {
        this.isMenuShow = false;
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          if (typeof this.btn === 'string' && keyContextMenuRegistry[this.btn]) {
            if (this.hapticFeedback) {
              vibrator.startVibration({
                type: 'preset',
                effectId: 'haptic.effect.sharp',
                count: 1
              }, { usage: 'touch' }).catch(() => {});
            }
            this.isMenuShow = true;
          }
        })
    )
  }
}

@Component
export struct BottomKeyboard {
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};
  onContinuousDelete: () => void = () => {};

  build() {
    Grid() {
      ForEach(bottomButtons, (btn: string | Resource) => {
        GridItem() {
          BottomKeyItem({
            btn: btn,
            onKeyPress: this.onKeyPress,
            onMenuSelect: this.onMenuSelect,
            onContinuousDelete: this.onContinuousDelete
          })
        }
      })
    }
    .rowsTemplate('1fr 1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
    .rowsGap(12)
    .columnsGap(8)
    .padding({ left: 10, right: 10, top: 6, bottom: 0 })
    .clip(false)
    .width('100%')
    .height('45%')
  }
}