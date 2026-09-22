/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file BaseConverter.ets
 * @description 程序员模式页面与双路径键盘
 * * @author StartYi
 * @date 2026/7/24 22:53
 */

import deviceInfo from '@ohos.deviceInfo';
import pasteboard from '@ohos.pasteboard';
import { PreferenceConfigs } from '../../../utils/CalculatorConfigs';
import { HapticUtils } from '../../../utils/HapticUtils';
import { KeyboardKeySurface } from '../../common/keyboard/KeyboardKeySurface';
import { KeyboardKeyRole } from '../../common/keyboard/KeyboardKeyTypes';
import { ProgrammerSession } from '../../../utils/base/ProgrammerSession';
import { decodeFloat } from '../../../utils/base/Ieee754';
import { ProgrammerInspector } from './ProgrammerInspector';
import { PreferenceManager } from '../../../utils/PreferenceManager';
import { HistoryRepository, HistoryRecord } from '../../../database/HistoryRepository';
import { ProgrammerMemory, ProgrammerSettings, settingsOf, recordOf, restoreSettings, restoreRecord } from '../../../utils/base/ProgrammerState';

const INTEGER_KEYS: string[] = [
  'A', 'B', 'C', 'AND', 'SHL',
  'D', 'E', 'F', 'MOD', 'SHR',
  'AC', '(', ')', '⌫', '/',
  '7', '8', '9', '±', '*',
  '4', '5', '6', '0', '-',
  '1', '2', '3', '=', '+'
];
const FLOAT_KEYS: string[] = [
  'A', 'B', 'C', 'D', 'E',
  'F', 'NaN', '∞', 'AC', '⌫',
  '7', '8', '9', 'e', '-',
  '4', '5', '6', '.', '+',
  '1', '2', '3', '±', '=',
  '0'
];

function keyRole(key: string): KeyboardKeyRole {
  if (key === 'AC' || key === '⌫') return KeyboardKeyRole.DANGER;
  if (key === '=') return KeyboardKeyRole.EMPHASIS;
  if (/^[0-9A-F]$/.test(key) || key === '.') return KeyboardKeyRole.CORE;
  return KeyboardKeyRole.OPERATOR;
}

function alternatives(key: string): string[] {
  if (key === 'AND') return ['OR', 'XOR', 'NOT'];
  if (key === 'SHL') return ['ROL', 'RCL'];
  if (key === 'SHR') return ['SAR', 'ROR', 'RCR'];
  if (key === '+') return ['ADC'];
  if (key === '-') return ['SBB'];
  return [];
}

@Component
struct ProgrammerKey {
  @Prop keyText: string = '';
  @Prop immersive: boolean = false;
  @Prop available: boolean = true;
  @Prop integerMode: boolean = true;
  onPress: (key: string) => void = () => {};
  private repeatTimer: number = -1;
  private delayTimer: number = -1;
  private repeated: boolean = false;

  private stopRepeat(): void {
    clearTimeout(this.delayTimer);
    clearInterval(this.repeatTimer);
  }
  aboutToDisappear(): void { this.stopRepeat(); }

  @Builder
  private MenuBuilder() {
    Menu() {
      ForEach(alternatives(this.keyText), (key: string) => {
        MenuItem({ content: key }).onClick(() => this.onPress(key))
      })
    }
  }

