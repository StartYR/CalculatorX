/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file CalculationTestBridge.ets
 * @description 设备计算测试与设置预置的响应协议
 * @author StartYi
 * @date 2026/09/15 23:35
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CalcConfig, EngineService } from '../../../main/ets/utils/EngineService';
import { PreferenceConfigs } from '../../../main/ets/utils/CalculatorConfigs';

/** CLI 与测试 Ability 共用的版本 1 请求契约；requestId 用于匹配日志中的响应。 */
export interface CalculationRequest {
  protocolVersion: number;
  requestId: string;
  latex: string;
  mode: string;
  angle: string;
  precision: string;
}

/** stage 定位失败边界；成功响应的中间表示供调用方核对计算路径。 */
export interface CalculationResponse {
  protocolVersion: number;
  requestId: string;
  ok: boolean;
  inputLatex?: string;
  normalizedLatex?: string;
  mathJson?: string;
  resultLatex?: string;
  mode?: string;
  angle?: string;
  precision?: string;
  stage?: string;
  error?: string;
  executionPath?: string;
  setting?: string;
  value?: string;
  restartRequired?: boolean;
}

interface NormalizedSetting {
  key: string;
  value: string | number | boolean;
}

/** WebView 就绪后沿应用现有 MathJSON 与原生引擎调用链执行计算。 */
export class CalculationTestBridge {
  private static controller: webview.WebviewController | undefined = undefined;
  private static ready: boolean = false;

  static attach(controller: webview.WebviewController): void {
    // 换绑控制器时必须清除旧就绪状态，避免请求落入尚未加载的 WebView。
    CalculationTestBridge.controller = controller;
    CalculationTestBridge.ready = false;
  }

  static markReady(): void {
    CalculationTestBridge.ready = true;
  }

