/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file UnitConverter.ets
 * @description 请在此处输入文件描述...
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:53
 */

@Component
export struct UnitConverter {
  build() {
    Column() {
      Text('当前模块正在开发中...')
        .fontSize(18)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}