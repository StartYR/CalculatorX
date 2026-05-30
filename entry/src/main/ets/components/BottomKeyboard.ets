// entry/src/main/ets/components/BottomKeyboard.ets
import { bottomButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';

@Component
export struct BottomKeyboard {
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Grid() {
      ForEach(bottomButtons, (btn: string) => {
        GridItem() {
          Button(btn)
            .fontFamily(getFontFamily(btn))
            .type(ButtonType.Normal)
            .borderRadius(16)
            .width('100%')
            .height('100%')
            .padding({ left: 4, right: 4 })
            .fontSize(getFontSize(btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getFontColor(btn))
            .backgroundColor(getBgColor(btn, false)) // 底部不需要 shift 状态影响背景色
            .onClick(() => {
              this.onKeyPress(btn);
            })
        }
      })
    }
    .rowsTemplate('1fr 1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
    .rowsGap(12)
    .columnsGap(8)
    .padding({ left: 10, right: 10, top: 6, bottom: 0 })
    .width('100%')
    .height('45%')
  }
}