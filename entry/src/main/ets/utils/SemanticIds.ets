/** Stable, locale-independent identifiers exposed to CalculatorX UI automation. */
export class SemanticIds {
  static readonly PAGE_INDEX = 'app.page.index';
  static readonly PAGE_SETTINGS = 'app.page.settings';
  static readonly PAGE_HISTORY = 'app.page.history';
  static readonly FORMULA = 'calc.formula';
  static readonly SIDEBAR = 'overlay.sidebar';
  static readonly SIDEBAR_DISMISS = 'overlay.sidebar.dismiss';
  static readonly NAV_SIDEBAR_OPEN = 'nav.sidebar.open';
  static readonly NAV_UNDO = 'nav.undo';
  static readonly NAV_REDO = 'nav.redo';
  static readonly NAV_HISTORY_SHEET = 'nav.history.sheet';
  static readonly NAV_HISTORY_PAGE = 'nav.history.page';
  static readonly NAV_SETTINGS = 'nav.settings';
  static readonly NAV_GRAPHING_EDIT = 'nav.graphing.edit';
}

const KEY_NAMES: Record<string, string> = {
  '+': 'plus',
  '−': 'minus',
  '×': 'multiply',
  '÷': 'divide',
  '=': 'equals',
  'AC': 'clear',
  '⌫': 'backspace',
  '.': 'decimal',
  '%': 'percent',
  'Ans': 'ans',
  '⇧Shift': 'shift',
  '⇦': 'cursor-left',
  '⇨': 'cursor-right',
  '⇧': 'cursor-up',
  '⇩': 'cursor-down',
  'R/D': 'angle-toggle',
  'S⇄D': 'format-toggle',
  'π': 'pi',
  '∞': 'infinity',
  '(': 'left-parenthesis',
  ')': 'right-parenthesis',
  '° \' "': 'dms',
  'fraction': 'fraction',
  'sqrt': 'square-root',
  'sqrt3': 'cube-root',
  'sqrtx': 'nth-root',
  'power2': 'square',
  'power3': 'cube',
  'power': 'power',
  'icon_exp': 'scientific-exponent',
  'inverse': 'inverse',
  'abs': 'absolute',
  'sum': 'sum',
  'product': 'product',
  'integral': 'integral',
  'indef_integral': 'indefinite-integral',
  'comma': 'comma',
  'fact': 'factorial',
  'nCr': 'combination',
  'nPr': 'permutation'
};

export function getCalculatorKeySemanticId(actionId: string): string {
  if (/^[0-9]$/.test(actionId)) {
    return `calc.key.${actionId}`;
  }
  const readableName = KEY_NAMES[actionId];
  if (readableName) {
    return `calc.key.${readableName}`;
  }
  if (/^[A-Za-z][A-Za-z0-9_-]*$/.test(actionId)) {
    return `calc.key.${actionId.toLowerCase()}`;
  }
  let encoded = '';
  for (let index = 0; index < actionId.length; index++) {
    encoded += actionId.charCodeAt(index).toString(16);
  }
  return `calc.key.u-${encoded || 'empty'}`;
}

export function getModuleSemanticId(module: string): string {
  return `module.${module}`;
}
