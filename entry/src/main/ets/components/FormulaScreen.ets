/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file FormulaScreen.ets
 * @description 全能公式屏幕，负责渲染、引擎通信及入库闭环
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 21:12
 */

import web_webview from '@ohos.web.webview';
import { HistoryRepository } from '../database/HistoryRepository';
import { EngineService, CalcConfig } from '../utils/EngineService';
import { InputTranslator } from '../utils/InputTranslator';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';
import Logger from '../utils/Logger';

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

  // Web 就绪状态与缓冲
  @State isWebReady: boolean = false;
  private pendingLatex: string | null = null;

  aboutToAppear() {
    Logger.info(`[FormulaScreen] aboutToAppear 触发, 当前 moduleType: ${this.moduleType}`);
    let eventHub = getContext(this).eventHub;

    // ---------- 基础编辑监听 ----------
    eventHub.on('event_math_insert', (str: string) => {
      Logger.info(`[FormulaScreen] 收到 event_math_insert 事件`);
      this.insertToWeb(str);
    });
    eventHub.on('event_math_undo', () => {
      Logger.info(`[FormulaScreen] 收到 event_math_undo 事件`);
      this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('undo')`);
    });
    eventHub.on('event_math_redo', () => {
      Logger.info(`[FormulaScreen] 收到 event_math_redo 事件`);
      this.webviewController.runJavaScript(`document.querySelector('math-field').executeCommand('redo')`);
    });
    eventHub.on('screen_handle_action', (action: string, isShift: boolean) => {
      Logger.info(`[FormulaScreen] 收到 screen_handle_action 事件, action: ${action}, isShift: ${isShift}`);
      this.handleAction(action, isShift);
    });

    // ==================== 新增：底层引擎的硬件级休眠与唤醒控制 ====================
    eventHub.on('sleep_web_engines', () => {
      Logger.info(`[FormulaScreen] 收到 sleep_web_engines 休眠指令`);
      try {
        this.webviewController.onInactive();
        this.renderWebController.onInactive();
      } catch (e) {
        Logger.error(`[FormulaScreen] 休眠执行异常: ${e.message}`);
      }
    });

    eventHub.on('wake_web_engines', () => {
      Logger.info(`[FormulaScreen] 收到 wake_web_engines 唤醒指令`);
      try {
        this.webviewController.onActive();
        this.renderWebController.onActive();
      } catch (e) {
        Logger.error(`[FormulaScreen] 唤醒执行异常: ${e.message}`);
      }
    });

    // ==================== 对象池复用，接收新公式并重置输入框 ====================
    eventHub.on('load_latex_to_editor', (latex: string) => {
      Logger.info(`[FormulaScreen] 收到 load_latex_to_editor 事件`);
      if (!this.isWebReady) {
        Logger.info(`[FormulaScreen] Web 尚未就绪，存入 pendingLatex`);
        this.pendingLatex = latex;
        return;
      }
      let safeString = JSON.stringify(latex);
      let script = latex ? `clearMath(); insertMath(${safeString});` : `clearMath();`;
      try {
        this.webviewController.runJavaScript(script);
      } catch (e) {
        Logger.error(`[FormulaScreen] load_latex_to_editor 异常: ${e.message}`);
      }
    });

    // ==================== 画图数据提取 ====================
    eventHub.on('request_graphing_data', (reqId: number) => {
      Logger.info(`[FormulaScreen] 收到 request_graphing_data 事件, reqId: ${reqId}`);
      this.webviewController.runJavaScript('window.getFormula()', (error, rawLatexResult) => {
        if (error) {
          Logger.error(`[FormulaScreen] request_graphing_data getFormula 失败: ${error.message}`);
          return;
        }
        let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');
        let cleanedLatex = EngineService.cleanRawLatex(rawLatexResult);
        let injectJs = EngineService.generateInjectJs(cleanedLatex);

        this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
          if (err) {
            Logger.error(`[FormulaScreen] request_graphing_data injectJs 失败: ${err.message}`);
            return;
          }
          let cleanJsonString = EngineService.parseWebJsonResult(jsonResult);
          let graphHookTag = `GRAPH_HOOK_${reqId}`;

          Logger.info(`[FormulaScreen] 画图提取，下发 exportLatexToPng`);
          this.renderWebController.runJavaScript(`window.exportLatexToPng(${JSON.stringify(rawLatex)}, ${JSON.stringify(graphHookTag)})`);
          getContext(this).eventHub.emit('temp_graph_ast_ready', reqId, rawLatex, cleanJsonString);
        });
      });
    });
  }

  aboutToDisappear() {
    Logger.info(`[FormulaScreen] aboutToDisappear 触发, 卸载全部事件监听`);
    let eventHub = getContext(this).eventHub;
    eventHub.off('event_math_insert');
    eventHub.off('event_math_undo');
    eventHub.off('event_math_redo');
    eventHub.off('screen_handle_action');
    eventHub.off('request_graphing_data');
    eventHub.off('sleep_web_engines');
    eventHub.off('wake_web_engines');
    eventHub.off('load_latex_to_editor');
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
      AppStorage.setOrCreate('isRad', !this.isRad);
    } else if (action === '° \' \"') {
      this.webviewController.runJavaScript('insertDMS()');
    } else if (action === 'Ans') {
      let latexChar = this.lastAnsLatex === "0" ? "0" : `\\left(${this.lastAnsLatex}\\right)`;
      this.insertToWeb(latexChar);
    } else if (action === 'S⇄D') {
      if (!this.lastValidJson) return;
      let cppPrecisionMode = -1;
      if (isShift) {
        cppPrecisionMode = -4;
        getContext(this).eventHub.emit('screen_shift_consumed');
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
      Logger.info(`[FormulaScreen] 处理 = 按键`);
      if (this.moduleType === 'equation') {
        this.insertToWeb('=');
      } else {
        this.executeCalculation();
      }
    } else if (action === 'EXE') {
      Logger.info(`[FormulaScreen] 处理 EXE 按键`);
      this.executeCalculation();
    } else {
      let latexChar = InputTranslator.translate(action, this.combSelect, this.permSelect);
      this.insertToWeb(latexChar);
    }
  }

  private getCalcMode(): number {
    switch (this.moduleType) {
      case 'matrix': return 1;
      case 'equation': return 2;
      case 'graphing': return 3;
      default: return 0;
    }
  }

  private executeCalculation() {
    Logger.info(`[FormulaScreen] 开始执行 executeCalculation，准备提取输入公式`);
    this.webviewController.runJavaScript('window.getFormula()', (error, rawLatexResult) => {
      if (error) {
        Logger.error(`[FormulaScreen] getFormula 失败: ${error.message}`);
        return;
      }
      Logger.info(`[FormulaScreen] 成功提取原始 LaTeX`);

      let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');
      let cleanedLatex = EngineService.cleanRawLatex(rawLatexResult);
      let injectJs = EngineService.generateInjectJs(cleanedLatex);

      this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
        if (err) {
          Logger.error(`[FormulaScreen] AST 转换 JS 执行失败: ${err.message}`);
          return;
        }
        Logger.info(`[FormulaScreen] 成功获取 MathJSON AST`);

        let cleanJsonString = EngineService.parseWebJsonResult(jsonResult);
        this.lastValidJson = cleanJsonString;

        let cppPrecisionMode = -1;
        if (this.answerOutputMode === 0) {
          cppPrecisionMode = -1;
        } else {
          cppPrecisionMode = this.decimalPrecision === 16 ? -2 : this.decimalPrecision;
        }

        let config: CalcConfig = {
          isRad: this.isRad,
          precision: cppPrecisionMode,
          mode: this.getCalcMode()
        };

        Logger.info(`[FormulaScreen] 准备调用 N-API 计算引擎`);
        let cppResponse: string = EngineService.calculateNative(cleanJsonString, config);
        Logger.info(`[FormulaScreen] C++ 引擎返回结果，长度: ${cppResponse.length}`);

        if (cppResponse.includes("Error")) {
          Logger.error(`[FormulaScreen] C++ 计算出现异常: ${cppResponse}`);
          this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
        } else {
          this.lastAnsLatex = cppResponse;

          Logger.info(`[FormulaScreen] 准备向暗房下发截图指令，原始公式与结果均就绪`);
          this.renderWebController.runJavaScript(`window.exportLatexToPng(${JSON.stringify(rawLatex)}, ${JSON.stringify(cppResponse)})`, (err, res) => {
            if (err) {
              Logger.error(`[FormulaScreen] 暗房截图指令下发失败: ${err.message}`);
            } else {
              Logger.info(`[FormulaScreen] 暗房截图指令已成功送达 Web`);
            }
          });

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

  private recalculateWithPrecision(cppPrecisionMode: number) {
    let config: CalcConfig = {
      isRad: this.isRad,
      precision: cppPrecisionMode,
      mode: this.getCalcMode()
    };
    let cppResponse: string = EngineService.calculateNative(this.lastValidJson, config);
    this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
  }

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
        .onConsole((event) => {
          Logger.info(`[Web Input Console] ${event?.message.getMessage()}`);
          return false;
        })
        // 加载完毕后消费积压的任务
        .onPageEnd(() => {
          Logger.info(`[FormulaScreen] calculator.html 页面加载完毕`);
          this.isWebReady = true;
          if (this.pendingLatex !== null) {
            let safeString = JSON.stringify(this.pendingLatex);
            let script = this.pendingLatex ? `clearMath(); insertMath(${safeString});` : `clearMath();`;
            this.webviewController.runJavaScript(script);
            this.pendingLatex = null;
          }
        })

      // 2. 暗房 Webview
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
        .onConsole((event) => {
          Logger.info(`[Web Render Console] ${event?.message.getMessage()}`);
          return false;
        })
        .javaScriptProxy({
          object: {
            onImageReady: (jsonStr: string) => {
              Logger.info(`[FormulaScreen] 收到 onImageReady 回调，数据长度: ${jsonStr.length}`);
              try {
                let parsed = JSON.parse(jsonStr) as Record<string, string>;
                if (parsed['error']) {
                  Logger.error(`[FormulaScreen] 渲染内部返回 Error: ${parsed['error']}`);
                  return;
                }

                let outLatex = parsed['outputLatex'];
                if (outLatex && outLatex.startsWith("GRAPH_HOOK_")) {
                  let reqId = parseInt(outLatex.replace("GRAPH_HOOK_", ""));
                  let inputBase64 = parsed['inputBase64'];
                  Logger.info(`[FormulaScreen] 拦截为 GRAPH_HOOK 流程，分发事件`);
                  // 完美闭环
                  getContext(this).eventHub.emit('response_graph_base64_ready', reqId, inputBase64);
                  return;
                }

                Logger.info(`[FormulaScreen] 开始组装数据调用 HistoryRepository.insertRecord，当前 moduleType: ${this.moduleType}`);
                HistoryRepository.insertRecord({
                  moduleType: this.moduleType,
                  inputContent: parsed['inputLatex'],
                  outputContent: parsed['outputLatex'],
                  inputBase64: parsed['inputBase64'],
                  outputBase64: parsed['outputBase64'],
                  timestamp: Date.now(),
                });
                Logger.info(`[FormulaScreen] HistoryRepository.insertRecord 调用完成`);
              } catch (e) {
                Logger.error(`[FormulaScreen] onImageReady 执行异常: ${e.message}`);
              }
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