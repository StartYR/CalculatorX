import localUnitTest from './LocalUnit.test';
import keyboardVisualPolicyTest from './KeyboardVisualPolicy.test';

export default function testsuite() {
  localUnitTest();
  keyboardVisualPolicyTest();
}
