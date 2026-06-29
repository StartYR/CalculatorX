/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file HelpDocs.ets
 * @description 帮助文档查看器
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/30 01:37
 */

import router from '@ohos.router';
import web_webview from '@ohos.web.webview';

@Entry
@Component
struct HelpDocs {
  // 引入全局状态栏高度，保证顶部按钮不会被刘海/挖孔遮挡
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 实例化 Web 控制器
  controller: web_webview.WebviewController = new web_webview.WebviewController();

  build() {
    Column() {
      // ================= 1. 顶部原生返回栏 =================
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Text('帮助中心')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .margin({ top: this.navBarHeight }) // 状态栏避让

      // ================= 2. 全屏离线 Web 容器 =================
      Web({ src: $rawfile('docs/index.html'), controller: this.controller })
        .fileAccess(true)           // 核心：允许访问 rawfile 中的本地静态文件
        .domStorageAccess(true)     // Next.js 框架运行时通常需要 LocalStorage 支持
        .mixedMode(MixedMode.All)   // 允许混合加载
        .width('100%')
        .layoutWeight(1)            // 撑满下方剩余全部空间
        .backgroundColor($r('sys.color.background_primary')) // 避免加载白屏瞬间刺眼
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}