/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file Logger.ets
 * @description 日志模板
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/25 17:02
 */

import hilog from '@ohos.hilog';

class Logger {
  private domain: number;
  private prefix: string;
  // 生产环境总开关：打包 Release 前，把 isDebug 设为 false
  private isDebug: boolean = true;

  constructor(prefix: string) {
    this.prefix = prefix;
    this.domain = 0x0000; // 官方建议的默认 Domain
  }

  debug(...args: Object[]) {
    if (this.isDebug) {
      hilog.debug(this.domain, this.prefix, '%{public}s', args.map(String).join(' '));
    }
  }

  info(...args: Object[]) {
    if (this.isDebug) {
      hilog.info(this.domain, this.prefix, '%{public}s', args.map(String).join(' '));
    }
  }

  warn(...args: Object[]) {
    hilog.warn(this.domain, this.prefix, '%{public}s', args.map(String).join(' '));
  }

  error(...args: Object[]) {
    hilog.error(this.domain, this.prefix, '%{public}s', args.map(String).join(' '));
  }
}

// 导出单例，方便全局使用
export default new Logger('CalcX_ArkTS');