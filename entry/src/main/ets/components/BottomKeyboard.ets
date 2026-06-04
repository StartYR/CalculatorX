// entry/src/main/ets/components/BottomKeyboard.ets
import { bottomButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';

@Component
export struct BottomKeyboard {
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Grid() {
      ForEach(bottomButtons, (btn: string | Resource) => {
        GridItem() {
          Button() {
            if (typeof btn === 'string') {
              // 如果是文本，走 Text 渲染
              Text(btn)
                .fontFamily(getFontFamily(btn))
                .fontSize(getFontSize(btn))
                .fontWeight(FontWeight.Medium)
                .fontColor(getFontColor(btn))
            } else {
              Image(btn)
                .width(48)
                .height(40)
                .fillColor(getFontColor(btn))
            }
          }
          .type(ButtonType.Normal)
          .borderRadius(16)
          .width('100%')
          .height('100%')
          .padding({ left: 4, right: 4 })
          .backgroundColor(getBgColor(btn, false))

          // 系统级外阴影，让按键整体“浮”在面板上
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)

          // 模拟物理按键的顶部高光（左上受光面）
          // 通过给左边和上边加 1px 的半透明白色边框，产生 3D 倒角凸起感
          .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
          .borderColor($r('app.color.btn_highlight'))

          // 动态按压效果
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .stateStyles({
            pressed: {
              // 按下时不仅降低透明度，还可以把阴影去掉，模拟“按到底了”的物理真实感
              .opacity(0.7)
              .shadow(ShadowStyle.OUTER_DEFAULT_XS) // 阴影变小
            },
            normal: {
              .opacity(1.0)
              .shadow(ShadowStyle.OUTER_DEFAULT_SM) // 阴影恢复
            }
          })
          .onClick(() => {
            this.onKeyPress(btn as string); // 加上 as string 防止类型报警，因为你的 onKeyPress 可能只认字符串
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