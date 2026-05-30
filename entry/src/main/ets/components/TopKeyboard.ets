// entry/src/main/ets/components/TopKeyboard.ets
import { topButtons, topShiftButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';

@Component
export struct TopKeyboard {
  @Link isShift: boolean;
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Grid() {
      ForEach(topButtons, (btn: string | Resource, index: number) => {
        GridItem() {
          Column() {
            // Shift 副功能文本区
            Row() {
              if (typeof topShiftButtons[index] === 'string') {
                Text(topShiftButtons[index] as string)
                  .fontFamily(getFontFamily(topShiftButtons[index]))
                  .fontSize(15)
                  .fontColor('#ff805300')
                  .textAlign(TextAlign.Center)
                  .width('100%')
              } else {
                Image(topShiftButtons[index] as Resource)
                  .width(24)
                  .height(24)
                  .fillColor('#8A94A6')
                  .objectFit(ImageFit.Contain)
              }
            }
            .width('100%')
            .height(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ bottom: 1 })

            // 主按钮
            Button() {
              if (typeof btn === 'string') {
                Text(btn)
                  .fontFamily(getFontFamily(btn))
                  .fontSize(getFontSize(btn))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getFontColor(btn))
              } else {
                Image(btn)
                  .width(36)
                  .height(36)
                  .fillColor('#4A5568')
              }
            }
            .type(ButtonType.Normal)
            .borderRadius(12)
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 2, right: 2, top: 0, bottom: 0 })
            .backgroundColor(getBgColor(btn, this.isShift))
            .onClick(() => {
              if (btn === '⇧Shift') {
                this.isShift = !this.isShift;
                return;
              }
              if (this.isShift && topShiftButtons[index] !== '') {
                this.onKeyPress(topShiftButtons[index]);
                this.isShift = false;
              } else {
                this.onKeyPress(btn);
              }
            })
          }
          .width('100%')
          .height('100%')
        }
      })
    }
    .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
    .rowsGap(4)
    .columnsGap(5)
    .padding({ left: 10, right: 10, top: 12, bottom: 6 })
    .width('100%')
    .height('55%')
  }
}