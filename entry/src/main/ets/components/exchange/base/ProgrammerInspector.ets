/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file ProgrammerInspector.ets
 * @description 位编辑、整数编码与浮点字段观察
 */
import { ProgrammerSession } from '../../../utils/base/ProgrammerSession';
import { encodingRows, decodeEncoding, EncodingRow } from '../../../utils/base/ProgrammerEngine';
import { FloatFormat, decodeFloat } from '../../../utils/base/Ieee754';
import { Natural } from '../../../utils/base/Natural';

@Component
export struct ProgrammerInspector {
  @Prop session: ProgrammerSession = new ProgrammerSession();
  @Prop panel: string = 'bits';
  onFlip: (index: number) => void = () => {};

  private indices(): number[] {
    const result: number[] = [];
    const width = this.session.mode === 'integer' ? this.session.width : this.session.floatWidth;
    for (let i = width - 1; i >= 0; i--) result.push(i);
    return result;
  }
  private bit(index: number): number {
    return this.session.mode === 'integer' ? this.session.word.value.bit(index) : this.session.floatBits.bit(index);
  }
  private fieldColor(index: number): ResourceColor {
    if (this.session.mode === 'integer') return $r('sys.color.font_emphasize');
    const format = new FloatFormat(this.session.floatWidth);
    return index === format.width - 1 ? $r('sys.color.warning') :
      index >= format.fractionBits ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary');
  }

  private ranges(): string {
    const sign = Natural.small(1).shift(this.session.width - 1);
    const maximum = sign.subtract(Natural.small(1)).toString();
    return '无符号：0 … ' + sign.shift(1).subtract(Natural.small(1)).toString() +
      '\n补码：-' + sign.toString() + ' … ' + maximum + '\n原码/反码：-' + maximum + ' … ' + maximum;
  }

  @Builder
  private Bits() {
    Text('点击翻转 bit · 从高位到低位，每行 1 byte')
      .fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ bottom: 8 })
    Grid() {
      ForEach(this.indices(), (index: number) => {
        GridItem() {
          Button() {
            Column({ space: 2 }) {
              Text(index.toString()).fontSize(10).fontColor($r('sys.color.font_secondary'))
              Text(this.bit(index).toString()).fontSize(18).fontFamily('monospace').fontColor(this.fieldColor(index))
            }
          }
          .type(ButtonType.Normal).borderRadius(8).width('100%').height(44)
          .backgroundColor(this.bit(index) ? $r('sys.color.comp_background_secondary') : Color.Transparent)
          .id('base.bit.' + index.toString())
          .accessibilityText('第 ' + index + ' 位，' + this.bit(index) + '，点击翻转')
          .onClick(() => this.onFlip(index))
        }.padding({ right: index % 8 === 4 ? 4 : 0 })
      }, (index: number) => index.toString())
    }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(4).columnsGap(3)
    .height(this.indices().length / 8 * 48).width('100%')
  }

  @Builder
  private Encodings() {
    Text('按当前数学值生成编码').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
    ForEach(encodingRows(this.session.word, this.session.signed), (row: EncodingRow) => {
      Column({ space: 3 }) {
        Text(row.name + ' · ' + row.value).fontSize(12).fontColor($r('sys.color.font_secondary'))
        Text(row.bits).fontSize(13).fontFamily('monospace').copyOption(CopyOptions.LocalDevice)
          .fontColor($r('sys.color.font_primary')).width('100%')
      }.alignItems(HorizontalAlign.Start).margin({ top: 10 })
    })
    Divider().margin({ top: 12, bottom: 12 })
    Text('将当前原始位模式解释为').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
    ForEach(['无符号', '原码', '反码', '补码'], (name: string) => {
      Text(name + '  ' + decodeEncoding(this.session.word, name))
        .fontFamily('monospace').fontSize(13).fontColor($r('sys.color.font_primary')).margin({ top: 6 })
    })
    Text('原码/反码保留负零；最小补码负数无法编码为同宽原码/反码。此面板用于观察，运算仍采用无符号或补码。')
      .fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 10 })
    Text(this.ranges()).fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
  }

  @Builder
  private FloatFields() {
    Text(decodeFloat(this.session.floatBits, this.session.floatWidth).category)
      .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_emphasize'))
    Row({ space: 8 }) {
      Text('S ' + decodeFloat(this.session.floatBits, this.session.floatWidth).sign).fontColor($r('sys.color.warning')).fontSize(13)
      Text('E ' + decodeFloat(this.session.floatBits, this.session.floatWidth).exponent).fontColor($r('sys.color.font_emphasize')).fontSize(13)
      Text('偏置 ' + new FloatFormat(this.session.floatWidth).bias).fontColor($r('sys.color.font_secondary')).fontSize(13)
    }.margin({ top: 8 })
    Text('尾数 F：' + decodeFloat(this.session.floatBits, this.session.floatWidth).fraction)
      .fontSize(13).fontFamily('monospace').fontColor($r('sys.color.font_primary'))
      .copyOption(CopyOptions.LocalDevice).margin({ top: 8 })
    Text('精确解释：' + decodeFloat(this.session.floatBits, this.session.floatWidth).exact)
      .fontSize(13).fontColor($r('sys.color.font_secondary')).copyOption(CopyOptions.LocalDevice).margin({ top: 8 })
    if (!decodeFloat(this.session.floatBits, this.session.floatWidth).category.includes('NaN') &&
      decodeFloat(this.session.floatBits, this.session.floatWidth).category !== '无穷') {
      Text('实际指数：' + decodeFloat(this.session.floatBits, this.session.floatWidth).actualExponent +
        ' · 有效数字：' + (decodeFloat(this.session.floatBits, this.session.floatWidth).exponent === 0 ? '0.F' : '1.F'))
        .fontSize(13).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
    }
    Text('十进制显示采用简短表示；输入按 roundTiesToEven 舍入。修改位模式保留 NaN payload，切换格式重新编码。')
      .fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8, bottom: 12 })
    this.Bits()
  }

  build() {
    Column() {
      if (this.panel === 'help') {
        Text('操作说明').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        Text('长按 AND：OR / XOR / NOT\n长按 SHL / SHR：算术移位、循环和带进位循环\n长按 + / −：ADC / SBB\n长按退格：连续删除\n四进制行切换输入进制，长按数值可复制\n切换配置先确认表达式；无效草稿会保留并提示\nCF：进位或借位；OF：有符号溢出\nZF：全零；SF：最高位；—：不适用\nC-in 独立控制 ADC / SBB / RCL / RCR 的输入进位\n移位计数为 0 保持标志；旋转计数按字长（带进位时字长 + 1）取模\n乘除只更新 ZF / SF，结果按字长截断\n括号 > 一元 > 乘除 > 加减 > 移位 > AND > XOR > OR\n这些是 CalculatorX 的固定规则，不模拟特定 CPU。')
          .fontSize(14).lineHeight(23).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
      } else if (this.session.mode === 'float') { this.FloatFields() }
      else if (this.panel === 'encoding') { this.Encodings() }
      else { this.Bits() }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
    .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(16)
  }
}
