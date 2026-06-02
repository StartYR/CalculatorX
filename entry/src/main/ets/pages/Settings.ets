// entry/src/main/ets/pages/Settings.ets
import router from '@ohos.router';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuContentOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';

@Entry
@Component
struct Settings {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  @StorageLink('isRad') isRad: boolean = false;
  @StorageLink('hapticFeedback') hapticFeedback: boolean = true;
  @StorageLink('vibrationIntensity') vibrationIntensity: number = 2;
  @StorageLink('vibrationCurve') vibrationCurve: number = 0;
  @StorageLink('decimalPrecision') decimalPrecision: number = 6;
  @StorageLink('combinationSelectIndex') combinationSelectIndex: number = 1;
  @StorageLink('permutationSelectIndex') permutationSelectIndex: number = 1;
  @StorageLink('colorModeIndex') colorModeIndex: number = 2;

  private scrollerForScroll: Scroller = new Scroller();
  private menus: HdsNavigationMenuContentOptions = { value: [] };

  @Builder GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      // 👈 优化 1：稍微收紧标题与下方卡片的间距
      .padding({ left: 16, top: 12, bottom: 4 })
  }

  @Builder ItemDivider() {
    Divider()
      .strokeWidth(1.5)
      .color($r('sys.color.comp_background_tertiary'))
      .margin({ left: 48, right: 16 })
  }

  build() {
    HdsNavigation() {
      Scroll(this.scrollerForScroll) {
        Column() {
          Row().width('100%').height(108)

          // ====================== 科学计算设置 ==========================
          Column() {
            this.GroupHeader('科学计算设置')

            Column() {
              // 1. 角度单位
              Row() {
                SymbolGlyph($r('sys.symbol.triangleshape'))
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
              // 👈 优化 2：统一将上下 padding 压缩为 8，左右保持 16
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

              this.ItemDivider()

              // 2. 小数精度
              // 👈 优化 3：将 Column 内部元素的间距由 8 缩小为 4
              Column({ space: 4 }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.ruler'))
                    .fontSize(20)
                    .fontColor([$r('sys.color.icon_secondary')])
                    .margin({ right: 12 })
                  Text('小数精度')
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                  Blank()
                  Text(this.decimalPrecision === 13 ? '自动化简' : `${this.decimalPrecision} 位`)
                    .fontSize(14)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')

                Slider({
                  value: this.decimalPrecision,
                  min: 0,
                  max: 13,
                  step: 1,
                  style: SliderStyle.InSet
                })
                  .width('100%')
                  .onChange((value: number) => {
                    this.decimalPrecision = value;
                  })
              }
              .width('100%')
              // 👈 优化 4：缩小滑块容器的整体边距
              .padding({ left: 16, right: 16, top: 10, bottom: 6 })
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 12 })

          // ====================== 按键显示 ==========================
          Column() {
            this.GroupHeader('按键显示')

            Column() {
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
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

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
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 12 })

          // ============================= 外观与体验 =====================================
          Column() {
            this.GroupHeader('外观与体验')

            Column() {
              // 颜色模式
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
                  { value: '浅色' },
                  { value: '深色' },
                  { value: '系统' }
                ])
                  .selected(this.colorModeIndex)
                  .value(this.colorModeIndex === 0 ? '浅色' : this.colorModeIndex === 1 ? '深色' : '系统')
                  .font({ size: 14 })
                  .fontColor($r('sys.color.font_primary'))
                  .onSelect((index: number) => {
                    this.colorModeIndex = index;
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

              this.ItemDivider()

              // 触感反馈
              Row() {
                SymbolGlyph($r('sys.symbol.waveform_left_speaker_waveform_right'))
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
              // 👈 优化 5：之前用的是 .padding(16)，极大地拉高了高度，现在只保留左右的16
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })

              if (this.hapticFeedback) {
                this.ItemDivider()

                // 振动风格
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
                .padding({ left: 16, right: 12, top: 8, bottom: 8 })

                // 振动强度
                if (this.vibrationCurve === 0) {
                  this.ItemDivider()

                  Column({ space: 4 }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.rectangle_portrait_wave_2'))
                        .fontSize(20)
                        .fontColor([$r('sys.color.icon_secondary')])
                        .margin({ right: 12 })
                      Text('振动强度')
                        .fontSize(16)
                        .fontColor($r('sys.color.font_primary'))
                      Blank()
                      Text(`${Math.round(this.vibrationIntensity)}`)
                        .fontSize(14)
                        .fontColor($r('sys.color.font_secondary'))
                    }
                    .width('100%')

                    Slider({
                      value: this.vibrationIntensity,
                      min: 1,
                      max: 5,
                      step: 1,
                      style: SliderStyle.InSet
                    })
                      .width('100%')
                      .onChange((value: number) => {
                        this.vibrationIntensity = value;
                      })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 10, bottom: 6 })
                }
              }
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 12 })

          // ============================ 关于 ====================================
          Column() {
            this.GroupHeader('关于')

            Column() {

              // 使用帮助
              Row() {
                SymbolGlyph($r('sys.symbol.checkmark_lightbulb_max'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('使用帮助')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                console.info('点击：使用帮助');
              })

              this.ItemDivider()

              // 隐私声明
              Row() {
                SymbolGlyph($r('sys.symbol.private_browsing_mode'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('隐私声明')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                console.info('点击：隐私声明');
              })

              this.ItemDivider()

              // 用户协议
              Row() {
                SymbolGlyph($r('sys.symbol.doc_plaintext'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('用户协议')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                console.info('点击：用户协议');
              })

              this.ItemDivider()
              // 关于 CalcPro
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
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                console.info('点击：关于');
                // router.pushUrl({ url: 'pages/About' }); 预留跳转
              })



            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 32 + this.navBarHeight })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: {
          mainTitle: '设置',
        },
        menu: this.menus,
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}