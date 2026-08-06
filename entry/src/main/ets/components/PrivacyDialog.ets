/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file PrivacyDialog.ets
 * @description 首次启动隐私合规声明弹窗
 * @author 易睿 (Yi Rui)
 * @date 2026/8/6 11:55
 */

import { common, Want } from '@kit.AbilityKit';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PreferenceConfigs, CURRENT_PRIVACY_VERSION } from '../utils/CalculatorConfigs';

@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController;

  // 获取当前 UIAbility 的上下文，用于退出应用和拉起浏览器
  private context = getContext(this) as common.UIAbilityContext;

  /**
   * @description 隐式拉起系统默认浏览器访问指定网页
   */
  private openWebBrowser(url: string) {
    let want: Want = {
      action: 'ohos.want.action.viewData', // 系统预置的查看数据 Action
      entities: ['entity.system.browsable'], // 声明需要可浏览网页的能力
      uri: url
    };
    this.context.startAbility(want).catch((err: Error) => {
      // 容错处理：如果系统极度精简没有浏览器，静默拦截错误避免崩溃
    });
  }

  build() {
    Column({ space: 16 }) {
      Text('温馨提示')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .margin({ top: 20 })

      // ================= 富文本正文 =================
      Text() {
        Span('欢迎使用 CalculatorX！我们非常重视您的隐私保护和个人信息安全。在您使用本应用前，请您务必仔细阅读并透彻理解')
        // 高亮并绑定点击事件的用户协议
        Span('《用户协议》')
          .fontColor($r('sys.color.brand')) // 使用全局品牌强调色（通常是蓝色或主题色）
          .onClick(() => {
            this.openWebBrowser('https://calcx.startyi.com/agreement/');
          })
        Span('与')
        // 高亮并绑定点击事件的隐私政策
        Span('《隐私政策》')
          .fontColor($r('sys.color.brand'))
          .onClick(() => {
            this.openWebBrowser('https://calcx.startyi.com/privacy/');
          })
        Span('。如果您同意以上协议内容，请点击“同意”开始使用我们的产品与服务。')
      }
      .fontSize(15)
      .fontColor($r('sys.color.font_secondary'))
      .lineHeight(24) // 增加行高，提升阅读舒适度
      .textAlign(TextAlign.Start)
      .margin({ left: 20, right: 20, top: 4, bottom: 8 })

      // ================= 底部操作按钮 =================
      Row({ space: 16 }) {
        // “不同意”按钮（透明背景，降低视觉权重，符合合规无诱导要求）
        Button('不同意')
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .onClick(() => {
            // 极其冷酷且合规的操作：直接杀掉自身进程
            this.context.terminateSelf();
          })

        // “同意”按钮
        Button('同意')
          .type(ButtonType.Capsule)
          .backgroundColor($r('sys.color.comp_background_emphasize'))
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            // 1. 将最新的版本号落盘持久化
            PreferenceManager.set(PreferenceConfigs.KEY_PRIVACY_VERSION, CURRENT_PRIVACY_VERSION);
            // 2. 同步最新版本号到内存
            AppStorage.setOrCreate(PreferenceConfigs.KEY_PRIVACY_VERSION, CURRENT_PRIVACY_VERSION);
            // 3. 关闭弹窗放行
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .width('85%') // 稍微收窄一点，让弹窗更显精致
  }
}