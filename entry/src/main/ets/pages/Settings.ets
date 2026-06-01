// entry/src/main/ets/pages/Settings.ets
import router from '@ohos.router';

@Entry
@Component
struct Settings {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 自动去读取 EntryAbility 中初始化的本地磁盘数据，并支持双向实时保存
  @StorageLink('isRad') isRad: boolean = false;
  @StorageLink('vibrationIntensity') vibrationIntensity: number = 50;
  @StorageLink('decimalPrecision') decimalPrecision: number = 6;
  @StorageLink('combinationSelectIndex') combinationSelectIndex: number = 1;
  @StorageLink('permutationSelectIndex') permutationSelectIndex: number = 1;

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .backgroundBlurStyle(BlurStyle.Thin)
        .onClick(() => {
          router.back();
        })

        Text('设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .margin({ left: 16 })
      }
      .width('100%')
      .padding({ top: 48, left: 16, right: 16, bottom: 24 })
      .alignItems(VerticalAlign.Center)

      // 主设置列表
      List({ space: 12 }) {

        // 1. 角度单位
        ListItem() {
          Row() {
            Text('角度单位 (Deg / Rad)')
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.isRad })
              .onChange((isOn: boolean) => {
                this.isRad = isOn;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }

        // 2. 震动强度 (滑块)
        ListItem() {
          Column({ space: 8 }) {
            Row() {
              Text('触感震动强度')
                .fontSize(16)
                .fontColor($r('sys.color.font_primary'))
              Blank()
              Text(`${Math.round(this.vibrationIntensity)}%`)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')

            Slider({
              value: this.vibrationIntensity,
              min: 0,
              max: 100,
              style: SliderStyle.InSet
            })
              .width('100%')
              .onChange((value: number) => {
                this.vibrationIntensity = value;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }

        // 3. 小数精度 (滑块)
        ListItem() {
          Column({ space: 8 }) {
            Row() {
              Text('小数保留位数')
                .fontSize(16)
                .fontColor($r('sys.color.font_primary'))
              Blank()
              Text(this.decimalPrecision === 0 ? '自动化简' : `${this.decimalPrecision} 位`)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')

            Slider({
              value: this.decimalPrecision,
              min: 0,
              max: 12,
              step: 1,
              style: SliderStyle.InSet
            })
              .width('100%')
              .onChange((value: number) => {
                this.decimalPrecision = value;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }

        // 4. 组合计数显示效果 (下拉选择)
        ListItem() {
          Row() {
            Text('组合计数显示效果')
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Select([
              { value: '有大括号 ⎛n⎞\n         ⎝r⎠' },
              { value: '标准上标 nCr' },
              { value: '大C记法 C(n,r)' }
            ])
              .selected(this.combinationSelectIndex)
              .value(this.combinationSelectIndex === 0 ? '大括号' : this.combinationSelectIndex === 1 ? 'nCr' : '大C')
              .font({ size: 14 })
              .fontColor($r('sys.color.font_primary'))
              .onSelect((index: number) => {
                this.combinationSelectIndex = index;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 12, top: 10, bottom: 10 }) // 稍微缩减上下外边距以适配 Select 组件的原生高度
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }

        // 5. 排列计数显示效果 (下拉选择)
        ListItem() {
          Row() {
            Text('排列计数显示效果')
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Select([
              { value: '大P记法 P(n,r)' },
              { value: '标准上标 nPr' },
              { value: '大A记法 A(n,r)' }
            ])
              .selected(this.permutationSelectIndex)
              .value(this.permutationSelectIndex === 0 ? '大P' : this.permutationSelectIndex === 1 ? 'nPr' : '大A')
              .font({ size: 14 })
              .fontColor($r('sys.color.font_primary'))
              .onSelect((index: number) => {
                this.permutationSelectIndex = index;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
        }

        // 6. 关于 (跳转菜单)
        ListItem() {
          Row() {
            Text('关于 CalculatorPro')
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(20)
              .fontColor([$r('sys.color.icon_tertiary')])
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(16)
          .onClick(() => {
            // 这里可以处理关于页面的跳转，比如弹出一个自定义弹窗或跳转到说明页
            console.info('点击了关于菜单');
          })
        }

      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .padding({ bottom: this.navBarHeight })
  }
}