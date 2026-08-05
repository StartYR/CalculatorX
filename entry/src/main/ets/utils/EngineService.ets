/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file EngineService.ets
 * @description CAS 引擎中枢：正则清洗、AST 解析及 N-API 调度
 * * @author 易睿 (Yi Rui)
 * @date 2026
 */
import testNapi from 'libentry.so';
import Logger from './Logger'

/**
 * 全局计算配置
 */
export interface CalcConfig {
  isRad: boolean;
  precision: number;
  mode: number; // 0:标准(微积分/常规), 1:矩阵, 2:方程等
  xMin?: number;
  xMax?: number;
  pointsCount?: number;
}

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

      // 三角函数
      .replace(/\\csc\^\{-1\}/g, '\\operatorname{Arccsc}')
      .replace(/\\sec\^\{-1\}/g, '\\operatorname{Arcsec}')
      .replace(/\\cot\^\{-1\}/g, '\\operatorname{Arccot}')

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

      // 绕过 MathLive 严格的 \times 类型检查，只要乘号挨着矩阵（包括带上标的矩阵），就将其隐形为隐式乘法
      .replace(/\\times\s*(?=\\begin\{bmatrix\})/g, ' ')
      .replace(/(\\end\{bmatrix\}(?:\^(?:\{[^}]+\}|[a-zA-Z0-9]))?)\s*\\times/g, '$1 ')

      // 利用 MathLive 的隐式乘法，降维叉乘和点乘（匹配 \bullet 及其可能自带的空格）
      // .replace(/⨯/g, '\\operatorname{cross}')
      // .replace(/\\bullet\s?/g, '\\operatorname{dot}')
      // .replace(/\\otimes/g, '\\operatorname{Kronecker}')

      // 矩阵上标（转置、共轭、求逆、乘方）
      .replace(/\\end\{bmatrix\}\^\{\\mathrm\{T\}\}/g, '\\end{bmatrix}\\operatorname{TranOp}')
      .replace(/\\end\{bmatrix\}\^\{\\mathrm\{H\}\}/g, '\\end{bmatrix}\\operatorname{ConjTranOp}')
      .replace(/\\end\{bmatrix\}\^\{-1\}/g, '\\end{bmatrix}\\operatorname{InvOp}')
      // .replace(/\\end\{bmatrix\}\s*\^/g, '\\end{bmatrix}\\operatorname{MatPowOp}^')
      .replace(/\\end\{bmatrix\}\s*\^\{([^}]+)\}/g, '\\end{bmatrix}\\operatorname{MatPowOp}\\left($1\\right)')
      .replace(/\\end\{bmatrix\}\s*\^([a-zA-Z0-9.-]+)/g, '\\end{bmatrix}\\operatorname{MatPowOp}\\left($1\\right)')

      // 给矩阵套上自定义参数，绕过 MathLive 的类型识别
      .replace(/\\begin\{bmatrix\}/g, '\\operatorname{MWrap}\\left(\\begin{bmatrix}')
      .replace(/\\end\{bmatrix\}/g, '\\end{bmatrix}\\right)')
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
  public static calculateNative(jsonStr: string, config: CalcConfig): string {
    let astObj = JSON.parse(jsonStr) as Object;

    let cleanedAstObj = EngineService.unwrapMWrap(astObj);
    let finalJsonStr = JSON.stringify(cleanedAstObj);

    Logger.info(`[EngineService] 清洗后传递给 C++ 的 JSON: ${finalJsonStr}`);

    // 调用 C++ 引擎
    let cppResult = testNapi.calculate(finalJsonStr, config) as string;

    Logger.info(`[EngineService] C++ 返回的 LaTeX: ${cppResult}`);

    return cppResult;
  }

  /**
   * 5. 供 GraphingCalc 调用的批量采样接口
   * 接收 C++ 返回的 Float64Array (二进制共享内存)，零解析开销直接返回给 Canvas 画线
   */
  public static calculateGraphPoints(jsonStr: string, config: CalcConfig): Float64Array {
    let astObj = JSON.parse(jsonStr) as Object;
    let cleanedAstObj = EngineService.unwrapMWrap(astObj);
    let finalJsonStr = JSON.stringify(cleanedAstObj);

    // 此时 cppResult 的类型是 string | Float64Array
    let cppResult = testNapi.calculate(finalJsonStr, config);

    // 类型守卫：如果是字符串，说明发生了错误（返回了 "Error..."），触发兜底
    if (typeof cppResult === 'string') {
      return new Float64Array(0);
    }

    // 既然不是字符串，那在 ArkTS 的类型推导里，它必定是 Float64Array，直接返回！
    return cppResult;
  }

  /**
   * AST 树修剪器：无差别过滤 MWrap 外壳
   */
  private static unwrapMWrap(astNode: Object): Object {
    if (Array.isArray(astNode)) {
      let arr = astNode as Object[];

      // 1. 拦截孤立的 ["MWrap", ["Matrix", ...]]
      if (arr.length === 2 && arr[0] === 'MWrap' && Array.isArray(arr[1]) && arr[1][0] === 'Matrix') {
        return EngineService.unwrapMWrap(arr[1]);
      }

      // 无差别过滤掉当前层级所有的 'MWrap' 字符串
      let filteredArr = arr.filter(item => item !== 'MWrap');

      // 3. 如果过滤后变成了 ["Tuple", ["Matrix", ...]]，直接剥离多余的 Tuple 保护层
      if (filteredArr.length === 2 && filteredArr[0] === 'Tuple' &&
        Array.isArray(filteredArr[1]) && filteredArr[1][0] === 'Matrix') {
        return EngineService.unwrapMWrap(filteredArr[1]);
      }

      // 4. 递归处理其余干净的子节点
      let newArr: Object[] = [];
      for (let i = 0; i < filteredArr.length; i++) {
        newArr.push(EngineService.unwrapMWrap(filteredArr[i]));
      }
      return newArr;
    }
    // 如果是数字或字符串，直接返回
    return astNode;
  }
}