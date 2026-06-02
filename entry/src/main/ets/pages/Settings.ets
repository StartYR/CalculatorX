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
  @StorageLink('answerOutputMode') answerOutputMode: number = 0;

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
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

              this.ItemDivider()

              // 2. 答案输出模式 (新增)
              Row() {
                SymbolGlyph($r('sys.symbol.doc_plaintext'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('答案输出')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Select([
                  { value: '自动模式' },
                  { value: '小数模式' }
                ])
                  .selected(this.answerOutputMode)
                  .value(this.answerOutputMode === 0 ? '自动模式' : '小数模式')
                  .font({ size: 14 })
                  .fontColor($r('sys.color.font_primary'))
                  .onSelect((index: number) => {
                    this.answerOutputMode = index;
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

              // 3. 小数精度 (仅在“小数模式”下渲染显示)
              if (this.answerOutputMode === 1) {
                this.ItemDivider()

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
                    Text(this.decimalPrecision === 16 ? '自动' : `${this.decimalPrecision} 位`)
                      .fontSize(14)
                      .fontColor($r('sys.color.font_secondary'))
                  }
                  .width('100%')

                  // 小字说明
                  Text('为保证精度，建议计算大数时调整至 12 位以下。')
                    .fontSize(12)
                    .fontColor($r('sys.color.font_tertiary')) // 三级字体颜色
                    .lineHeight(10)
                    .width('100%')
                    .padding({ left: 32, right: 8, top: 2, bottom: 0 })

                  Slider({
                    value: this.decimalPrecision,
                    min: 0,
                    max: 16,
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .width('100%')
                    .onChange((value: number) => {
                      this.decimalPrecision = value;
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 6 })
              }
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
                    { value: '自定义' },
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
                router.pushUrl({
                  url: 'pages/DocViewer',
                  params: {
                    title: '使用帮助',
                    content: '欢迎使用 CalculatorPro！\n\n【科学计算】\n支持切换角度制(Deg)与弧度制(Rad)，您可以在设置中调整小数保留精度。\n\n【排版显示】\n支持动态渲染排列(nPr)与组合(nCr)的多种 LaTeX 格式。\n\n【触感反馈】\n我们为您提供了多档位的马达震动调节，请确保系统设置中的触感反馈已开启。'
                  }
                });
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
                router.pushUrl({
                  url: 'pages/DocViewer',
                  params: {
                    title: '隐私声明',
                    content: '本应用极其重视您的隐私。\n\n1. 数据收集\nCalculatorPro 作为一款本地科学计算工具，绝不会在后台私自收集、上传您的任何计算记录或个人标识信息。\n\n2. 权限说明\n本应用无需请求网络、相册、通讯录等敏感权限即可完整运行。所有持久化设置项（如精度、震动档位）均安全存储于设备本地沙盒中。'
                  }
                });
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
                router.pushUrl({
                  url: 'pages/DocViewer',
                  params: {
                    title: '用户协议',
                    content: '1. 接受条款\n通过使用本软件，即表示您同意接受本协议的所有条款。\n\n2. 软件使用\n您仅可将本软件用于合法的计算与学术用途。开发者对因使用本软件产生的计算偏差或附带损失不承担直接法律责任。\n\n3. 知识产权\n本软件的代码架构及界面设计均受版权保护，未经授权不得进行反向工程或商业分发。'
                  }
                });
              })

              this.ItemDivider()
              // 关于 CalcPro
              Row() {
                SymbolGlyph($r('sys.symbol.info_circle'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('关于此应用')
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
                console.info('点击：关于此应用');
                router.pushUrl({ url: 'pages/About' });
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