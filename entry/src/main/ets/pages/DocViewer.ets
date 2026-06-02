// entry/src/main/ets/pages/DocViewer.ets
import router from '@ohos.router';
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

  // 用于接收路由参数的状态变量
  @State pageTitle: string = '文档';
  @State pageContent: string = '内容加载中...';

  private scrollerForScroll: Scroller = new Scroller();

  // 页面即将显示时，解析路由传过来的参数
  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      if (params.title) {
        this.pageTitle = params.title;
      }
      if (params.content) {
        this.pageContent = params.content;
      }
    }
  }

  build() {
    HdsNavigation() {
      Scroll(this.scrollerForScroll) {
        Column() {
          // 顶部透明占位，避让沉浸式标题栏
          Row().width('100%').height(108)

          // ====================== 文档正文展示区 ==========================
          Column() {
            Text(this.pageContent)
              .fontSize(16)
              .fontColor($r('sys.color.font_primary'))
              .lineHeight(28) // 稍微放宽行距，提升长文本阅读体验
              .letterSpacing(0.5)
              .width('100%')
          }
          .width('100%')
          // 阅读区的内边距要比普通列表大一些，让眼睛更舒服
          .padding({ left: 24, right: 24, top: 16, bottom: 48 + this.navBarHeight })
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
        // 👇 动态绑定接收到的标题
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
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.FREE) // 依然支持原生大标题折叠
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // 文档阅读界面通常使用纯净的 primary 底色
    .backgroundColor($r('sys.color.background_primary'))
  }
}