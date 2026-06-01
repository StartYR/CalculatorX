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
  '1', '2', '3', '+', '-',
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
  if (['+', '-', '×', '÷'].includes(action)) return $r('sys.color.comp_background_tertiary');

  let isNumberOrCore = (typeof btn === 'string' && btn >= '0' && btn <= '9') || action === '.' || action === 'e' || action === 'π' || action === 'Ans';
  if (isNumberOrCore) return $r('sys.color.comp_background_primary');

  return $r('sys.color.comp_background_secondary');
}

export function getFontSize(btn: string | Resource): number {
  if (typeof btn !== 'string') return 14;
  if (btn >= '0' && btn <= '9') return 24;
  if (btn === '+' || btn === '-' || btn === '×' || btn === '÷' || btn === '=' || btn === 'π' || btn === 'e' || btn === '.') return 28;
  if (['sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'd/dx', 'lim'].includes(btn)) return 20;
  if (['sin', 'cos', 'tan', 'log', 'ln'].includes(btn)) return 20;
  if (['∫', '∑', '∏', '∞'].includes(btn)) return 22;
  if (['eˣ', '10ˣ'].includes(btn)) return 18;
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
  if (['+', '-', '×', '÷'].includes(action)) return $r('sys.color.font_emphasize');

  // 4. 顶部高级功能区：次要文字颜色 (略微弱化，将视觉焦点让给下方数字区)
  if (topButtons.includes(btn as string)) return $r('sys.color.font_secondary');

  // 5. 核心数字区：主要文字颜色
  return $r('sys.color.font_primary');
}