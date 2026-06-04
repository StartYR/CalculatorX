// entry/src/main/ets/pages/DocViewer.ets
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
struct DocViewer {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State pageTitle: string = '加载中...';
  @State pageUrl: string = 'https://calcx.startyi.com';

  private scrollerForContent: Scroller = new Scroller(); // 创建滚动控制器

  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      // if (params.title) this.pageTitle = params.title;
      if (params.title) this.pageTitle = '';
      if (params.url) this.pageUrl = params.url;
    }
  }

  build() {
    HdsNavigation() {
      // 使用Scroll包裹Web内容，让标题栏感知滚动
      Scroll(this.scrollerForContent) {
        Web({ src: this.pageUrl, controller: this.controller })
          .width('100%')
          .height('100%')
          .padding({ bottom: this.navBarHeight })
          .darkMode(WebDarkMode.Auto)
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
        title: { mainTitle: this.pageTitle },
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
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .bindToScrollable([this.scrollerForContent]) // 绑定滚动组件
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_primary'))
  }
}