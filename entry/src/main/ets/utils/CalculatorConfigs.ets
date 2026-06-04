// entry/src/main/ets/utils/CalculatorConfigs.ets

// ========== 1. SVG 资源定义 ==========
export const icon_sum: Resource = $rawfile('math-icons/icon_sum.svg');
export const icon_product: Resource = $rawfile('math-icons/icon_product.svg');
export const icon_integral: Resource = $rawfile('math-icons/icon_integral.svg');
export const icon_abs: Resource = $rawfile('math-icons/icon_abs.svg');
export const icon_sqrt: Resource = $rawfile('math-icons/icon_sqrt.svg');
export const icon_sqrt3: Resource = $rawfile('math-icons/icon_sqrt3.svg');
export const icon_sqrtx: Resource = $rawfile('math-icons/icon_sqrtx.svg');
export const icon_power2: Resource = $rawfile('math-icons/icon_power2.svg');
export const icon_power: Resource = $rawfile('math-icons/icon_power.svg');
export const icon_fraction: Resource = $rawfile('math-icons/icon_fraction.svg');

export class MathIcons {
  // 组合 (Combination)
  static readonly COMB_SUBSUP = $rawfile('math-icons/comb/icon_comb_subsup.svg'); // C角标 Cₙᵏ C_n^r
  static readonly COMB_BINOM = $rawfile('math-icons/comb/icon_comb_binom.svg'); // 国际规范 \binom{n}{r}
  static readonly COMB_CALC = $rawfile('math-icons/comb/icon_comb_calc.svg'); // 左上标 ⁿCᵣ ^nC_r
  static readonly COMB_CALC2 = $rawfile('math-icons/comb/icon_comb_calc2.svg'); // 左下标 ₙCᵣ _nC_r
  static readonly COMB_INLINE = $rawfile('math-icons/comb/icon_comb_inline.svg'); // 平铺 C(n,r)

  // 排列 (Permutation)
  static readonly PERM_A = $rawfile('math-icons/perm/icon_perm_a.svg'); // A角标 Aₙᵏ A_n^r
  static readonly PERM_P = $rawfile('math-icons/perm/icon_perm_p.svg'); // P角标 Pₙʳ P_n^r
  static readonly PERM_CALC = $rawfile('math-icons/perm/icon_perm_calc.svg'); // 左上标 ⁿPᵣ ^nP_r
  static readonly PERM_CALC2 = $rawfile('math-icons/perm/icon_perm_calc2.svg'); // 左下标 ₙPᵣ _nP_r
  static readonly PERM_INLINE = $rawfile('math-icons/perm/icon_perm_inline.svg'); // 平铺 P(n,r)
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

// ========== 2. 键盘布局数组 ==========
export const topButtons: Array<string | Resource> = [
  '⇧Shift', 'R/D', '⇦', '⇨', 'Ans', 'i',
  'lim', 'd/dx', icon_sum, icon_product, icon_integral, '∞',
  'x⁻¹', '!', 'nCr', 'nPr', 'ln', 'log',
  icon_abs, icon_sqrt, icon_sqrtx, icon_power2, icon_power, icon_fraction,
  'sin', 'cos', 'tan', ',', '(', ')',
];

export const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  '', '', '', '', '', '',
  '', '', '', '', 'eˣ', '10ˣ',
  '', icon_sqrt3, '', '', '', '',
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '[', ']',
];

export const bottomButtons: string[] = [
  '7', '8', '9', '⌫', 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'e', 'π', '=',
];

// ========== 3. 样式映射函数 ==========
export function getActionId(btn: string | Resource): string {
  if (typeof btn === 'string') return btn;
  if (btn === icon_fraction) return 'fraction';
  if (btn === icon_sqrt) return 'sqrt';
  if (btn === icon_sqrt3) return 'sqrt3';
  if (btn === icon_sqrtx) return 'sqrtx';
  if (btn === icon_power2) return 'power2';
  if (btn === icon_power) return 'power';
  if (btn === icon_abs) return 'abs';
  if (btn === icon_sum) return 'sum';
  if (btn === icon_product) return 'product';
  if (btn === icon_integral) return 'integral';
  return '';
}

// 全局路径
export class RoutePath {
  static readonly INDEX = 'pages/Index';
  static readonly SETTINGS = 'pages/settings/Settings';
  static readonly ABOUT = 'pages/settings/About';
  static readonly DOC_VIEWER = 'pages/DocViewer';
}

export function getFontFamily(btn: string | Resource): string {
  if (typeof btn !== 'string') return 'HarmonyOS Sans';
  if (['AC', '⌫', '='].includes(btn)) return 'HarmonyOS Sans';
  if (['y', 'z', 'i', 'e', 'π', 'ln', 'log'].includes(btn)) return 'Cambria Italic';
  return 'Cambria Math';
}

export function getBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  let action = getActionId(btn);

  if (action === 'AC' || action === '⌫') return '#ffff5d3e';
  if (action === '⇧Shift') return isShift ? '#ffb87200' : '#ff9900';
  if (action === '=') return $r('sys.color.comp_background_emphasize');
  if (['+', '−', '×', '÷'].includes(action)) return $r('sys.color.comp_background_tertiary');

  let isNumberOrCore = (typeof btn === 'string' && btn >= '0' && btn <= '9') || action === '.' || action === 'e' || action === 'π' || action === 'Ans';
  if (isNumberOrCore) return $r('sys.color.comp_background_primary');

  return $r('sys.color.comp_background_secondary');
}

export function getFontSize(btn: string | Resource): number {
  if (typeof btn !== 'string') return 14;
  if (btn >= '0' && btn <= '9') return 24;
  if (btn === '−') return 28;
  if (btn === '+' || btn === '×' || btn === '÷' || btn === '=' || btn === 'π' || btn === 'e' || btn === '.') return 28;
  if (['sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'd/dx', 'lim'].includes(btn)) return 20;
  if (['sin', 'cos', 'tan', 'log', 'ln'].includes(btn)) return 20;
  if (btn === 'AC' || btn === '⌫') return 20;
  if (btn === '⇦'|| btn === '⇨') return 30;
  if (btn === '⇧Shift') return 16;
  return 20;
}

export function getFontColor(btn: string | Resource): ResourceColor {
  let action = getActionId(btn);

  // 1. 在红色、蓝色、橙色等重色彩背景上，强制使用反色文字 (纯白)，保证绝对清晰
  if (['AC', '⌫', '=', '⇧Shift'].includes(action)) return $r('sys.color.font_on_primary');

  // 2. SVG 图标：使用主要文字色
  if (typeof btn !== 'string') return $r('sys.color.font_primary');

  // 3. 右侧运算符：为了让界面更灵动，在灰色背景上使用系统强调色 (蓝色文字)
  if (['+', '−', '×', '÷'].includes(action)) return $r('sys.color.font_emphasize');

  // 4. 顶部高级功能区：次要文字颜色 (略微弱化，将视觉焦点让给下方数字区)
  if (topButtons.includes(btn as string)) return $r('sys.color.font_secondary');

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
}