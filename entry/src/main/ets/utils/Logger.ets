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
  private isDebug: boolean = true;

  constructor(prefix: string) {
    this.prefix = prefix;
    this.domain = 0x0000;
  }

  debug(msg: string) {
    if (this.isDebug) {
      hilog.debug(this.domain, this.prefix, '%{public}s', msg);
    }
  }

  info(msg: string) {
    if (this.isDebug) {
      hilog.info(this.domain, this.prefix, '%{public}s', msg);
    }
  }

  warn(msg: string) {
    hilog.warn(this.domain, this.prefix, '%{public}s', msg);
  }

  error(msg: string) {
    hilog.error(this.domain, this.prefix, '%{public}s', msg);
  }
}

export default new Logger('CalcX_ArkTS');