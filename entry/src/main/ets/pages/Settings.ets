// entry/src/main/ets/pages/Settings.ets
import router from '@ohos.router';

@Entry
@Component
struct Settings {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  @StorageLink('isRad') isRad: boolean = false;
  @StorageLink('hapticFeedback') hapticFeedback: boolean = true;
  @StorageLink('vibrationIntensity') vibrationIntensity: number = 2; // 1-5 档
  @StorageLink('vibrationCurve') vibrationCurve: number = 0;
  @StorageLink('decimalPrecision') decimalPrecision: number = 6;
  @StorageLink('combinationSelectIndex') combinationSelectIndex: number = 1;
  @StorageLink('permutationSelectIndex') permutationSelectIndex: number = 1;
  @StorageLink('colorModeIndex') colorModeIndex: number = 2; // 0:浅色, 1:深色, 2:系统

  // 统一的分组标题 Builder
  @Builder GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 6 })
  }

  // 统一的分割线 Builder
  @Builder ItemDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_background_tertiary'))
      .margin({ left: 48, right: 16 })
  }

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
      .padding({ top: 48, left: 16, right: 16, bottom: 16 })
      .alignItems(VerticalAlign.Center)

      // 主设置列表
      List() {

        // ==========================================
        // 分组 1：科学计算设置
        // ==========================================
        ListItem() {
          Column() {
            this.GroupHeader('科学计算设置')

            Column() {
              // 1. 角度单位 (改为下拉选择)
              Row() {
                SymbolGlyph($r('sys.symbol.ruler'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('角度单位')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Select([
                  { value: '角度制 (Deg)' },
                  { value: '弧度制 (Rad)' }
                ])
                  .selected(this.isRad ? 1 : 0)
                  .value(this.isRad ? '弧度制 (Rad)' : '角度制 (Deg)')
                  .font({ size: 14 })
                  .fontColor($r('sys.color.font_primary'))
                  .onSelect((index: number) => {
                    this.isRad = (index === 1);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 10, bottom: 10 })

              this.ItemDivider()

              // 2. 小数精度
              Column({ space: 8 }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.ruler'))
                    .fontSize(20)
                    .fontColor([$r('sys.color.icon_secondary')])
                    .margin({ right: 12 })
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

              this.ItemDivider()

              // 3. 组合计数样式
              Row() {
                SymbolGlyph($r('sys.symbol.square_grid_2x2'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('组合计数样式')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Select([
                  { value: '大括号 ⎛n⎞' },
                  { value: '标准 nCr' },
                  { value: '大C C(n,r)' }
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
              .padding({ left: 16, right: 12, top: 10, bottom: 10 })

              this.ItemDivider()

              // 4. 排列计数样式
              Row() {
                SymbolGlyph($r('sys.symbol.list_bullet'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('排列计数样式')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Select([
                  { value: '大P P(n,r)' },
                  { value: '标准 nPr' },
                  { value: '大A A(n,r)' }
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

            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 12 })
        }

        // ==========================================
        // 分组 2：外观与体验
        // ==========================================
        ListItem() {
          Column() {
            this.GroupHeader('外观与体验')

            Column() {

              // 1. 触感反馈 (主开关)
              Row() {
                SymbolGlyph($r('sys.symbol.waveform'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('触感反馈')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.hapticFeedback })
                  .onChange((isOn: boolean) => {
                    this.hapticFeedback = isOn;
                  })
              }
              .width('100%')
              .padding(16)

              // 👇 当触感反馈开启时，才显示子选项
              if (this.hapticFeedback) {
                this.ItemDivider()

                // 1.1 振动风格
                Row() {
                  SymbolGlyph($r('sys.symbol.slider_horizontal_2'))
                    .fontSize(20)
                    .fontColor([$r('sys.color.icon_secondary')])
                    .margin({ right: 12 })
                  Text('振动风格')
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                  Blank()
                  Select([
                    { value: '自定义时长' },
                    { value: '原生清脆 (Sharp)' },
                    { value: '原生轻柔 (Soft)' }
                  ])
                    .selected(this.vibrationCurve)
                    .value(this.vibrationCurve === 0 ? '自定义' : this.vibrationCurve === 1 ? '清脆' : '轻柔')
                    .font({ size: 14 })
                    .fontColor($r('sys.color.font_primary'))
                    .onSelect((index: number) => {
                      this.vibrationCurve = index;
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 12, top: 10, bottom: 10 })

                // 1.2 振动强度 (仅在曲线为0时渲染，1~5 档)
                if (this.vibrationCurve === 0) {
                  this.ItemDivider()

                  Column({ space: 8 }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.clock'))
                        .fontSize(20)
                        .fontColor([$r('sys.color.icon_secondary')])
                        .margin({ right: 12 })
                      Text('振动强度')
                        .fontSize(16)
                        .fontColor($r('sys.color.font_primary'))
                      Blank()
                      Text(`${Math.round(this.vibrationIntensity)} 档`)
                        .fontSize(14)
                        .fontColor($r('sys.color.font_secondary'))
                    }
                    .width('100%')

                    Slider({
                      value: this.vibrationIntensity,
                      min: 1,  // 最低 1 档
                      max: 5,  // 最高 5 档
                      step: 1, // 步长 1 档
                      style: SliderStyle.InSet
                    })
                      .width('100%')
                      .onChange((value: number) => {
                        this.vibrationIntensity = value;
                      })
                  }
                  .width('100%')
                  .padding(16)
                }
              }

              this.ItemDivider()

              // 2. 颜色模式
              Row() {
                SymbolGlyph($r('sys.symbol.paintbrush'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('颜色模式')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Select([
                  { value: '☀️ 浅色' },
                  { value: '🌙 深色' },
                  { value: '⚙️ 系统' }
                ])
                  .selected(this.colorModeIndex)
                  .value(this.colorModeIndex === 0 ? '☀️ 浅色' : this.colorModeIndex === 1 ? '🌙 深色' : '⚙️ 系统')
                  .font({ size: 14 })
                  .fontColor($r('sys.color.font_primary'))
                  .onSelect((index: number) => {
                    this.colorModeIndex = index;
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 10, bottom: 10 })

            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 12 })
        }

        // ==========================================
        // 分组 3：关于
        // ==========================================
        ListItem() {
          Column() {
            this.GroupHeader('关于')

            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.info_circle'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
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
              .onClick(() => {
                console.info('点击了关于菜单');
              })
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 32 })
        }

      }
      .width('100%')
      .layoutWeight(1)
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .padding({ bottom: this.navBarHeight })
  }
}