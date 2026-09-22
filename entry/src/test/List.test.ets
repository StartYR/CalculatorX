import localUnitTest from './LocalUnit.test';
import keyboardVisualPolicyTest from './KeyboardVisualPolicy.test';
import programmerTest from './Programmer.test';

export default function testsuite() {
  localUnitTest();
  keyboardVisualPolicyTest();
  programmerTest();
}
