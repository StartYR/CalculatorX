import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
  }

  async onRun(): Promise<void> {
    const arguments_ = abilityDelegatorRegistry.getArguments();
    const want: Want = {
      bundleName: arguments_.bundleName,
      abilityName: 'CalculationTestAbility'
    };
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);
  }
}
