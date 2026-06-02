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
  @State pageUrl: string = 'https://calcx.startyi.com'; // 默认底座域名

  // 👈 实例化 WebView 控制器
  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      if (params.title) {
        this.pageTitle = params.title;
      }
      if (params.url) { // 接收 URL
        this.pageUrl = params.url;
      }
    }
  }

  build() {
    HdsNavigation() {
      Column() {
        // 顶部透明占位，避让沉浸式标题栏
        Row().width('100%').height(64)

        // ====================== 网页加载区 ==========================
        Web({ src: this.pageUrl, controller: this.controller })
          .width('100%')
          .layoutWeight(1) // 占满剩余所有空间
          .padding({ bottom: this.navBarHeight })
          // 开启深色模式自适应（网页需要写 prefers-color-scheme 支持）
          .darkMode(WebDarkMode.Auto)
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: this.pageTitle },
      },
      style: {
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
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_primary'))
  }
}