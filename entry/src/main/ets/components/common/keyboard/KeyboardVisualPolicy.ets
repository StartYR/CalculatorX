import { getActionId } from '../../../utils/CalculatorConfigs';
import { KeyboardKeyRole, KeyboardKeySpec } from './KeyboardKeyTypes';

const OPERATOR_ACTIONS: string[] = ['+', '−', '×', '÷', '∘', 'Ans', '⌨⇩'];
const CORE_ACTIONS: string[] = ['.', 'dim', '⇦', '⇨', '⇧', '⇩', 'icon_exp'];

export function resolveKeyboardKeyRole(
  content: string | Resource,
  emphasisActions: string[] = ['=', 'EXE', '确定'],
  extraCoreActions: string[] = []
): KeyboardKeyRole {
  const action = getActionId(content);
  if (action === 'AC' || action === '⌫') return KeyboardKeyRole.DANGER;
  if (emphasisActions.includes(action)) return KeyboardKeyRole.EMPHASIS;
  if (action === '⇧Shift') return KeyboardKeyRole.SHIFT;

  const isNumber = typeof content === 'string' && content >= '0' && content <= '9';
  if (isNumber || CORE_ACTIONS.includes(action) || extraCoreActions.includes(action)) {
    return KeyboardKeyRole.CORE;
  }
  if (OPERATOR_ACTIONS.includes(action)) return KeyboardKeyRole.OPERATOR;
  return KeyboardKeyRole.FUNCTION;
}

export function createKeyboardKeySpec(
  content: string | Resource,
  emphasisActions: string[] = ['=', 'EXE', '确定'],
  extraCoreActions: string[] = []
): KeyboardKeySpec {
  return {
    content: content,
    actionId: getActionId(content),
    role: resolveKeyboardKeyRole(content, emphasisActions, extraCoreActions)
  };
}

export function getLegacyKeyboardBackground(role: KeyboardKeyRole, shiftActive: boolean): ResourceColor {
  if (role === KeyboardKeyRole.DANGER) return '#ffff5d3e';
  if (role === KeyboardKeyRole.EMPHASIS) return $r('sys.color.comp_background_emphasize');
  if (role === KeyboardKeyRole.SHIFT) return shiftActive ? '#ffb87200' : '#ff9900';
  if (role === KeyboardKeyRole.OPERATOR) return $r('sys.color.comp_background_tertiary');
  if (role === KeyboardKeyRole.FUNCTION) return $r('sys.color.comp_background_secondary');
  return $r('sys.color.comp_background_primary');
}
