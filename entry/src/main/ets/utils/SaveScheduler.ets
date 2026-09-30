/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file SaveScheduler.ets
 * @description 输入保存的防抖、最长等待与生命周期收尾
 * @author StartYi
 * @date 2026/09/30 14:00
 */
export class SaveScheduler {
  private debounceTimer: number = -1;
  private maximumTimer: number = -1;
  private pending: boolean = false;
  private save: () => void;
  private delayMs: number;
  private maximumMs: number;

  constructor(save: () => void, delayMs: number, maximumMs: number = 2000) {
    this.save = save;
    this.delayMs = delayMs;
    this.maximumMs = maximumMs;
  }

  schedule(): void {
    this.pending = true;
    if (this.debounceTimer !== -1) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout((): void => this.flush(), this.delayMs);
    // 连续输入只延后防抖计时，最长等待从第一次未保存输入开始计算。
    if (this.maximumTimer === -1) {
      this.maximumTimer = setTimeout((): void => this.flush(), this.maximumMs);
    }
  }

  flush(): void {
    if (this.debounceTimer !== -1) clearTimeout(this.debounceTimer);
    if (this.maximumTimer !== -1) clearTimeout(this.maximumTimer);
    this.debounceTimer = -1;
    this.maximumTimer = -1;
    const pending = this.pending;
    this.pending = false;
    if (pending) this.save();
  }
}
