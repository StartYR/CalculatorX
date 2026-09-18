/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file SideBarMenu.ets
 * @description 手势驱动的侧边栏菜单
 * @author StartYi
 * @date 2026
 */

import router from '@ohos.router';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';

import { GroupHeader, ItemDivider, MenuButton, MenuGroup } from './common/MenuComponents';
import { RoutePath } from '../utils/CalculatorConfigs';
import { SemanticIds, getModuleSemanticId } from '../utils/SemanticIds';

@Component
export struct SideBarMenu {
  @Link isSidebarOpen: boolean;
  onSettingsClick?: () => void;
  onHistoryClick?: () => void;
  onModuleSelect?: (module: string) => void;

  // 用于实时记录手指拖拽的横向偏移量
  @State dragOffsetX: number = 0;

  private scroller: Scroller = new Scroller();

  @Builder
  SideBarTitleBuilder() {
    Row() {
      Text('Calc')
        .fontSize(32)
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('sys.color.font_primary'))
      Text('X')
        .fontSize(32)
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('sys.color.font_emphasize'))
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, top: 20 })
    .alignItems(VerticalAlign.Center)
  }

  private getTitleBarMenuItems(): HdsNavigationMenuItemOptions[] {
    return [
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.arrow_counterclockwise_clock_fill'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')]),
          label: '历史记录',
          componentId: SemanticIds.NAV_HISTORY_PAGE,
          action: () => {
            animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
            if (this.onHistoryClick) {
              this.onHistoryClick();
            }
          }
        }
      },
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.gearshape_fill'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')]),
          label: '设置',
          componentId: SemanticIds.NAV_SETTINGS,
          action: () => {
            animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
            if (this.onSettingsClick) {
              this.onSettingsClick();
            }
          }
        }
      }
    ];
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 底层：全屏模糊遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.2)') // 稍微调低透明度，让底层的模糊更透亮
        .id(SemanticIds.SIDEBAR_DISMISS)
        .accessibilityText('关闭导航菜单')
        .backgroundBlurStyle(BlurStyle.Thin)
        .onClick(() => {
          // 收起动效
          animateTo({ duration: 350, curve: Curve.Friction }, () => {
            this.isSidebarOpen = false;
          });
        })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 2. 顶层：左侧抽屉面板
      Column() {
        HdsNavigation() {
          // 菜单项区域
          Scroll(this.scroller) {
            Column() {
              // ====================== 1. 模式 ==========================
              Column() {
                GroupHeader({ title: '模式' })
                MenuGroup() {
                  MenuButton({
                    icon: $r('sys.symbol.calculator_1'),
                    title: '基础计算',
                    semanticId: getModuleSemanticId('basic'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('basic'); }
                    }
                  })
                  ItemDivider()
                  MenuButton({
                    icon: $r('sys.symbol.calculator'),
                    title: '科学计算',
                    semanticId: getModuleSemanticId('scientific'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('scientific'); }
                    }
                  })
                }
              }
              .padding({ left: 16, right: 16, bottom: 12 })

              // ====================== 2. 进阶 ==========================
              Column() {
                GroupHeader({ title: '进阶' })
                MenuGroup() {
                  MenuButton({
                    icon: $r('sys.symbol.foldline_screen'),
                    title: '函数图像',
                    semanticId: getModuleSemanticId('graphing'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('graphing'); }
                    }
                  })
                  ItemDivider()
                  MenuButton({
                    icon: $r('sys.symbol.exponentiation'),
                    title: '方程求解',
                    semanticId: getModuleSemanticId('equation'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('equation'); }
                    }
                  })
                  ItemDivider()
                  MenuButton({
                    icon: $r('sys.symbol.square_grid_2x2'),
                    title: '矩阵与向量',
                    semanticId: getModuleSemanticId('matrix'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('matrix'); }
                    }
                  })
                  // 暂时隐藏未开发的统计分析功能
                  // ItemDivider()
                  // MenuButton({
                  //   icon: $r('sys.symbol.data'),
                  //   title: '统计分析',
                  //   semanticId: getModuleSemanticId('statistics'),
                  //   onClickAction: () => {
                  //     animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                  //     if (this.onModuleSelect) { this.onModuleSelect('statistics'); }
                  //   }
                  // })
                }
              }
              .padding({ left: 16, right: 16, bottom: 12 })

              // ====================== 3. 转换 ==========================
              Column() {
                GroupHeader({ title: '转换' })
                MenuGroup() {
                  // 暂时隐藏未开发的单位转换和进制转换功能
                  // MenuButton({
                  //   icon: $r('sys.symbol.arrow_left_arrow_right'),
                  //   title: '单位转换',
                  //   semanticId: getModuleSemanticId('unit'),
                  //   onClickAction: () => {
                  //     animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                  //     if (this.onModuleSelect) { this.onModuleSelect('unit'); }
                  //   }
                  // })
                  // ItemDivider()
                  // MenuButton({
                  //   icon: $r('sys.symbol.gobackward_10'),
                  //   title: '进制转换',
                  //   semanticId: getModuleSemanticId('base'),
                  //   onClickAction: () => {
                  //     animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                  //     if (this.onModuleSelect) { this.onModuleSelect('base'); }
                  //   }
                  // })
                  // ItemDivider()
                  MenuButton({
                    icon: $r('sys.symbol.yuansign_arrow_2_circlepath'),
                    title: '汇率',
                    semanticId: getModuleSemanticId('exchange'),
                    onClickAction: () => {
                      animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
                      if (this.onModuleSelect) { this.onModuleSelect('exchange'); }
                    }
                  })
                }
              }
              .padding({ left: 16, right: 16, bottom: 12 })

              // ====================== 4. 参考 ==========================
              Column() {
                GroupHeader({ title: '参考' })
                MenuGroup() {
                  // 暂时隐藏未开发的公式库和科学常数功能
                  // MenuButton({ icon: $r('sys.symbol.doc_plaintext'), title: '公式库', onClickAction: () => { /* TODO */ } })
                  // ItemDivider()
                  // MenuButton({ icon: $r('sys.symbol.e'), title: '科学常数', onClickAction: () => { /* TODO */ } })
                  // ItemDivider()
                  MenuButton({
                    icon: $r('sys.symbol.questionmark_circle'),
                    title: '帮助',
                    onClickAction: () => {
                      // 1. 先触发侧边栏丝滑收起动画
                      animateTo({ duration: 350, curve: Curve.Friction }, () => {
                        this.isSidebarOpen = false;
                      });
                      // 2. 触发系统级路由跳转
                      router.pushUrl({
                        url: RoutePath.HELP
                      });
                    }
                  })
                }
              }
              .padding({ left: 16, right: 16, bottom: 32 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ top: 110 })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 触底触顶回弹
          .fadingEdge(true)
        }
        .width('100%')
        .height('100%')
        .mode(NavigationMode.Stack)
        .titleBar({
          padding: { end: LengthMetrics.vp(24) },
          content: {
            title: { mainTitle: '' },
            stackBuilder: (): void => this.SideBarTitleBuilder(),
            menu: {
              value: this.getTitleBarMenuItems(),
              maxCount: 2
            }
          },
          style: {
            scrollEffectOpts: {
              enableScrollEffect: true,
              scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
            },
            originalStyle: {
              contentStyle: {
                titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
                menuStyle: { iconColor: $r('sys.color.icon_primary') }
              }
            },
            scrollEffectStyle: {
              contentStyle: {
                titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
                menuStyle: { iconColor: $r('sys.color.icon_primary') }
              }
            },
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.ADAPTIVE,
              materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
            }
          },
          avoidLayoutSafeArea: true,
          enableComponentSafeArea: false
        })
        .hideBackButton(true)
        .bindToScrollable([this.scroller])
        .titleMode(HdsNavigationTitleMode.MODAL)
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius({ topRight: 32, bottomRight: 32 })
        .clip(true)
      }
      .width('70%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius({ topRight: 32, bottomRight: 32 })
      .shadow({ radius: 48, color: '#25000000', offsetX: 12, offsetY: 0 })

      // 1. 实时绑定手势滑动的偏移量
      .translate({ x: this.dragOffsetX })
      .transition({ type: TransitionType.All, translate: { x: '-100%' } })
      // 2. 挂载原生平移手势
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            // 实时跟手：只允许向左拖拽（偏移量为负数），防止向右拉出屏幕边缘
            if (event.offsetX < 0) {
              this.dragOffsetX = event.offsetX;
            }
          })
          .onActionEnd((event: GestureEvent) => {
            // 手指松开时的判定逻辑
            // 如果向左滑动的距离超过 80px，或者向左甩动的速度极快 (velocityX < -500)
            if (this.dragOffsetX < -80 || event.velocityX < -500) {
              // 触发关闭动画
              animateTo({ duration: 350, curve: Curve.Friction }, () => {
                this.isSidebarOpen = false;
                this.dragOffsetX = 0; // 动画的同时将拖拽偏移量归零
              });
            } else {
              // 没达到关闭阈值，触发回弹动画
              animateTo({ duration: 350, curve: Curve.Friction }, () => {
                this.dragOffsetX = 0;
              });
            }
          })
      )
      // .transition({ type: TransitionType.All, translate: { x: '-100%' } })
    }
    .width('100%')
    .height('100%')
    .id(SemanticIds.SIDEBAR)
    .accessibilityText('CalculatorX 导航菜单')
  }
}
