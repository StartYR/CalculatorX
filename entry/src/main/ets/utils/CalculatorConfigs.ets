/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file CalculatorConfigs.ets
 * @description 全局配置与状态映射
 * * @author 易睿 (Yi Rui)
 * @date 2026
 */

// ========== SVG 资源定义 ==========
export const icon_backspace: Resource = $rawfile('icons/icon_backspace.svg');
export const icon_sum: Resource = $rawfile('icons/math/icon_sum.svg');
export const icon_product: Resource = $rawfile('icons/math/icon_product.svg');
export const icon_integral: Resource = $rawfile('icons/math/icon_integral.svg');
export const icon_indef_integral: Resource = $rawfile('icons/math/icon_indef_integral.svg');
export const icon_abs: Resource = $rawfile('icons/math/icon_abs.svg');
export const icon_sqrt: Resource = $rawfile('icons/math/icon_sqrt.svg');
export const icon_sqrt3: Resource = $rawfile('icons/math/icon_sqrt3.svg');
export const icon_sqrtx: Resource = $rawfile('icons/math/icon_sqrtx.svg');
export const icon_power2: Resource = $rawfile('icons/math/icon_power2.svg');
export const icon_power: Resource = $rawfile('icons/math/icon_power.svg');
export const icon_fraction: Resource = $rawfile('icons/math/icon_fraction.svg');
export const icon_power3: Resource = $rawfile('icons/math/icon_power3.svg');
export const icon_exp: Resource = $rawfile('icons/math/icon_exp.svg');
export const icon_inverse: Resource = $rawfile('icons/math/icon_inverse.svg');
export const icon_e_power: Resource = $rawfile('icons/math/icon_e_power.svg');
export const icon_comma: Resource = $rawfile('icons/math/icon_comma.svg');
export const icon_fact: Resource = $rawfile('icons/math/icon_fact.svg');
export const icon_dim: Resource = $rawfile('icons/matrix/icon_dim.svg');

export class MathIcons {
  // 组合 (Combination)
  static readonly COMB_SUBSUP = $rawfile('icons/math/comb/icon_comb_subsup.svg'); // C角标 Cₙᵏ C_n^r
  static readonly COMB_BINOM = $rawfile('icons/math/comb/icon_comb_binom.svg'); // 国际规范 \binom{n}{r}
  static readonly COMB_CALC = $rawfile('icons/math/comb/icon_comb_calc.svg'); // 左上标 ⁿCᵣ ^nC_r
  static readonly COMB_CALC2 = $rawfile('icons/math/comb/icon_comb_calc2.svg'); // 左下标 ₙCᵣ _nC_r
  static readonly COMB_INLINE = $rawfile('icons/math/comb/icon_comb_inline.svg'); // 平铺 C(n,r)

  // 排列 (Permutation)
  static readonly PERM_A = $rawfile('icons/math/perm/icon_perm_a.svg'); // A角标 Aₙᵏ A_n^r
  static readonly PERM_P = $rawfile('icons/math/perm/icon_perm_p.svg'); // P角标 Pₙʳ P_n^r
  static readonly PERM_CALC = $rawfile('icons/math/perm/icon_perm_calc.svg'); // 左上标 ⁿPᵣ ^nP_r
  static readonly PERM_CALC2 = $rawfile('icons/math/perm/icon_perm_calc2.svg'); // 左下标 ₙPᵣ _nP_r
  static readonly PERM_INLINE = $rawfile('icons/math/perm/icon_perm_inline.svg'); // 平铺 P(n,r)
}

// 定义选项的数据结构
export interface MathStyleOption {
  id: number;           // 对应存入 Preferences 的 index
  name: string;         // 列表里显示的文字名称
  icon: Resource;       // 对应的 SVG 预览图
  latexTemplate: string;// 对应的 LaTeX 源码（为以后的底层翻译器做准备）
  description: string;  // 描述
}

