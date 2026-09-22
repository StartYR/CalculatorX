import { describe, it, expect } from '@ohos/hypium';
import { KeyboardKeyRole } from '../main/ets/components/common/keyboard/KeyboardKeyTypes';
import {
  createKeyboardKeySpec,
  resolveKeyboardKeyRole
} from '../main/ets/components/common/keyboard/KeyboardVisualPolicy';

export default function keyboardVisualPolicyTest() {
  describe('keyboardVisualPolicy', () => {
    it('resolvesBuiltInRoles', 0, () => {
      expect(resolveKeyboardKeyRole('7')).assertEqual(KeyboardKeyRole.CORE);
      expect(resolveKeyboardKeyRole('+')).assertEqual(KeyboardKeyRole.OPERATOR);
      expect(resolveKeyboardKeyRole('sin')).assertEqual(KeyboardKeyRole.FUNCTION);
      expect(resolveKeyboardKeyRole('AC')).assertEqual(KeyboardKeyRole.DANGER);
      expect(resolveKeyboardKeyRole('=')).assertEqual(KeyboardKeyRole.EMPHASIS);
      expect(resolveKeyboardKeyRole('⇧Shift')).assertEqual(KeyboardKeyRole.SHIFT);
    });

    it('honorsModuleOverrides', 0, () => {
      expect(resolveKeyboardKeyRole('=', ['EXE'], ['π'], ['=']))
        .assertEqual(KeyboardKeyRole.OPERATOR);
      expect(resolveKeyboardKeyRole('π', ['EXE'], ['π'], ['=']))
        .assertEqual(KeyboardKeyRole.CORE);
      expect(resolveKeyboardKeyRole('EXE', ['EXE'], ['π'], ['=']))
        .assertEqual(KeyboardKeyRole.EMPHASIS);
    });

    it('createsStableKeySpec', 0, () => {
      const spec = createKeyboardKeySpec('确定', ['确定']);
      expect(spec.content).assertEqual('确定');
      expect(spec.actionId).assertEqual('确定');
      expect(spec.role).assertEqual(KeyboardKeyRole.EMPHASIS);
    });
  });
}