  @Builder
  private Surface() {
    KeyboardKeySurface({
      immersive: this.immersive, role: keyRole(this.keyText), keyBorderRadius: 16,
      semanticId: 'base.key.' + this.keyText,
      keyAccessibilityText: this.keyText + (this.available ? '' : '，当前进制不可用') +
        (this.integerMode && alternatives(this.keyText).length ? '，长按更多操作' : ''),
      onKeyClick: () => { if (this.available && !this.repeated) this.onPress(this.keyText); },
      onKeyTouch: (event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.repeated = false;
          if (this.keyText === '⌫') {
            this.stopRepeat();
            this.delayTimer = setTimeout(() => {
              this.repeated = true;
              this.onPress('⌫');
              this.repeatTimer = setInterval(() => this.onPress('⌫'), 70);
            }, 450);
          }
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.stopRepeat();
      }
    }) {
      Column({ space: 1 }) {
        Text(this.keyText === '*' ? '×' : this.keyText === '/' ? '÷' : this.keyText === '-' ? '−' : this.keyText)
          .fontSize(this.keyText.length > 2 ? 16 : 23).fontWeight(FontWeight.Medium)
          .fontColor(keyRole(this.keyText) === KeyboardKeyRole.DANGER || this.keyText === '=' ?
            $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
        if (this.integerMode && alternatives(this.keyText).length > 0) {
          Text('···').fontSize(10).fontColor($r('sys.color.font_secondary'))
        }
      }
    }
  }

  build() {
    if (this.integerMode && alternatives(this.keyText).length > 0) {
      Stack() { this.Surface() }.width('100%').height('100%')
        .enabled(this.available).opacity(this.available ? 1 : 0.3)
        .bindContextMenu(this.MenuBuilder, ResponseType.LongPress)
    } else {
      Stack() { this.Surface() }.width('100%').height('100%')
        .enabled(this.available).opacity(this.available ? 1 : 0.3)
    }
  }
}

@Component
export struct BaseConverter {
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @State session: ProgrammerSession = new ProgrammerSession();
  @State panel: string = '';
  @State pageHeight: number = 700;
  private undoStack: ProgrammerSession[] = [];
  private redoStack: ProgrammerSession[] = [];
  private undoHandler: () => void = () => this.undo();
  private redoHandler: () => void = () => this.redo();
  private historyHandler: (record: HistoryRecord, insertType: string) => void = (record, insertType) => {
    this.apply(() => {
      this.session = restoreRecord(record.extraParams || '');
      if (insertType === 'output') {
        if (this.session.mode === 'integer') this.session.expression = this.session.word.format(this.session.radix, this.session.signed, false);
        else {
          this.session.floatRadix = 16;
          this.session.floatText = this.session.floatBits.toString(16);
        }
      }
    });
  };

  aboutToAppear(): void {
    try {
      this.session = ProgrammerMemory.session ? ProgrammerMemory.session.copy() :
        restoreSettings(JSON.parse(PreferenceManager.get('programmer.settings.v1', JSON.stringify(settingsOf(this.session))) as string) as ProgrammerSettings);
    } catch (_) { this.session = new ProgrammerSession(); }
    getContext(this).eventHub.on('event_math_undo', this.undoHandler);
    getContext(this).eventHub.on('event_math_redo', this.redoHandler);
    getContext(this).eventHub.on('event_programmer_restore', this.historyHandler);
  }

  aboutToDisappear(): void {
    ProgrammerMemory.session = this.session.copy();
    getContext(this).eventHub.off('event_math_undo', this.undoHandler);
    getContext(this).eventHub.off('event_math_redo', this.redoHandler);
    getContext(this).eventHub.off('event_programmer_restore', this.historyHandler);
  }

  private persistSettings(): void {
    const settings = JSON.stringify(settingsOf(this.session));
    if (settings !== PreferenceManager.get('programmer.settings.v1', '')) PreferenceManager.set('programmer.settings.v1', settings);
  }

  private saveHistory(): void {
    const integer = this.session.mode === 'integer';
    HistoryRepository.insertRecord({ moduleType: 'base',
      inputContent: integer ? this.session.expression : this.session.floatText,
      outputContent: integer ? this.session.word.format(this.session.radix, this.session.signed) :
        decodeFloat(this.session.floatBits, this.session.floatWidth).decimal + ' · 0x' + this.session.floatBits.toString(16),
      extraParams: JSON.stringify(recordOf(this.session)), timestamp: Date.now() });
  }

  private semanticState(): string {
    if (!getContext(this).applicationInfo.debug) return '';
    return JSON.stringify(recordOf(this.session));
  }

  private apply(action: () => void): void {
    const before = this.session.copy();
    try { action(); }
    catch (error) { this.session.error = (error as Error).message; }
    this.undoStack.push(before);
    if (this.undoStack.length > 50) this.undoStack.shift();
    this.redoStack = [];
    this.session = this.session.copy();
    this.persistSettings();
  }

  private press(key: string): void {
    HapticUtils.playVibration(key, this.hapticFeedback, this.vibrationCurve);
    this.apply(() => this.session.key(key));
    if (key === '=' && this.session.error.length === 0) this.saveHistory();
  }

  private undo(): void {
    const previous = this.undoStack.pop();
    if (previous) { this.redoStack.push(this.session.copy()); this.session = previous; this.persistSettings(); }
  }
  private redo(): void {
    const next = this.redoStack.pop();
    if (next) { this.undoStack.push(this.session.copy()); this.session = next; this.persistSettings(); }
  }

