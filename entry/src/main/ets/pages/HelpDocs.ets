/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file HelpDocs.ets
 * @description 帮助中心页面，基于 Webview 离线加载本地用户手册与说明书
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/30 01:37
 */

import router from '@ohos.router';
import webview from '@ohos.web.webview';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';

@Entry
@Component
struct HelpDocs {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 原生滚动控制器，用于向 HdsNavigation 传递滚动视差
  private scrollerForContent: Scroller = new Scroller();

  // Web 控制器
  controller: webview.WebviewController = new webview.WebviewController();

  onBackPress(): boolean {
    // 是否还有“上一页”
    if (this.controller.accessBackward()) {
      this.controller.backward();
      // 消耗返回事件
      return true;
    }
    // 如果当前就是第一页，返回 false
    return false;
  }

  build() {
    HdsNavigation() {
      // 外层原生滚动容器
      Scroll(this.scrollerForContent) {
        Column() {
          // ================= 顶部占位块 =================
          Row()
            .width('100%')
            .height(this.navBarHeight + 64)
            .backgroundColor('transparent')

          // ================= 离线 Web 容器 =================
          Web({ src: $rawfile('docs/index.html'), controller: this.controller })
            .width('100%')
            .height('100%') // 高度设为 100% 视口
            .padding({ bottom: this.navBarHeight })
            .darkMode(WebDarkMode.Auto)
            .fileAccess(true)
            .domStorageAccess(true)
            .mixedMode(MixedMode.All)
            .textZoomRatio(90) // 网页缩放
            // 配置双向嵌套滚动轴，实现协同联动
            .nestedScroll({
              // 手势上滑（页面下滚）：父容器（原生Scroll）优先滚动。
              scrollForward: NestedScrollMode.PARENT_FIRST,
              // 手势下滑（页面上滚）：Web 内部优先滚动。
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: '帮助中心' },
        backIcon: {
          action: () => {
            // 直接关闭整个页面
            router.back();
          }
        }
      },
      style: {
        // 启用系统级高级渐变模糊与材质自适应
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
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .bindToScrollable([this.scrollerForContent]) // 绑定原生滚动组件
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_primary'))
  }
}