/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file BasicCalc.ets
 * @description 基础计算器独立业务面板插件
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 02:20
 */

import web_webview from '@ohos.web.webview';
import { HistoryRepository } from '../database/HistoryRepository';
import { EngineService } from '../utils/EngineService';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId } from '../utils/CalculatorConfigs';
import { BasicKeyboard } from './BasicKeyboard';

@Component
export struct BasicCalc {
  // [新增] 引入科学计算器同款的全局状态配置
  @StorageProp('answerOutputMode') answerOutputMode: number = 0;
  @StorageProp('isRad') isRad: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('decimalPrecision') decimalPrecision: number = 13;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // [新增] 双 Webview 控制器
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();
  renderWebController: web_webview.WebviewController = new web_webview.WebviewController();

  // [修改] 移除之前的 inputExpress 占位，换成 Ans 历史记录记忆
  @State lastAnsLatex: string = "0";

  aboutToAppear() {
    let eventHub = getContext(this).eventHub;
    eventHub.on('event_math_insert', (str: string) => { this.insertToWeb(str); });
    eventHub.on('event_math_undo', () => { this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('undo')`); });
    eventHub.on('event_math_redo', () => { this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('redo')`); });
  }

  aboutToDisappear() {
    let eventHub = getContext(this).eventHub;
    eventHub.off('event_math_insert');
    eventHub.off('event_math_undo');
    eventHub.off('event_math_redo');
  }

  // 响应按键点击的核心回调
  private handleKeyPress(btn: string | Resource) {
    let action = getActionId(btn);
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    if (action === 'AC') {
      this.webviewController.runJavaScript('clearMath()');
    } else if (action === '⌫') {
      this.webviewController.runJavaScript('deleteMath()');
    } else if (action === '=') {
      this.webviewController.runJavaScript('window.getFormula()', (error, rawLatexResult) => {
        if (error) return;
        let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');
        let cleanedLatex = EngineService.cleanRawLatex(rawLatexResult);
        let injectJs = EngineService.generateInjectJs(cleanedLatex);

        this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
          if (err) return;
          let cleanJsonString = EngineService.parseWebJsonResult(jsonResult);

          let cppPrecisionMode = -1;
          if (this.answerOutputMode === 0) {
            cppPrecisionMode = -1;
          } else {
            cppPrecisionMode = this.decimalPrecision === 16 ? -2 : this.decimalPrecision;
          }

          let cppResponse: string = EngineService.calculateNative(cleanJsonString, this.isRad, cppPrecisionMode);

          if (cppResponse.includes("Error")) {
            this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
          } else {
            this.lastAnsLatex = cppResponse;
            this.renderWebController.runJavaScript(`window.exportLatexToPng(${JSON.stringify(rawLatex)}, ${JSON.stringify(cppResponse)})`);
            this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
          }
        });
      });
    } else {
      let latexChar = action;
      switch (action) {
        case '×': latexChar = "\\times "; break;
        case '÷': latexChar = "\\div "; break;
        case '−': latexChar = "-"; break;
        case '%': latexChar = "\\%"; break;
        case '+/-': latexChar = "-"; break; // 基础模式的正负号，先优雅地映射为负号输入
        case 'Ans':
          latexChar = this.lastAnsLatex === "0" ? "0" : `\\left(${this.lastAnsLatex}\\right)`;
          break;
      }
      this.insertToWeb(latexChar);
    }
  }

  // 向 Web 插入 LaTeX 代码
  insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }

  build() {
    Stack() {
      Column() {
        // ================= 1. 屏幕显示区 =================
        Web({
          src: $rawfile('calculator.html'),
          controller: this.webviewController
        })
          .darkMode(WebDarkMode.Auto)
          .width('100%')
          .height('45%') // 基础模式屏幕
          .backgroundColor(Color.Transparent)

        // ================= 2. 独立基础键盘区 =================
        BasicKeyboard({
          onKeyPress: (btn: string | Resource) => {
            this.handleKeyPress(btn);
          }
        })
      }
      .width('100%')
      .height('100%')
      // 底部安全区避让
      .padding({ bottom: this.navBarHeight })

      // ================= 3. 暗房 Webview (完全复用) =================
      Web({
        src: $rawfile('render.html'),
        controller: this.renderWebController
      })
        .width(1000)
        .height(2000)
        .position({ x: -5000, y: -5000 })
        .backgroundColor(Color.Transparent)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .javaScriptProxy({
          object: {
            onImageReady: (jsonStr: string) => {
              try {
                let parsed = JSON.parse(jsonStr) as Record<string, string>;
                if (parsed['error']) return;
                HistoryRepository.insertRecord({
                  moduleType: 'basic', // 基础计算的历史记录
                  inputContent: parsed['inputLatex'],
                  outputContent: parsed['outputLatex'],
                  inputBase64: parsed['inputBase64'],
                  outputBase64: parsed['outputBase64'],
                  timestamp: Date.now(),
                });
              } catch (e) {}
            }
          },
          name: "arktsBridge",
          methodList: ["onImageReady"],
          controller: this.renderWebController
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}