  private async paste(): Promise<void> {
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      const text = data.getPrimaryText().trim();
      this.apply(() => {
        if (this.session.mode === 'integer') { this.session.expression = text; this.session.evaluated = false; }
        else { this.session.floatText = text; this.session.floatEvaluated = false; }
        this.session.confirm();
      });
    } catch (_) { this.session.error = '无法读取剪贴板'; this.session = this.session.copy(); }
  }

  private keyboardHeight(): number {
    return Math.min(390, Math.max(270, this.pageHeight * 0.52)) + Math.max(0, this.navBarHeight - 8);
  }
  private value(radix: number): string {
    if (this.session.mode === 'integer') return this.session.word.format(radix, this.session.signed);
    if (radix === 10) return decodeFloat(this.session.floatBits, this.session.floatWidth).decimal;
    return this.session.floatBits.toString(radix).padStart(radix === 16 ? this.session.floatWidth / 4 : this.session.floatWidth, '0');
  }

  @Builder
  private Chip(label: string, selected: boolean, action: () => void, identifier: string) {
    Button(label).fontSize(13).fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(selected ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .backgroundColor(selected ? $r('sys.color.comp_background_secondary') : Color.Transparent)
      .height(32).padding({ left: 10, right: 10 }).id(identifier)
      .accessibilityText(label + (selected ? '，已选中' : '')).onClick(action)
  }

  @Builder
  private RadixRow(label: string, radix: number) {
    Row({ space: 10 }) {
      Text(label).fontSize(13).fontWeight(FontWeight.Bold).width(38)
        .fontColor(this.session.currentRadix() === radix ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      Scroll() {
        Text(this.value(radix)).fontFamily('monospace').fontSize(radix === 10 ? 19 : 15)
          .fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice).maxLines(1)
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
    }.width('100%').height(38).padding({ left: 10, right: 10 }).borderRadius(10)
    .backgroundColor(this.session.currentRadix() === radix ? $r('sys.color.comp_background_secondary') : Color.Transparent)
    .id('base.radix.' + radix.toString())
    .accessibilityText(label + ' ' + this.value(radix) + (this.session.currentRadix() === radix ? '，当前输入进制' : '，点击切换'))
    .onClick(() => this.apply(() => this.session.changeRadix(radix)))
  }

  @Builder
  private Flag(label: string, value: number) {
    Text(label + ' ' + (value < 0 ? '—' : value.toString())).fontFamily('monospace').fontSize(12)
      .fontColor(value === 1 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .id('base.flag.' + label.toLowerCase())
  }

  @Builder
  private Display() {
    Scroll() {
      Column({ space: 7 }) {
        Row() {
          this.Chip('整数', this.session.mode === 'integer', () => {
            this.apply(() => { this.session.mode = 'integer'; this.session.error = ''; });
          }, 'base.mode.integer')
          this.Chip('IEEE 754', this.session.mode === 'float', () => {
            this.apply(() => { this.session.mode = 'float'; this.session.error = ''; });
          }, 'base.mode.float')
          Blank()
          this.Chip('粘贴', false, () => { this.paste(); }, 'base.paste')
          this.Chip('?', this.panel === 'help', () => { this.panel = this.panel === 'help' ? '' : 'help'; }, 'base.help')
        }.width('100%')
        Scroll() {
          Text(this.session.mode === 'integer' ? this.session.expression : this.session.floatText)
            .fontSize(25).fontFamily('monospace').fontColor($r('sys.color.font_primary'))
            .copyOption(CopyOptions.LocalDevice).maxLines(1).padding({ left: 8, right: 8 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(40).width('100%').id('base.expression')
        if (this.session.error.length > 0) {
          Text(this.session.error).fontSize(12).fontColor($r('sys.color.warning')).width('100%').id('base.error')
        }
        this.RadixRow('HEX', 16)
        this.RadixRow('DEC', 10)
        if (this.session.mode === 'integer') { this.RadixRow('OCT', 8) }
        this.RadixRow('BIN', 2)
        if (this.session.mode === 'integer') {
          Row({ space: 6 }) {
            Select([{ value: '8 bit · BYTE' }, { value: '16 bit · WORD' }, { value: '32 bit · DWORD' }, { value: '64 bit · QWORD' }])
              .selected([8, 16, 32, 64].indexOf(this.session.width)).value(this.session.width + ' bit').font({ size: 14 }).height(34)
              .id('base.width').onSelect((index: number) => this.apply(() => this.session.changeWidth([8, 16, 32, 64][index])))
            this.Chip(this.session.signed ? '有符号' : '无符号', this.session.signed,
              () => this.apply(() => this.session.changeSigned()), 'base.signed')
            Blank()
            this.Chip('位', this.panel === 'bits', () => { this.panel = this.panel === 'bits' ? '' : 'bits'; }, 'base.bits')
            this.Chip('编码', this.panel === 'encoding', () => { this.panel = this.panel === 'encoding' ? '' : 'encoding'; }, 'base.encoding')
          }.width('100%')
          Row({ space: 12 }) {
            this.Flag('CF', this.session.flags.cf)
            this.Flag('OF', this.session.flags.of)
            this.Flag('ZF', this.session.flags.zf)
            this.Flag('SF', this.session.flags.sf)
            Blank()
            this.Chip('C-in ' + this.session.carry, this.session.carry === 1,
              () => this.apply(() => { this.session.carry = 1 - this.session.carry; }), 'base.carry')
          }.width('100%')
        } else {
          Row() {
            ForEach([16, 32, 64], (width: number) => {
              this.Chip('binary' + width, this.session.floatWidth === width,
                () => this.apply(() => this.session.changeFloatWidth(width)), 'base.float.width.' + width)
            })
            Blank()
            this.Chip('字段', this.panel === 'bits', () => { this.panel = this.panel === 'bits' ? '' : 'bits'; }, 'base.bits')
          }.width('100%')
          Text(decodeFloat(this.session.floatBits, this.session.floatWidth).category + ' · 按 = 确认输入')
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        }
        if (this.panel.length > 0) {
          ProgrammerInspector({ session: this.session, panel: this.panel,
            onFlip: (index: number) => this.apply(() => this.session.flip(index)) })
        }
      }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 12 })
    }.width('100%').height('100%').scrollBar(BarState.Auto).align(Alignment.Top)
  }

  @Builder
  private Keyboard(immersive: boolean) {
    Grid() {
      ForEach(this.session.mode === 'integer' ? INTEGER_KEYS : FLOAT_KEYS, (key: string) => {
        GridItem() {
          ProgrammerKey({ keyText: key, immersive: immersive, available: this.session.inputEnabled(key),
            integerMode: this.session.mode === 'integer', onPress: (action: string) => this.press(action) })
        }.columnStart(this.session.mode === 'float' && key === '0' ? 0 : undefined)
        .columnEnd(this.session.mode === 'float' && key === '0' ? 4 : undefined)
      }, (key: string) => this.session.mode + '.' + key)
    }.columnsTemplate('1fr 1fr 1fr 1fr 1fr').rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
    .rowsGap(8).columnsGap(8).width('100%').height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 + Math.max(0, this.navBarHeight - 8) })
  }

  @Builder
  private ImmersiveKeyboard() {
    Column() { this.Keyboard(true) }.width('100%').height('100%').borderRadius({ topLeft: 28, topRight: 28 })
      .backgroundColor($r('sys.color.comp_background_primary'))
  }
  @Builder
  private LegacyLayout() {
    Column() {
      Column() { this.Display() }.layoutWeight(1).width('100%')
      Column() { this.Keyboard(false) }.height(this.keyboardHeight()).width('100%').borderRadius({ topLeft: 28, topRight: 28 })
        .backgroundColor($r('sys.color.comp_background_primary'))
    }.width('100%').height('100%')
  }
  @Builder
  private ImmersiveLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() { this.Display() }.tabBar(this.ImmersiveKeyboard)
    }.vertical(false).scrollable(false).animationDuration(0).barHeight(this.keyboardHeight()).width('100%').height('100%')
  }

  build() {
    Column() {
      if (deviceInfo.apiAvailable('26.0.0')) {
        if (this.keyImmersiveMaterial) { this.ImmersiveLayout() }
        else { this.LegacyLayout() }
      } else { this.LegacyLayout() }
    }.width('100%').height('100%').backgroundColor($r('sys.color.comp_background_tertiary'))
    .onAreaChange((_, area: Area) => { this.pageHeight = Number(area.height); }).id('base.programmer')
    .accessibilityDescription(this.semanticState())
  }
}
