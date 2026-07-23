/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file FormulaScreen.ets
 * @description 全能公式屏幕，负责渲染、引擎通信及入库闭环
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 21:12
 */

import web_webview from '@ohos.web.webview';
import { HistoryRepository } from '../database/HistoryRepository';
import { EngineService } from '../utils/EngineService';
import { InputTranslator } from '../utils/InputTranslator';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';

@Component
export struct FormulaScreen {
  @Prop moduleType: string; // 区分是 basic 还是 scientific，用于入库打标签

  // 全局配置属性
  @StorageProp('answerOutputMode') answerOutputMode: number = 0;
  @StorageProp('isRad') isRad: boolean = false;
  @StorageProp('decimalPrecision') decimalPrecision: number = 13;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;

  webviewController: web_webview.WebviewController = new web_webview.WebviewController();
  renderWebController: web_webview.WebviewController = new web_webview.WebviewController();

  // 内部计算状态
  @State lastAnsLatex: string = "0";      // 供 Ans 调用的上一次结果
  @State lastValidJson: string = "";      // 供 S⇄D 重新计算的纯净 AST
  @State isTempDecimal: boolean = false;  // 当前 S⇄D 面板的显示状态

  aboutToAppear() {
    let eventHub = getContext(this).eventHub;

    // 监听全局历史记录插板的插入、顶部撤销重做
    eventHub.on('event_math_insert', (str: string) => {
      this.insertToWeb(str);
    });
    eventHub.on('event_math_undo', () => {
      this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('undo')`);
    });
    eventHub.on('event_math_redo', () => {
      this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('redo')`);
    });

    // 监听来自各模式 UI 外壳的按键指令分发
    eventHub.on('screen_handle_action', (action: string, isShift: boolean) => {
      this.handleAction(action, isShift);
    });
  }

  aboutToDisappear() {
    let eventHub = getContext(this).eventHub;
    eventHub.off('event_math_insert');
    eventHub.off('event_math_undo');
    eventHub.off('event_math_redo');
    eventHub.off('screen_handle_action');
  }

  // 接收并处理任何界面的按键逻辑
  private handleAction(action: string, isShift: boolean) {
    if (action === 'AC') {
      this.webviewController.runJavaScript('clearMath()');
    } else if (action === '⌫') {
      this.webviewController.runJavaScript('deleteMath()');
    } else if (action === '⇦') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToPreviousChar')`);
    } else if (action === '⇨') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToNextChar')`);
    } else if (action === '⇧') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveUp')`);
    } else if (action === '⇩') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveDown')`);
    } else if (action === 'R/D') {
      AppStorage.setOrCreate('isRad', !this.isRad); // 改变全局状态
    } else if (action === '° \' \"') {
      this.webviewController.runJavaScript('insertDMS()');
    } else if (action === 'Ans') {
      let latexChar = this.lastAnsLatex === "0" ? "0" : `\\left(${this.lastAnsLatex}\\right)`;
      this.insertToWeb(latexChar);
    } else if (action === 'S⇄D') {
      if (!this.lastValidJson) return;
      let cppPrecisionMode = -1;
      if (isShift) {
        cppPrecisionMode = -4; // 消费掉 Shift 状态 (通过事件回调或让外部自行复位)
        getContext(this).eventHub.emit('screen_shift_consumed'); // 通知外部复位 Shift
      } else {
        this.isTempDecimal = !this.isTempDecimal;
        cppPrecisionMode = this.isTempDecimal ? (this.decimalPrecision === 16 ? -2 : this.decimalPrecision) : -3;
      }
      this.recalculateWithPrecision(cppPrecisionMode);
    } else if (action.startsWith('LONG_SD_')) {
      if (!this.lastValidJson) return;
      let cppPrecisionMode = -1;
      switch (action) {
        case 'LONG_SD_DEC':
          this.isTempDecimal = true;
          cppPrecisionMode = (this.decimalPrecision === 16 ? -2 : this.decimalPrecision);
          break;
        case 'LONG_SD_FRAC':
          this.isTempDecimal = false;
          cppPrecisionMode = -3;
          break;
        case 'LONG_SD_MIXED':
          this.isTempDecimal = false;
          cppPrecisionMode = -4;
          break;
        case 'LONG_SD_DMS':
          cppPrecisionMode = -5;
          break;
      }
      this.recalculateWithPrecision(cppPrecisionMode);
    } else if (action === '=') {
      this.executeCalculation();
    } else {
      // 交给后厨翻译
      let latexChar = InputTranslator.translate(action, this.combSelect, this.permSelect);
      this.insertToWeb(latexChar);
    }
  }

  // 执行核心计算过程
  private executeCalculation() {
    this.webviewController.runJavaScript('window.getFormula()', (error, rawLatexResult) => {
      if (error) return;

      let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');
      let cleanedLatex = EngineService.cleanRawLatex(rawLatexResult);
      let injectJs = EngineService.generateInjectJs(cleanedLatex);

      this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
        if (err) return;

        let cleanJsonString = EngineService.parseWebJsonResult(jsonResult);
        this.lastValidJson = cleanJsonString;

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

          if (cppPrecisionMode === -1) {
            this.isTempDecimal = cppResponse.includes('.');
          } else {
            this.isTempDecimal = true;
          }
          this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
        }
      });
    });
  }

  // 通过特定控制码重新请求 C++ 渲染
  private recalculateWithPrecision(cppPrecisionMode: number) {
    let cppResponse: string = EngineService.calculateNative(this.lastValidJson, this.isRad, cppPrecisionMode);
    this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
  }

  // 向 Web 插入 LaTeX 代码
  private insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }

  build() {
    Stack() {
      // 1. 公式显示区
      Web({
        src: $rawfile('calculator.html'),
        controller: this.webviewController
      })
        .darkMode(WebDarkMode.Auto)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)

      // 2. 暗房 Webview (完全解耦，后台静默运行)
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
                  moduleType: this.moduleType, // 动态识别调用方
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
  }
}