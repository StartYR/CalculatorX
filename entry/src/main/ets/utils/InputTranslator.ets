/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file InputTranslator.ets
 * @description 翻译中枢，负责将用户按键指令无状态地翻译为标准 LaTeX
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 21:11
 */

import { CombinationOptions, PermutationOptions } from './CalculatorConfigs';

export class InputTranslator {
  /**
   * 将 ActionID 翻译为对应的 LaTeX 代码
   */
  public static translate(action: string, combSelect: number, permSelect: number): string {
    let latexChar = action;
    switch (action) {
      case '×':        latexChar = "\\times "; break;
      case '÷':        latexChar = "\\div "; break;
      case '−':        latexChar = "-"; break;
      case 'π':        latexChar = "\\pi "; break;
      case '∞':        latexChar = "\\infty "; break;
      case 'i':        latexChar = "i"; break;
      case 'comma':    latexChar = ","; break;
      case 'fraction': latexChar = "\\frac{\\placeholder{}}{\\placeholder{}}"; break;
      case 'sqrt':     latexChar = "\\sqrt{\\placeholder{}}"; break;
      case 'sqrt3':    latexChar = "\\sqrt[3]{\\placeholder{}}"; break;
      case 'sqrtx':    latexChar = "\\sqrt[\\placeholder{}]{\\placeholder{}}"; break;
      case 'power2':   latexChar = "^2"; break;
      case 'power3':   latexChar = "^3"; break;
      case 'power':    latexChar = "^{\\placeholder{}}"; break;
      case 'inverse':  latexChar = '^{-1}'; break;
      case 'e_power':  latexChar = 'e^{\\placeholder{}}'; break;
      case 'icon_exp': latexChar = '\\times 10^{\\placeholder{}}'; break;
      case 'abs':      latexChar = "\\left| \\placeholder{} \\right|"; break;
      case 'fact':     latexChar = "!"; break;
      case 'ln':       latexChar = "\\ln\\left(\\placeholder{}\\right)"; break;
      case 'lg':       latexChar = '\\lg\\left(\\placeholder{}\\right)'; break;
      case 'log':      latexChar = "\\log_{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;

      case 'sin':      latexChar = "\\sin\\left(\\placeholder{}\\right)"; break;
      case 'cos':      latexChar = "\\cos\\left(\\placeholder{}\\right)"; break;
      case 'tan':      latexChar = "\\tan\\left(\\placeholder{}\\right)"; break;
      // case 'sin⁻¹':    latexChar = "\\arcsin\\left(\\placeholder{}\\right)"; break;
      // case 'cos⁻¹':    latexChar = "\\arccos\\left(\\placeholder{}\\right)"; break;
      // case 'tan⁻¹':    latexChar = "\\arctan\\left(\\placeholder{}\\right)"; break;
      case 'sinh':      latexChar = "\\sinh\\left(\\placeholder{}\\right)"; break;
      case 'cosh':      latexChar = "\\cosh\\left(\\placeholder{}\\right)"; break;
      case 'tanh':      latexChar = "\\tanh\\left(\\placeholder{}\\right)"; break;
      // case 'sinh⁻¹':    latexChar = "\\arcsinh\\left(\\placeholder{}\\right)"; break;
      // case 'cosh⁻¹':    latexChar = "\\arccosh\\left(\\placeholder{}\\right)"; break;
      // case 'tanh⁻¹':    latexChar = "\\arctanh\\left(\\placeholder{}\\right)"; break;
      case 'csc':      latexChar = "\\csc\\left(\\placeholder{}\\right)"; break;
      case 'sec':      latexChar = "\\sec\\left(\\placeholder{}\\right)"; break;
      case 'cot':      latexChar = "\\cot\\left(\\placeholder{}\\right)"; break;
      // case 'csc⁻¹':    latexChar = "\\arccsc\\left(\\placeholder{}\\right)"; break;
      // case 'sec⁻¹':    latexChar = "\\arcsec\\left(\\placeholder{}\\right)"; break;
      // case 'cot⁻¹':    latexChar = "\\arccot\\left(\\placeholder{}\\right)"; break;


      case 'sin⁻¹':    latexChar = "\\sin^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'cos⁻¹':    latexChar = "\\cos^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'tan⁻¹':    latexChar = "\\tan^{-1}\\left(\\placeholder{}\\right)"; break;

      // 双曲反函数
      case 'sinh⁻¹':    latexChar = "\\sinh^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'cosh⁻¹':    latexChar = "\\cosh^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'tanh⁻¹':    latexChar = "\\tanh^{-1}\\left(\\placeholder{}\\right)"; break;

      // 倒数三角反函数（这三个如果不改，大概率也会标红）
      case 'csc⁻¹':    latexChar = "\\csc^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'sec⁻¹':    latexChar = "\\sec^{-1}\\left(\\placeholder{}\\right)"; break;
      case 'cot⁻¹':    latexChar = "\\cot^{-1}\\left(\\placeholder{}\\right)"; break;



      case 'integral': latexChar = "\\int_{\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)dx"; break;
      case 'indef_integral': latexChar = "\\int\\left(\\placeholder{}\\right)dx"; break;
      case 'sum':      latexChar = "\\sum_{x=\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
      case 'product':  latexChar = "\\prod_{x=\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
      case 'd/dx':     latexChar = "\\frac{d}{dx}\\left(\\placeholder{}\\right)"; break;
      case 'lim':      latexChar = "\\lim_{x \\to \\placeholder{}}\\left(\\placeholder{}\\right)"; break;
      case '%':        latexChar = '\\%'; break;
      case 'mod':      latexChar = '\\bmod '; break;
      case 'GCD':      latexChar = '\\gcd\\left(\\placeholder{}, \\placeholder{}\\right)'; break;
      case 'LCM':      latexChar = '\\operatorname{lcm}\\left(\\placeholder{}, \\placeholder{}\\right)'; break;

      case 'nCr':
        let combTemplates = [
          "\\binom{\\placeholder{}}{\\placeholder{}}",                 // 0: 国际规范 \binom{n}{r}
          "\\mathrm{C}_{\\placeholder{}}^{\\placeholder{}}",           // 1: C角标 Cₙᵏ C_n^r
          "{}^{\\placeholder{}}\\mathrm{C}_{\\placeholder{}}",         // 2: 左上标 ⁿCᵣ ^nC_r
          "{}_{\\placeholder{}}\\mathrm{C}_{\\placeholder{}}",         // 3: 左下标 ₙCᵣ _nC_r
          "\\mathrm{C}\\left(\\placeholder{}, \\placeholder{}\\right)" // 4: 平铺 C(n,r)
        ];
        latexChar = combTemplates[combSelect];
        break;

      case 'nPr':
        let permTemplates = [
          "\\mathrm{A}_{\\placeholder{}}^{\\placeholder{}}",           // 0: A角标 Aₙᵏ A_n^r
          "\\mathrm{P}_{\\placeholder{}}^{\\placeholder{}}",           // 1: P角标 Pₙʳ P_n^r
          "{}^{\\placeholder{}}\\mathrm{P}_{\\placeholder{}}",         // 2: 左上标 ⁿPᵣ ^nP_r
          "{}_{\\placeholder{}}\\mathrm{P}_{\\placeholder{}}",         // 3: 左下标 ₙPᵣ _nP_r
          "\\mathrm{P}\\left(\\placeholder{}, \\placeholder{}\\right)" // 4: 平铺 P(n,r)
        ];
        latexChar = permTemplates[permSelect];
        break;

      // ================= 矩阵与向量专属算子 =================
      // 1. 矩阵属性与变换
      case 'M⁻¹':      latexChar = "^{-1}"; break;
      case 'Mᵀ':       latexChar = "^{\\mathrm{T}}"; break;
      case 'Mᴴ':       latexChar = "^{\\mathrm{H}}"; break;
      case 'M_power':  latexChar = "^{\\placeholder{}}"; break; // 和普通的 power 一样，触发上标输入
      // 2. 高级线性代数运算
      case 'det':      latexChar = "\\det\\left(\\placeholder{}\\right)"; break;
      case 'rref':     latexChar = "\\operatorname{rref}\\left(\\placeholder{}\\right)"; break;
      case 'eig':      latexChar = "\\operatorname{eig}\\left(\\placeholder{}\\right)"; break;
      case 'rank':     latexChar = "\\operatorname{rank}\\left(\\placeholder{}\\right)"; break;
      case 'tr':       latexChar = "\\operatorname{tr}\\left(\\placeholder{}\\right)"; break;

      // 3. 特殊常量
      case 'I':        latexChar = "\\operatorname{I}_{\\placeholder{}}"; break;

      // =============== 方程求解 ===============
      case 'cases':    latexChar = "\\begin{cases} \\placeholder{} \\\\ \\placeholder{} \\end{cases}"; break;
      case 'cases_3':  latexChar = "\\begin{cases} \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\end{cases}"; break;
      case 'cases_4':  latexChar = "\\begin{cases} \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\end{cases}"; break;
      case 'cases_5':  latexChar = "\\begin{cases} \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\end{cases}"; break;
      case 'cases_6':  latexChar = "\\begin{cases} \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\\\ \\placeholder{} \\end{cases}"; break;
    }
    return latexChar;
  }
}