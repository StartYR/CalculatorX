// entry/src/main/ets/utils/HapticUtils.ets
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class HapticUtils {
  /**
   * 触发按键触感反馈
   * @param action 按键的 actionId
   * @param hapticFeedback 是否开启触感反馈
   * @param vibrationCurve 振动风格 (0:自动, 1:清脆, 2:轻柔, 3:厚重)
   */
  public static playVibration(action: string, hapticFeedback: boolean, vibrationCurve: number): void {
    // 1. 判断“触感反馈”总开关是否打开
    if (!hapticFeedback) return;

    let effectId = 'haptic.effect.sharp'; // 声明默认效果

    if (vibrationCurve === 0) {
      // 自动模式（基于按键类型的差异化震动）
      if (action === '=' || action === 'AC' || action === '⌫') {
        // 高权重操作：hard
        effectId = 'haptic.effect.hard';
      } else if (['+', '-', '×', '÷'].includes(action as string)) {
        // 运算符操作：sharp
        effectId = 'haptic.effect.sharp';
      } else {
        // 普通数字与函数：soft
        effectId = 'haptic.effect.soft';
      }

    } else {
      // 全局统一震感（用户选择）
      if (vibrationCurve === 1) {
        effectId = 'haptic.effect.sharp';
      } else if (vibrationCurve === 2) {
        effectId = 'haptic.effect.soft';
      } else if (vibrationCurve === 3) {
        effectId = 'haptic.effect.hard';
      }
    }

    // 触发系统原生震动
    vibrator.startVibration({
      type: 'preset',
      effectId: effectId,
      count: 1
    }, { usage: 'touch' }).catch((err: BusinessError) => {
      console.warn(`震动拦截: ${err.message}`);
    });
  }
}