// 组合的 5 种样式配置
export const CombinationOptions: MathStyleOption[] = [
  { id: 0, name: '国际学术规范', description: '二项式系数，微积分及国际学术论文通用', icon: MathIcons.COMB_BINOM,  latexTemplate: '\\binom{n}{r}' },
  { id: 1, name: 'C - 角标写法', description: '随前苏联的数学体系传入中国，国内中学教材通用标准', icon: MathIcons.COMB_SUBSUP, latexTemplate: '\\mathrm{C}_{n}^{r}' },
  { id: 2, name: '现代计算器风格 (左上标)', description: 'Casio 等主流实体科学计算器显示风格', icon: MathIcons.COMB_CALC,   latexTemplate: '{}^{n}\\mathrm{C}_{r}' },
  { id: 3, name: '早期计算器风格 (左下标)', description: 'TI 及部分早期科学计算器显示风格', icon: MathIcons.COMB_CALC2,  latexTemplate: '{}_{n}\\mathrm{C}_{r}' },
  { id: 4, name: '平铺函数风格', description: '计算机编程、离散数学及纯文本环境规范', icon: MathIcons.COMB_INLINE, latexTemplate: '\\mathrm{C}(n, r)' }
];

// 排列的 5 种样式配置
export const PermutationOptions: MathStyleOption[] = [
  { id: 0, name: 'A - 角标写法', description: '源自法语 Arrangement，非英语国家的通用写法', icon: MathIcons.PERM_A,      latexTemplate: '\\mathrm{A}_{n}^{r}' },
  { id: 1, name: 'P - 角标写法', description: '源自英语 Permutation，英语国家的通用写法', icon: MathIcons.PERM_P,      latexTemplate: '\\mathrm{P}_{n}^{r}' },
  { id: 2, name: '现代计算器风格 (左上标)', description: 'Casio 等主流实体科学计算器按键风格', icon: MathIcons.PERM_CALC,   latexTemplate: '{}^{n}\\mathrm{P}_{r}' },
  { id: 3, name: '早期计算器风格 (左下标)', description: 'TI 及部分早期科学计算器显示风格', icon: MathIcons.PERM_CALC2,  latexTemplate: '{}_{n}\\mathrm{P}_{r}' },
  { id: 4, name: '平铺函数风格', description: '计算机编程、离散数学及纯文本环境规范', icon: MathIcons.PERM_INLINE, latexTemplate: '\\mathrm{P}(n, r)' }
];

/**
 * 样式映射函数
 */
export function getActionId(btn: string | Resource): string {
  if (typeof btn === 'string') return btn;
  if (btn === icon_backspace) return '⌫';
  if (btn === icon_fraction) return 'fraction';
  if (btn === icon_sqrt) return 'sqrt';
  if (btn === icon_sqrt3) return 'sqrt3';
  if (btn === icon_sqrtx) return 'sqrtx';
  if (btn === icon_power2) return 'power2';
  if (btn === icon_power3) return 'power3';
  if (btn === icon_power) return 'power';
  if (btn === icon_abs) return 'abs';
  if (btn === icon_sum) return 'sum';
  if (btn === icon_product) return 'product';
  if (btn === icon_integral) return 'integral';
  if (btn === icon_indef_integral) return 'indef_integral';
  if (btn === icon_exp) return 'icon_exp';
  if (btn === icon_inverse) return 'inverse';
  if (btn === icon_e_power) return 'e_power';
  if (btn === icon_comma) return 'comma';
  if (btn === icon_fact) return 'fact';
  if (btn === icon_dim) return 'dim';
  return '';
}

/**
 * 全局路径
 */
export class RoutePath {
  static readonly INDEX = 'pages/Index';
  static readonly SETTINGS = 'pages/settings/Settings';
  static readonly ABOUT = 'pages/settings/About';
  static readonly DOC_VIEWER = 'pages/DocViewer';
  static readonly HISTORY = 'pages/history/HistoryManager';
  static readonly HELP = 'pages/HelpDocs';
}

/**
 * 字体样式
 */
export function getFontFamily(btn: string | Resource): string {
  if (typeof btn !== 'string') return 'HarmonyOS Sans';
  if (['AC', '⌫', '='].includes(btn)) return 'HarmonyOS Sans';
  if (['a', 'b', 'c', 'd', 'm', 'n', 'x', 'y', 'z', 'i', 'e', 'π'].includes(btn)) return 'Cambria Italic';
  return 'Cambria Math';
}

/**
 * 按钮颜色
 */
