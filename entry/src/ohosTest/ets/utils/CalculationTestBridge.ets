import { webview } from '@kit.ArkWeb';
import { CalcConfig, EngineService } from '../../../main/ets/utils/EngineService';

export interface CalculationRequest {
  protocolVersion: number;
  requestId: string;
  latex: string;
  mode: string;
  angle: string;
  precision: string;
}

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
}

export class CalculationTestBridge {
  private static controller: webview.WebviewController | undefined = undefined;
  private static ready: boolean = false;

  static attach(controller: webview.WebviewController): void {
    CalculationTestBridge.controller = controller;
    CalculationTestBridge.ready = false;
  }

  static markReady(): void {
    CalculationTestBridge.ready = true;
  }

  static async waitUntilReady(timeoutMs: number): Promise<webview.WebviewController> {
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

  private static toNativeMode(mode: string): number {
    switch (mode) {
      case 'matrix': return 1;
      case 'equation': return 2;
      default: return 0;
    }
  }

  private static toNativePrecision(precision: string): number {
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
