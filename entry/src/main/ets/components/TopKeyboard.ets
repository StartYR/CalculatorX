// entry/src/main/ets/components/TopKeyboard.ets
import { topButtons, topShiftButtons, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs, CombinationOptions, PermutationOptions } from '../utils/CalculatorConfigs';

@Component
export struct TopKeyboard {
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Grid() {
      ForEach(topButtons, (btn: string | Resource, index: number) => {
        GridItem() {
          Column() {
            if (index >= 6) {
              // Shift 副功能文本区
              Row() {
                if (typeof topShiftButtons[index] === 'string') {
                  Text(topShiftButtons[index] as string)
                    .fontFamily(getFontFamily(topShiftButtons[index]))
                    .fontSize(15)
                    .fontColor('#ffac8100')
                    .textAlign(TextAlign.Center)
                    .width('100%')
                } else {
                  Image(topShiftButtons[index] as Resource)
                    .width(24)
                    .height(24)
                    .fillColor($r('sys.color.icon_secondary'))
                    .objectFit(ImageFit.Contain)
                }
              }
              .width('100%')
              .height(16)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .margin({ bottom: 1 })
            } else {
              Row()
                .width('100%')
                .height(6)
            }

            // 主按钮
            Button() {
              if (btn === 'nCr') {
                // 如果是组合键，使用全局配置里的 SVG 图标
                Image(CombinationOptions[this.combSelect].icon)
                  .width('100%')
                  .height(36)
                  .objectFit(ImageFit.Contain)
                  .fillColor($r('sys.color.font_secondary'))

              } else if (btn === 'nPr') {
                // 如果是排列键，使用全局配置里的 SVG 图标
                Image(PermutationOptions[this.permSelect].icon)
                  .width('100%')
                  .height(36)
                  .objectFit(ImageFit.Contain)
                  .fillColor($r('sys.color.font_secondary'))

              } else if (typeof btn === 'string') {
                // 普通字符串按键，渲染 Text
                Text(btn)
                  .fontFamily(getFontFamily(btn))
                  .fontSize(getFontSize(btn))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getFontColor(btn))

              } else {
                // Image 按键
                Image(btn)
                  .width(36)
                  .height(36)
                  .fillColor($r('sys.color.font_secondary'))
              }
            }
            .type(ButtonType.Normal)
            .borderRadius(12)
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 2, right: 2, top: 0, bottom: 0 })
            .backgroundColor(getBgColor(btn, this.isShift))

            // 物理按键的 3D 静态渲染
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
            .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
            .borderColor($r('app.color.btn_highlight'))

            // 系统级物理回弹与压暗光效
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .stateStyles({
              pressed: {
                .opacity(0.7)
                .shadow(ShadowStyle.OUTER_DEFAULT_XS)
              },
              normal: {
                .opacity(1.0)
                .shadow(ShadowStyle.OUTER_DEFAULT_SM)
              }
            })

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