export function getBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  let action = getActionId(btn);
  if (action === 'AC' || action === '⌫') return '#ffff5d3e';
  if (action === '⇧Shift') return isShift ? '#ffb87200' : '#ff9900';
  if (action === '=') return $r('sys.color.comp_background_emphasize');
  if (['+', '−', '×', '÷'].includes(action)) return $r('sys.color.comp_background_tertiary');

  let isNumberOrCore = (typeof btn === 'string' && btn >= '0' && btn <= '9') || action === '.' || action === 'dim' || action === '⇦'|| action === '⇨' || btn === '⇧'|| btn === '⇩';
  if (isNumberOrCore || action === 'icon_exp') return $r('sys.color.comp_background_primary');

  return $r('sys.color.comp_background_secondary');
}

/**
 * 字体大小
 */
export function getFontSize(btn: string | Resource): number {
  if (typeof btn !== 'string') return 14;
  if (btn >= '0' && btn <= '9') return 24;
  if (btn === 'e' || btn === 'Ans' || btn === 'Dim') return 22;
  if (btn === '+' || btn === '×' || btn === '÷' || btn === '=' || btn === '−' || btn === '.') return 28;
  if (['d/dx', 'lim'].includes(btn)) return 20;
  if (['sin', 'cos', 'tan', 'log', 'ln'].includes(btn)) return 20;
  if (btn === 'AC' || btn === '⌫') return 20;
  if (btn === '⇦'|| btn === '⇨') return 30;
  if (btn === '⇧'|| btn === '⇩') return 27;
  if (btn === '⇧Shift') return 16;
  return 20;
}

/**
 * 字体颜色
*/
export function getFontColor(btn: string | Resource): ResourceColor {
  let action = getActionId(btn);

  // 1. 使用反色文字
  if (['AC', '⌫', '=', '⇧Shift'].includes(action)) return $r('sys.color.font_on_primary');

  // 2. SVG 图标：使用主要文字色
  if (typeof btn !== 'string') return $r('sys.color.font_primary');

  // 3. 右侧运算符：在灰色背景上使用系统强调色 (蓝色文字)
  if (['+', '−', '×', '÷'].includes(action)) return $r('sys.color.font_emphasize');

  // 4. 顶部高级功能区：次要文字颜色 (略微弱化，将视觉焦点让给下方数字区)
  // if (topButtons.includes(btn as string)) return $r('sys.color.font_secondary');
  let isPrimaryText = (typeof btn === 'string' && btn >= '0' && btn <= '9') ||
    ['.', '%', 'Dim'].includes(action);
  if (!isPrimaryText) return $r('sys.color.font_secondary');

  // 5. 核心数字区：主要文字颜色
  return $r('sys.color.font_primary');
}

export class PreferenceConfigs {
  static readonly STORE_NAME = 'CalcX_Preferences';
  static readonly KEY_COLOR_MODE = 'colorModeIndex';
  static readonly KEY_VIBRATION_CURVE = 'vibrationCurve';
  static readonly KEY_IS_RAD = 'isRad';
  static readonly KEY_DECIMAL_PRECISION = 'decimalPrecision';
  static readonly KEY_ANSWER_OUTPUT_MODE = 'answerOutputMode';
  static readonly KEY_COMBINATION_SELECT = 'combinationSelectIndex';
  static readonly KEY_PERMUTATION_SELECT = 'permutationSelectIndex';
  static readonly KEY_HAPTIC_FEEDBACK = 'hapticFeedback';

  // 启动页面配置
  static readonly KEY_STARTUP_PAGE = 'startupPageMode';
  static readonly KEY_LAST_USED_MODULE = 'lastUsedModule';
}

// 长按菜单
export interface CustomMenuItem {
  value: string;
  actionCode: string; // 传给后端的独立控制码
}

export const keyContextMenuRegistry: Record<string, CustomMenuItem[]> = {
  'S⇄D': [
    { value: '小数', actionCode: 'LONG_SD_DEC' },
    { value: '分数', actionCode: 'LONG_SD_FRAC' },
    { value: '带分数', actionCode: 'LONG_SD_MIXED' },
    { value: '度分秒', actionCode: 'LONG_SD_DMS' }
  ],

  // 其他按键（例如 Ans、sin、log）需要长按时，直接在这里追加一行即可！
  // 'Ans': [{ value: '清除历史记录', actionCode: 'CLEAR_HISTORY' }]
};