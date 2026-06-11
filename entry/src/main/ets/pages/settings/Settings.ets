// entry/src/main/ets/pages/settings/Settings.ets
import { preferences } from '@kit.ArkData';
import { PreferenceConfigs, CombinationOptions, PermutationOptions, RoutePath, MathStyleOption } from '../../utils/CalculatorConfigs';
import router from '@ohos.router';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuContentOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { ConfigurationConstant, common } from '@kit.AbilityKit';

// ==================== 底部半模态面板内容：数学公式样式选择 ====================
@Component
struct MathStyleSheet {
  @Prop styleType: string = 'comb'; // 'comb' 或 'perm'
  onClose?: () => void; // 用于接收关闭面板的回到函数

  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) currentComb: number = 0;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) currentPerm: number = 0;

  build() {
    Column() {
      // 面板的独立标题
      Text(this.styleType === 'comb' ? '组合显示样式' : '排列显示样式')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .padding({ left: 24, top: 24, bottom: 4 })

      // 小字说明
      Text('选择你习惯的公式显示规范，设置后键盘与屏幕的显示将保持一致。')
        .fontSize(13)
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 16 })

      // 渲染选项列表
      Column() {
        ForEach(this.styleType === 'comb' ? CombinationOptions : PermutationOptions, (item: MathStyleOption, index: number) => {
          Row() {
            Column() {
              Text(item.name)
                .fontSize(16)
                .fontColor($r('sys.color.font_primary'))
              Text(item.description) // 小字说明
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 4 })
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image(item.icon)
              .width(100)
              .height(48)
              .objectFit(ImageFit.Contain)
              .fillColor($r('sys.color.font_primary'))
              .margin({ right: 16 })

            if ((this.styleType === 'comb' && this.currentComb === item.id) ||
              (this.styleType === 'perm' && this.currentPerm === item.id)) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(20)
                .fontColor([$r('sys.color.brand')])
            } else {
              Blank().width(20)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .onClick(() => {
            // 1. 保存落盘
            let context = getContext(this) as common.UIAbilityContext;
            let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });

            if (this.styleType === 'comb') {
              prefs.putSync(PreferenceConfigs.KEY_COMBINATION_SELECT, item.id);
            } else {
              prefs.putSync(PreferenceConfigs.KEY_PERMUTATION_SELECT, item.id);
            }
            prefs.flush();

            // 2. 更新内存
            if (this.styleType === 'comb') {
              AppStorage.setOrCreate(PreferenceConfigs.KEY_COMBINATION_SELECT, item.id);
            } else {
              AppStorage.setOrCreate(PreferenceConfigs.KEY_PERMUTATION_SELECT, item.id);
            }

            // 3. 触发回调，收起底部面板！
            if (this.onClose) {
              this.onClose();
            }
          })

          if (index < 4) {
            Divider().color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 })
          }
        })
      }
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
      .margin({ left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

// ==================== 主设置页面 ====================
@Entry
@Component
export struct Settings {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageLink('isRad') isRad: boolean = false;
  @StorageLink('hapticFeedback') hapticFeedback: boolean = true;
  @StorageLink('vibrationCurve') vibrationCurve: number = 0;
  @StorageLink('decimalPrecision') decimalPrecision: number = 6;
  @StorageLink('colorModeIndex') colorModeIndex: number = 2;
  @StorageLink('answerOutputMode') answerOutputMode: number = 0;

  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;

  private scrollerForScroll: Scroller = new Scroller();
  private menus: HdsNavigationMenuContentOptions = { value: [] };

  @State isShowMathSheet: boolean = false;
  @State currentSheetType: string = 'comb';
  // @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();

  @Builder MathSheetBuilder() {
    MathStyleSheet({
      styleType: this.currentSheetType,
      onClose: () => {
        // 当子组件触发 onClose 时，将 isShowMathSheet 设为 false，面板就会丝滑降下
        this.isShowMathSheet = false;
      }
    })
  }

  // 🌟 核心修复：路由地图必须放在主页面里！
  // @Builder pageMap(name: string, param: Object) {
  //   if (name === 'MathStylePage') {
  //     // param 传入 'comb' 表示组合，传入 'perm' 表示排列
  //     MathStylePage({ styleType: param as string })
  //   }
  // }

  @Builder GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
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
          Row().width('100%').height(96)

          // ====================== 计算设置 ==========================
          Column() {
            this.GroupHeader('计算设置')

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
                    // 改变 UI 状态
                    this.isRad = (index === 1);
                    // 保存
                    let context = getContext(this) as common.UIAbilityContext;
                    let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
                    prefs.putSync(PreferenceConfigs.KEY_IS_RAD, this.isRad);
                    prefs.flush();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })

              this.ItemDivider()

              // 2. 答案输出模式
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
                    // 改变 UI 状态
                    this.answerOutputMode = index;
                    // 保存
                    let context = getContext(this) as common.UIAbilityContext;
                    let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
                    prefs.putSync(PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, index);
                    prefs.flush();
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
                      // 改变 UI 状态
                      this.decimalPrecision = value;

                      // 保存
                      let context = getContext(this) as common.UIAbilityContext;
                      let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
                      prefs.putSync(PreferenceConfigs.KEY_DECIMAL_PRECISION, value);
                      prefs.flush();
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


          // ====================== 按键样式 ==========================
          Column() {
            this.GroupHeader('按键样式')

            Column() {
              // 3. 组合计数样式
              Row() {
                SymbolGlyph($r('sys.symbol.square_grid_2x2'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('组合显示样式')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1) // 撑开中间，让右侧文字和箭头靠右

                // 动态显示当前选中的样式名称
                Text(this.combSelect === 0 ? '国际学术' : this.combSelect === 1 ? '角标式 Cₙʳ' : this.combSelect === 2 ? '现代计算器 ⁿCᵣ' : this.combSelect === 3 ? '早期计算器 ₙCᵣ' : '平铺风格 C(n, r)')
                  .fontSize(14)
                  .fontColor($r('sys.color.font_secondary'))
                  .margin({ right: 4 })

                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                // 拉起面板
                this.currentSheetType = 'comb';
                this.isShowMathSheet = true;
              })

              this.ItemDivider()

              // 4. 排列计数样式
              Row() {
                SymbolGlyph($r('sys.symbol.list_bullet'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('排列显示样式')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)

                // 动态显示当前选中的样式名称
                Text(this.permSelect === 0 ? '角标式 Aₙʳ' : this.permSelect === 1 ? '角标式 Pₙʳ' : this.permSelect === 2 ? '现代计算器 ⁿPᵣ' : this.permSelect === 3 ? '早期计算器 ₙPᵣ' : '平铺风格 P(n, r)')
                  .fontSize(14)
                  .fontColor($r('sys.color.font_secondary'))
                  .margin({ right: 4 })

                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                // 拉起面板
                this.currentSheetType = 'perm';
                this.isShowMathSheet = true;
              })
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

                    // 改变 UI 状态
                    this.colorModeIndex = index;
                    let context = getContext(this) as common.UIAbilityContext;

                    // 获取同名首选项实例
                    let options: preferences.Options = { name: 'CalcX_Preferences' };
                    let prefs = preferences.getPreferencesSync(context, options);

                    // 保存
                    prefs.putSync('colorModeIndex', index);
                    prefs.flush();

                    // 切换当前颜色
                    let targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
                    if (index === 0) {
                      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
                    } else if (index === 1) {
                      targetColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
                    }
                    context.getApplicationContext().setColorMode(targetColorMode);
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
                    // 改变 UI 状态
                    this.hapticFeedback = isOn;

                    // 保存
                    let context = getContext(this) as common.UIAbilityContext;
                    let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
                    prefs.putSync(PreferenceConfigs.KEY_HAPTIC_FEEDBACK, isOn);
                    prefs.flush();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 5 })

              // 小字说明
              Text('确保在系统设置中开启“系统触感反馈”。')
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary')) // 三级字体颜色
                .lineHeight(5)
                .width('100%')
                .padding({ left: 48, right: 8, top: 0, bottom: 14 })


              if (this.hapticFeedback) {
                this.ItemDivider()

                // 振动风格
                Row() {
                  SymbolGlyph($r('sys.symbol.rectangle_portrait_wave_2'))
                    .fontSize(20)
                    .fontColor([$r('sys.color.icon_secondary')])
                    .margin({ right: 12 })
                  Text('振动风格')
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                  Blank()
                  Select([
                    { value: '自动 (差异化)' },
                    { value: '原生清脆 (Sharp)' },
                    { value: '原生轻柔 (Soft)' },
                    { value: '原生厚重 (Hard)' }
                  ])
                    .selected(this.vibrationCurve)
                    .value(this.vibrationCurve === 0 ? '自动' :
                      this.vibrationCurve === 1 ? '清脆' :
                      this.vibrationCurve === 2 ? '轻柔' : '厚重')
                    .font({ size: 14 })
                    .fontColor($r('sys.color.font_primary'))
                    .onSelect((index: number) => {
                      // 改变 UI 状态
                      this.vibrationCurve = index;
                      // 保存
                      let context = getContext(this) as common.UIAbilityContext;
                      let prefs = preferences.getPreferencesSync(context, { name: PreferenceConfigs.STORE_NAME });
                      prefs.putSync(PreferenceConfigs.KEY_VIBRATION_CURVE, index);
                      prefs.flush();
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 12, top: 8, bottom: 8 })
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
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：使用帮助');
                router.pushUrl({
                  url: RoutePath.DOC_VIEWER,
                  params: {
                    title: '使用帮助',
                    url: 'https://calcx.startyi.com/help'
                  }
                });
              })

              this.ItemDivider()

              // 隐私政策
              Row() {
                SymbolGlyph($r('sys.symbol.private_browsing_mode'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('隐私政策')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：隐私政策');
                router.pushUrl({
                  url: RoutePath.DOC_VIEWER,
                  params: {
                    title: '隐私政策',
                    url: 'https://calcx.startyi.com/privacy'
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
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：用户协议');
                router.pushUrl({
                  url: RoutePath.DOC_VIEWER,
                  params: {
                    title: '用户协议',
                    url: 'https://calcx.startyi.com/agreement'
                  }
                });
              })

              this.ItemDivider()

              // 关于此应用
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
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：关于此应用');
                router.pushUrl({ url: RoutePath.ABOUT });
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
    // .navDestination(this.pageMap)
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
    .bindSheet($$this.isShowMathSheet, this.MathSheetBuilder(), {
      height: SheetSize.FIT_CONTENT, // 优雅所在：面板高度自适应内容，不占用全屏
      dragBar: true,                 // 顶部显示可拖拽的灰色小横条
      backgroundColor: $r('sys.color.background_secondary'), // 统一底色
      showClose: false               // 隐藏右上角默认关闭按钮，保持 UI 极简
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}