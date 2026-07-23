/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file EngineService.ets
 * @description CAS 引擎中枢：正则清洗、AST 解析及 N-API 调度
 * * @author 易睿 (Yi Rui)
 * @date 2026
 */
import testNapi from 'libentry.so';

export class EngineService {
  /**
   * 1. 还原最纯净的 LaTeX，执行多层防御性正则清洗
   */
  public static cleanRawLatex(rawLatexResult: string): string {
    // 1. 去除首尾引号并处理转义，还原最纯净的 LaTeX
    let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');

    // 2.定义带类型的正则替换器
    let repC = (m: string, n1: string | undefined, n2: string | undefined, r1: string | undefined, r2: string | undefined): string => {
      return `\\operatorname{nCr}\\left(${n1 || n2},${r1 || r2}\\right)`;
    };
    let repP = (m: string, n1: string | undefined, n2: string | undefined, r1: string | undefined, r2: string | undefined): string => {
      return `\\operatorname{nPr}\\left(${n1 || n2},${r1 || r2}\\right)`;
    };
    let repFlatC = (m: string, n: string, r: string): string => {
      return `\\operatorname{nCr}\\left(${n},${r}\\right)`;
    };
    let repFlatP = (m: string, n: string, r: string): string => {
      return `\\operatorname{nPr}\\left(${n},${r}\\right)`;
    };

    // --- 度分秒 (DMS) 的正则替换器 ---
    let repDMS3 = (m: string, d: string, mnt: string, s: string): string => { return `\\operatorname{dms}\\left(${d},${mnt},${s}\\right)`; };
    let repDMS2 = (m: string, d: string, mnt: string): string => { return `\\operatorname{dms}\\left(${d},${mnt},0\\right)`; };
    let repDMS_DS = (m: string, d: string, s: string): string => { return `\\operatorname{dms}\\left(${d},0,${s}\\right)`; };
    let repDMS1 = (m: string, d: string): string => { return `\\operatorname{dms}\\left(${d},0,0\\right)`; };

    let cleanedLatex = rawLatex
    // --- 组合 (C) 的 5 种样式防御 ---
      .replace(/\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
      .replace(/\\binom(?:\{(.+?)\}|([a-zA-Z0-9.]))(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
      .replace(/\{\}\^(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
      .replace(/\{\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
      .replace(/\\mathrm\{C\}\\left\((.+?),\s*(.+?)\\right\)/g, repFlatC)

      // --- 排列 (P/A) 的 5 种样式防御 ---
      .replace(/\\mathrm\{A\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
      .replace(/\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
      .replace(/\{\}\^(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
      .replace(/\{\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
      .replace(/\\mathrm\{P\}\\left\((.+?),\s*(.+?)\\right\)/g, repFlatP)

      // 微积分求导
      .replace(/\\frac\{d\}\{dx\}/g, '\\operatorname{diff}')

      // --- 度分秒拦截 ---
      // 匹配完整的 12°34'56"
      .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\}\s*([0-9.]+)\^\{\\prime\s*\\prime\}/g, repDMS3)
      // 匹配缺秒的 12°34' (负向先行断言防止误杀)
      .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\}(?!\s*\\prime)/g, repDMS2)
      // 匹配缺分的 12°56"
      .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\s*\\prime\}/g, repDMS_DS)
      // 匹配只有度的 12°
      .replace(/([0-9.]+)\^\{\\circ\}/g, repDMS1)

      // ================= 矩阵与向量 =================
      // 伪装行列式与迹，绕过 MathLive 的严格语法与类型检查
      .replace(/\\det/g, '\\operatorname{Det}')
      .replace(/\\operatorname\{tr\}/g, '\\operatorname{Tr}')
      // 利用 MathLive 的隐式乘法，降维叉乘和点乘（匹配 \bullet 及其可能自带的空格）
      .replace(/⨯/g, '\\operatorname{cross}')
      .replace(/\\bullet\s?/g, '\\operatorname{dot}');

    return cleanedLatex;
  }

  /**
   * 2. 生成用于 Webview 注入的 JavaScript 脚本，用于将 LaTeX 转为 MathJSON (AST)
   */
  public static generateInjectJs(cleanedLatex: string): string {
    // 给反斜杠和引号加上双重转义，防止破坏 JS 边界
    let safeLatex = cleanedLatex.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, "\\n");

    // 内存静默转换 JSON
    return `
      (function() {
        try {
          let tempMf = document.createElement('math-field');
          tempMf.style.position = 'absolute';
          tempMf.style.visibility = 'hidden';
          tempMf.style.pointerEvents = 'none';
          document.body.appendChild(tempMf);

          tempMf.value = '${safeLatex}';
          let jsonAst = tempMf.getValue('math-json');
          document.body.removeChild(tempMf);

          return JSON.stringify(jsonAst);
        } catch (e) {
          return JSON.stringify(["Error", "JS_Parse_Crash: " + e.toString()]);
        }
      })();
    `;
  }

  /**
   * 3. 解析并安全验证从 Webview 返回的 JSON 字符串
   */
  public static parseWebJsonResult(jsonResult: string): string {
    let cleanJsonString = '';
    try {
      cleanJsonString = JSON.parse(jsonResult);
      if (typeof cleanJsonString === 'string') {
        cleanJsonString = JSON.parse(cleanJsonString);
      }
    } catch (e) {
      cleanJsonString = jsonResult;
    }
    return typeof cleanJsonString === 'string' ? cleanJsonString : JSON.stringify(cleanJsonString);
  }

  /**
   * 4. 封装 C++ 底层代数引擎的直接调用
   */
  public static calculateNative(jsonStr: string, isRad: boolean, cppPrecisionMode: number): string {
    console.info(`[EngineService] 清洗后传递给 C++ 的 JSON: ${jsonStr}`);
    return testNapi.calculate(jsonStr, isRad, cppPrecisionMode);
  }
}