  static async waitUntilReady(timeoutMs: number): Promise<webview.WebviewController> {
    // 页面加载和测试 Ability 启动异步进行；仅在有效控制器已就绪时继续。
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (CalculationTestBridge.ready && CalculationTestBridge.controller !== undefined) {
        return CalculationTestBridge.controller;
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    throw new Error(`WebView was not ready within ${timeoutMs} ms`);
  }

  static async calculate(request: CalculationRequest, timeoutMs: number): Promise<CalculationResponse> {
    let controller: webview.WebviewController;
    try {
      controller = await CalculationTestBridge.waitUntilReady(timeoutMs);
    } catch (error) {
      return CalculationTestBridge.failure(request.requestId, 'web-ready', `${error}`);
    }

    // 与正式计算路径一致，先经 WebView 得到可解析的 MathJSON，再交给原生引擎。
    const normalizedLatex = EngineService.cleanRawLatex(JSON.stringify(request.latex));
    let mathJson: string;
    try {
      const webResult = await controller.runJavaScript(EngineService.generateInjectJs(normalizedLatex));
      mathJson = EngineService.parseWebJsonResult(webResult);
      JSON.parse(mathJson);
    } catch (error) {
      return CalculationTestBridge.failure(request.requestId, 'latex-parse', `${error}`);
    }

    try {
      const config: CalcConfig = {
        isRad: request.angle === 'radian',
        precision: CalculationTestBridge.toNativePrecision(request.precision),
        mode: CalculationTestBridge.toNativeMode(request.mode)
      };
      const resultLatex = EngineService.calculateNative(mathJson, config);
      if (resultLatex.includes('Error')) {
        return {
          protocolVersion: 1,
          requestId: request.requestId,
          ok: false,
          inputLatex: request.latex,
          normalizedLatex: normalizedLatex,
          mathJson: mathJson,
          resultLatex: resultLatex,
          mode: request.mode,
          angle: request.angle,
          precision: request.precision,
          stage: 'native-calculate',
          error: resultLatex
        };
      }
      return {
        protocolVersion: 1,
        requestId: request.requestId,
        ok: true,
        inputLatex: request.latex,
        normalizedLatex: normalizedLatex,
        mathJson: mathJson,
        resultLatex: resultLatex,
        mode: request.mode,
        angle: request.angle,
        precision: request.precision
      };
    } catch (error) {
      return CalculationTestBridge.failure(request.requestId, 'native-calculate', `${error}`);
    }
  }

  static async setSetting(requestId: string, setting: string, value: string,
    timeoutMs: number, entryContext: common.UIAbilityContext): Promise<CalculationResponse> {
    try {
      await CalculationTestBridge.waitUntilReady(timeoutMs);
      // 使用主应用同一 Preferences 存储，flush 后回读确认，应用重启后才观察 UI 生效。
      const normalized = CalculationTestBridge.normalizeSetting(setting, value);
      const store = preferences.getPreferencesSync(entryContext, { name: PreferenceConfigs.STORE_NAME });
      store.putSync(normalized.key, normalized.value);
      await store.flush();
      const storedValue = store.getSync(normalized.key, `__calcx_missing_${Date.now()}`);
      if (storedValue !== normalized.value) {
        throw new Error(`Setting did not persist: ${setting}`);
      }
      return {
        protocolVersion: 1,
        requestId: requestId,
        ok: true,
        executionPath: 'setup',
        setting: setting,
        value: value,
        restartRequired: true
      };
    } catch (error) {
      return CalculationTestBridge.failure(requestId, 'settings-set', `${error}`);
    }
  }

  static async setFormula(requestId: string, latex: string,
    entryContext: common.UIAbilityContext): Promise<CalculationResponse> {
    try {
      if (latex.length > 4096) {
        throw new Error('latex must contain at most 4096 characters');
      }
      if (!entryContext.applicationInfo.debug) {
        throw new Error('formula setup is available only in debug builds');
      }
      // 版本前缀表示待启动消费的公式，调试构建以外不能从测试协议注入输入。
      const store = preferences.getPreferencesSync(entryContext, { name: PreferenceConfigs.STORE_NAME });
      store.putSync(PreferenceConfigs.KEY_CLI_PENDING_FORMULA, `1:${latex}`);
      await store.flush();
      return {
        protocolVersion: 1,
        requestId: requestId,
        ok: true,
        executionPath: 'setup',
        inputLatex: latex,
        restartRequired: true
      };
    } catch (error) {
      return CalculationTestBridge.failure(requestId, 'formula-set', `${error}`);
    }
  }

  /** CLI 字符串值映射到应用真实键与存储类型；必须与宿主白名单同步。 */
  private static normalizeSetting(setting: string, value: string): NormalizedSetting {
    switch (setting) {
      case 'angle':
        if (!['degree', 'radian'].includes(value)) throw new Error('angle must be degree or radian');
        return { key: PreferenceConfigs.KEY_IS_RAD, value: value === 'radian' };
      case 'answer-output':
        if (!['auto', 'decimal'].includes(value)) throw new Error('answer-output must be auto or decimal');
        return { key: PreferenceConfigs.KEY_ANSWER_OUTPUT_MODE, value: value === 'auto' ? 0 : 1 };
      case 'decimal-precision':
        if (value !== 'auto' && !/^(?:[0-9]|1[0-5])$/.test(value)) {
          throw new Error('decimal-precision must be auto or 0 through 15');
        }
        return { key: PreferenceConfigs.KEY_DECIMAL_PRECISION, value: value === 'auto' ? 16 : Number(value) };
      case 'haptic-feedback':
        if (!['true', 'false'].includes(value)) throw new Error('haptic-feedback must be true or false');
        return { key: PreferenceConfigs.KEY_HAPTIC_FEEDBACK, value: value === 'true' };
      case 'vibration-curve':
        if (!/^[0-3]$/.test(value)) throw new Error('vibration-curve must be 0 through 3');
        return { key: PreferenceConfigs.KEY_VIBRATION_CURVE, value: Number(value) };
      case 'startup-page':
        if (!/^[0-9]$/.test(value)) throw new Error('startup-page must be 0 through 9');
        return { key: PreferenceConfigs.KEY_STARTUP_PAGE, value: Number(value) };
      case 'color-mode':
        if (!['light', 'dark', 'system'].includes(value)) throw new Error('color-mode must be light, dark, or system');
        return {
          key: PreferenceConfigs.KEY_COLOR_MODE,
          value: value === 'light' ? 0 : value === 'dark' ? 1 : 2
        };
      case 'combination-style':
        if (!/^[0-4]$/.test(value)) throw new Error('combination-style must be 0 through 4');
        return { key: PreferenceConfigs.KEY_COMBINATION_SELECT, value: Number(value) };
      case 'permutation-style':
        if (!/^[0-4]$/.test(value)) throw new Error('permutation-style must be 0 through 4');
        return { key: PreferenceConfigs.KEY_PERMUTATION_SELECT, value: Number(value) };
      default:
        throw new Error(`Unsupported setting: ${setting}`);
    }
  }

  private static toNativeMode(mode: string): number {
    switch (mode) {
      case 'matrix': return 1;
      case 'equation': return 2;
      default: return 0;
    }
  }

  private static toNativePrecision(precision: string): number {
    // -1/-2 是原生引擎的自动精度模式，数字精度不使用负值。
    if (precision === 'auto') {
      return -1;
    }
    if (precision === 'decimal-auto') {
      return -2;
    }
    return Number(precision);
  }

  private static failure(requestId: string, stage: string, error: string): CalculationResponse {
    return {
      protocolVersion: 1,
      requestId: requestId,
      ok: false,
      stage: stage,
      error: error
    };
  }
}
