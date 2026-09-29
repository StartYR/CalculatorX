/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BaseConverter.ets
 * @description 进制转换页面、输入会话与双路径键盘装配
 * @author StartYi
 * @date 2026/7/24 22:53
 */

import deviceInfo from '@ohos.deviceInfo';
import pasteboard from '@ohos.pasteboard';

import { createTopBarMaterial } from '../../../utils/ImmersiveMaterialUtils';
import { PreferenceConfigs } from '../../../utils/CalculatorConfigs';
import { HapticUtils } from '../../../utils/HapticUtils';
import { BaseConversionSession } from '../../../utils/base/BaseConversionSession';
import { decodeFloat } from '../../../utils/base/IEEE754';
import { BaseInspector } from './BaseInspector';
import { BaseKey } from './BaseKey';
import { binaryRows } from '../../../utils/base/BinaryDisplay';
import { NUMERIC_PLACES } from '../../../utils/base/NumericValue';
import { PreferenceManager } from '../../../utils/PreferenceManager';
import { HistoryRepository, HistoryRecord } from '../../../database/HistoryRepository';
import { BaseConversionMemory, BaseConversionSettings, settingsOf, recordOf, historyRecordOf, restoreSettings, restoreRecord } from '../../../utils/base/BaseConversionState';

// 布局调节量均为 vp；顶栏位置从系统状态栏底部开始计算。
const BASE_TOOLBAR_TOP_OFFSET: number = 60;
const BASE_TOOLBAR_HEIGHT: number = 44;
const BASE_CONTENT_TOP_GAP: number = 12;
// 页面视口避开应用标题栏；材质留白仅容纳阴影，不计入顶栏可见高度。
const BASE_PAGE_TOP_OFFSET: number = 56;
const BASE_TOOLBAR_SHADOW_GUTTER: number = 24;

// 数值换算实时预览，键盘只提供数字、小数点和输入控制。
const NUMERIC_KEYS: string[] = [
  'E', 'F', '⌫', 'AC',
  '7', '8', '9', 'D',
  '4', '5', '6', 'C',
  '1', '2', '3', 'B',
  '±', '0', '.', 'A',
];

const INTEGER_KEYS: string[] = [
  'D', 'E', 'F', 'AND', 'SHL',
  'A', 'B', 'C', 'MOD', 'SHR',
  '7', '8', '9', '⌫', 'AC',
  '4', '5', '6', '*', '/',
  '1', '2', '3', '+', '-',
  '±', '0', '(', ')', '='
];

// 数组始终按五列六行排列，布局索引与按键位置共享这一约束。
// 同一行相邻的同名格子合并为一个横向按键。
const FLOAT_KEYS: string[] = [
  'D', 'E', 'F', 'NaN', '∞',
  'A', 'B', 'C', 'e', 'e',
  '7', '8', '9', '⌫', 'AC',
  '4', '5', '6', '*', '/',
  '1', '2', '3', '+', '-',
  '.', '0', '0', '±', '='
];

class BaseToolbarVisualModifier implements AttributeModifier<RowAttribute> {
  applyNormalAttribute(instance: RowAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.backgroundColor(Color.Transparent);
      instance.systemMaterial(createTopBarMaterial());
    } else {
      instance.backgroundColor($r('sys.color.comp_background_secondary'));
      instance.border({ width: 0.5, color: $r('sys.color.comp_divider') });
      instance.shadow(ShadowStyle.OUTER_DEFAULT_SM);
    }
  }
}

const baseToolbarVisualModifier: BaseToolbarVisualModifier = new BaseToolbarVisualModifier();

// 标签文字和选中态通过响应式属性更新，不能使用按值传参的 Builder 固定初始状态。
@Component
struct BaseChip {
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @Prop label: ResourceStr = '';
  @Prop selected: boolean = false;
  @Prop stretch: boolean = false;
  semanticId: string = '';
  onActivate: () => void = () => {};

  private labelText(): string {
    return typeof this.label === 'string' ? this.label : getContext(this).resourceManager.getStringSync(this.label.id);
  }

  build() {
    Button(this.labelText()).fontSize(13).fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selected ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .backgroundColor(this.selected ? $r('sys.color.comp_background_secondary') : Color.Transparent)
      .width(this.stretch ? '100%' : undefined).height(this.stretch ? BASE_TOOLBAR_HEIGHT - 8 : 32)
      .padding({ left: this.stretch ? 4 : 10, right: this.stretch ? 4 : 10 }).id(this.semanticId)
      .accessibilityText(this.labelText() + (this.selected ? '，已选中' : '')).onClick(() => {
        HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
        this.onActivate();
      })
  }
}

@Component
struct IntegerFlag {
  @Prop label: string = '';
  @Prop flagValue: number = -1;

  build() {
    Text(this.label + ' ' + (this.flagValue < 0 ? '—' : this.flagValue.toString())).fontFamily('monospace').fontSize(12)
      .fontColor(this.flagValue === 1 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      .id('base.flag.' + this.label.toLowerCase())
  }
}

@Component
export struct BaseConverter {
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @State session: BaseConversionSession = new BaseConversionSession();
  @State panel: string = '';
  @State pageHeight: number = 700;
  private undoStack: BaseConversionSession[] = [];
  private redoStack: BaseConversionSession[] = [];
  private undoHandler: () => void = () => this.undo();
  private redoHandler: () => void = () => this.redo();
  // 恢复输出时直接回填已存位模式；浮点转 HEX 可保留 NaN payload。
  private historyHandler: (record: HistoryRecord, insertType: string) => void = (record, insertType) => {
    this.apply(() => {
      this.session = restoreRecord(record.extraParams || '');
      if (insertType === 'output') {
        if (this.session.mode === 'integer') this.session.expression = this.session.word.format(this.session.radix, this.session.signed, false);
        else if (this.session.mode === 'numeric') this.session.numeric.changeRadix(this.session.numeric.radix);
        else {
          this.session.floatRadix = 16;
          this.session.floatText = this.session.floatBits.toString(16);
        }
      }
    });
  };

  aboutToAppear(): void {
    // 进程内会话优先于跨启动偏好；事件订阅只在组件挂载期间有效。
    try {
      this.session = BaseConversionMemory.session ? BaseConversionMemory.session.copy() :
        restoreSettings(JSON.parse(PreferenceManager.get(PreferenceConfigs.KEY_PROGRAMMER_SETTINGS, JSON.stringify(settingsOf(this.session))) as string) as BaseConversionSettings);
    } catch (_) { this.session = new BaseConversionSession(); }
    getContext(this).eventHub.on('event_math_undo', this.undoHandler);
    getContext(this).eventHub.on('event_math_redo', this.redoHandler);
    getContext(this).eventHub.on('event_programmer_restore', this.historyHandler);
  }

  aboutToDisappear(): void {
    BaseConversionMemory.session = this.session.copy();
    getContext(this).eventHub.off('event_math_undo', this.undoHandler);
    getContext(this).eventHub.off('event_math_redo', this.redoHandler);
    getContext(this).eventHub.off('event_programmer_restore', this.historyHandler);
  }

  private persistSettings(): void {
    // 只持久化可恢复的配置，草稿、预览和运算结果留在进程内会话。
    const settings = JSON.stringify(settingsOf(this.session));
    if (settings !== PreferenceManager.get(PreferenceConfigs.KEY_PROGRAMMER_SETTINGS, '')) {
      PreferenceManager.set(PreferenceConfigs.KEY_PROGRAMMER_SETTINGS, settings);
    }
  }

  private saveHistory(): void {
    // 历史只由确认操作触发，extraParams 保留完整位模式和当时的解释上下文。
    if (this.session.mode === 'numeric') {
      const numeric = this.session.numeric;
      HistoryRepository.insertRecord({ moduleType: 'base',
        inputContent: numeric.sourceText + ' (' + numeric.sourceRadix + ')',
        outputContent: numeric.displayText(numeric.radix) + ' (' + numeric.radix + ')',
        extraParams: JSON.stringify(historyRecordOf(this.session)), timestamp: Date.now() });
      return;
    }
    const integer = this.session.mode === 'integer';
    HistoryRepository.insertRecord({ moduleType: 'base',
      inputContent: integer ? this.session.expression : this.session.floatText,
      outputContent: integer ? this.session.word.format(this.session.radix, this.session.signed) :
        decodeFloat(this.session.floatBits, this.session.floatWidth).decimal + ' · 0x' + this.session.floatBits.toString(16),
      extraParams: JSON.stringify(historyRecordOf(this.session)), timestamp: Date.now() });
  }

  private semanticState(): string {
    // 结构化状态仅用于 debug 语义 CLI，release 不公开草稿与内部位模式。
    if (!getContext(this).applicationInfo.debug) return '';
    return JSON.stringify({ data: recordOf(this.session), error: this.session.error,
      integerConfirmed: this.session.evaluated, floatConfirmed: this.session.floatEvaluated,
      numericConfirmed: this.session.numeric.evaluated, numericInput: this.session.numeric.text,
      numericPreviewValid: this.session.numeric.previewValid });
  }

  private apply(action: () => void): void {
    // 每次操作前保存快照；替换整个 session 以触发 ArkUI 状态刷新，失败也保留诊断。
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
    // 预览按键不会写历史；只有无错误的 = 才记录已确认结果。
    HapticUtils.playVibration(key, this.hapticFeedback, this.vibrationCurve);
    this.apply(() => this.session.key(key));
    if (key === '=' && this.session.error.length === 0) this.saveHistory();
  }

  private select(action: () => void): void {
    HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
    this.apply(action);
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
    // 整数粘贴直接确认，浮点与数值粘贴先预览；各自会话校验对应输入上限。
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      const text = data.getPrimaryText().trim();
      this.apply(() => {
        if (text.length > (this.session.mode === 'integer' ? 1024 : 768)) throw new Error('剪贴板输入过长');
        if (this.session.mode === 'integer') {
          this.session.expression = text;
          this.session.evaluated = false;
          this.session.confirm();
        } else if (this.session.mode === 'numeric') this.session.numeric.replaceInput(text);
        else this.session.replaceFloatInput(text);
      });
    } catch (_) { this.session.error = '无法读取剪贴板'; this.session = this.session.copy(); }
  }

  private keyboardHeight(): number {
    return Math.min(390, Math.max(270, this.pageHeight * 0.52)) + Math.max(0, this.navBarHeight - 8);
  }
  private value(radix: number): string {
    if (this.session.mode === 'numeric') {
      // 当前输入直接放在进制行，保留尚未完成的负号、小数点和无效草稿。
      const numeric = this.session.numeric;
      return radix === numeric.radix && !numeric.evaluated ? numeric.text : numeric.displayText(radix);
    }
    if (this.session.mode === 'integer') return this.session.word.format(radix, this.session.signed);
    // 数值行和字段面板共用预览来源；保存历史仍使用独立的已确认结果。
    const bits = this.session.displayedFloatBits();
    if (radix === 10) return decodeFloat(bits, this.session.floatWidth).decimal;
    return bits.toString(radix).padStart(radix === 16 ? this.session.floatWidth / 4 : this.session.floatWidth, '0');
  }

  private async copyBinary(): Promise<void> {
    try {
      // 分行仅用于排版，复制仍提供连续完整文本，避免换行混入后续输入。
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.value(2)));
    } catch (_) { this.session.error = '无法复制数值'; this.session = this.session.copy(); }
  }

  @Builder
  private BinaryCopyMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.base_copy_value') }).onClick(() => { this.copyBinary(); })
    }
  }

  @Builder
  private BinaryRadixRow() {
    Row({ space: 10 }) {
      Text('BIN').fontSize(13).fontWeight(FontWeight.Bold).width(38)
        .fontColor(this.session.currentRadix() === 2 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      Column() {
        // 每组是独立单行；窄屏缩小字形而不重新换行，32 位边界不依赖屏幕型号。
        ForEach(binaryRows(this.value(2)), (row: string) => {
          Text(row).width('100%').height(22).maxLines(1)
            .fontFamily('monospace').fontSize(15).minFontSize(1).maxFontSize(15)
            .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
            .textAlign(TextAlign.End).fontColor($r('sys.color.font_primary'))
        }, (row: string, index: number) => index.toString() + ':' + row)
      }.layoutWeight(1)
        .bindContextMenu(this.BinaryCopyMenu, ResponseType.LongPress)
        .onClick(() => this.select(() => this.session.changeRadix(2)))
    }.width('100%').constraintSize({ minHeight: 38 }).padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .borderRadius(10)
    .backgroundColor(this.session.currentRadix() === 2 ? $r('sys.color.comp_background_secondary') : Color.Transparent)
    .id('base.radix.2').accessibilityText('BIN ' + this.value(2))
    .onClick(() => this.select(() => this.session.changeRadix(2)))
  }

  @Builder
  private RadixRow(label: string, radix: number) {
    Row({ space: 10 }) {
      Text(label).fontSize(13).fontWeight(FontWeight.Bold).width(38)
        .fontColor(this.session.currentRadix() === radix ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      Text(this.value(radix)).fontFamily('monospace').fontSize(radix === 10 ? 19 : 15)
        .fontColor($r('sys.color.font_primary')).copyOption(CopyOptions.LocalDevice)
        .minFontSize(8).maxFontSize(radix === 10 ? 19 : 15)
        .maxLines(1).heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
        .textAlign(TextAlign.End).layoutWeight(1).height(30)
        .onClick(() => this.select(() => this.session.changeRadix(radix)))
    }.width('100%').height(38)
    .padding({ left: 10, right: 10 }).borderRadius(10)
    .backgroundColor(this.session.currentRadix() === radix ? $r('sys.color.comp_background_secondary') : Color.Transparent)
    .id('base.radix.' + radix.toString())
    .accessibilityText(label + ' ' + this.value(radix) + (this.session.currentRadix() === radix ? '，当前输入进制' : '，点击切换'))
    .onClick(() => this.select(() => this.session.changeRadix(radix)))
  }

  /** 长数值按可用宽度换行，整数部分不能因显示精度或固定行高而丢失。 */
  @Builder
  private NumericRadixRow(label: string, radix: number) {
    Row({ space: 10 }) {
      Text(label)
        .width(38)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.session.currentRadix() === radix ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
      Text(this.value(radix))
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .wordBreak(WordBreak.BREAK_ALL)
        .fontFamily('monospace')
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .copyOption(CopyOptions.LocalDevice)
        .onClick(() => this.select(() => this.session.changeRadix(radix)))
    }
    .width('100%')
    .constraintSize({ minHeight: 42 })
    .padding(10)
    .borderRadius(10)
    .backgroundColor(this.session.currentRadix() === radix ? $r('sys.color.comp_background_secondary') : Color.Transparent)
    .id('base.radix.' + radix)
    .accessibilityText(label + ' ' + this.value(radix))
    .onClick(() => this.select(() => this.session.changeRadix(radix)))
  }

  @Builder
  private NumericControls() {
    Text($r('app.string.base_numeric_description'))
      .width('100%')
      .fontSize(12)
      .fontColor($r('sys.color.font_secondary'))
    Row({ space: 8 }) {
      Text($r('app.string.base_numeric_places'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Select([{ value: '16' }, { value: '32' }, { value: '64' }, { value: '128' }])
        .selected(NUMERIC_PLACES.indexOf(this.session.numeric.places))
        .value(this.session.numeric.places.toString())
        .font({ size: 14 })
        .height(32)
        .id('base.numeric.precision')
        .onSelect((index: number) => this.select(() => this.session.numeric.changePlaces(NUMERIC_PLACES[index])))
      Blank()
      if (this.session.numeric.radix !== this.session.numeric.sourceRadix) {
        BaseChip({ label: $r('app.string.base_numeric_edit_source'), selected: false,
          onActivate: () => this.apply(() => { this.session.numeric.editSource(); this.session.error = ''; }), semanticId: 'base.numeric.source' })
      }
    }.width('100%')
    Text($r('app.string.base_numeric_approximation'))
      .width('100%')
      .fontSize(12)
      .fontColor($r('sys.color.font_secondary'))
  }

  @Builder
  private Toolbar() {
    Row({ space: 8 }) {
      Row() {
        BaseChip({ label: $r('app.string.base_numeric_tab'), selected: this.session.mode === 'numeric', stretch: true,
          onActivate: () => {
            this.apply(() => { this.session.mode = 'numeric'; this.session.error = ''; });
          }, semanticId: 'base.mode.numeric' }).layoutWeight(1)
        BaseChip({ label: '整数', selected: this.session.mode === 'integer', stretch: true,
          onActivate: () => {
            this.apply(() => { this.session.mode = 'integer'; this.session.error = ''; });
          }, semanticId: 'base.mode.integer' }).layoutWeight(1)
        BaseChip({ label: 'IEEE 754', selected: this.session.mode === 'float', stretch: true,
          onActivate: () => {
            this.apply(() => { this.session.mode = 'float'; this.session.error = ''; });
          }, semanticId: 'base.mode.float' }).layoutWeight(1.35)
      }.layoutWeight(1).height(BASE_TOOLBAR_HEIGHT).padding(4).borderRadius(BASE_TOOLBAR_HEIGHT / 2)
      .attributeModifier(baseToolbarVisualModifier)
      Row() {
        Button('粘贴').width('100%').height('100%').padding(0).fontSize(13)
          .fontColor($r('sys.color.font_primary')).backgroundColor(Color.Transparent)
          .id('base.paste').accessibilityText('粘贴')
          .onClick(() => {
            HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
            this.paste();
          })
      }.width(52).height(BASE_TOOLBAR_HEIGHT).borderRadius(BASE_TOOLBAR_HEIGHT / 2).attributeModifier(baseToolbarVisualModifier)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(22)
            .fontColor([this.panel === 'help' ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary')])
        }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
        .id('base.help').accessibilityText(this.panel === 'help' ? '关闭帮助' : '帮助')
        .onClick(() => {
          HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
          this.panel = this.panel === 'help' ? '' : 'help';
        })
      }.width(BASE_TOOLBAR_HEIGHT).height(BASE_TOOLBAR_HEIGHT).borderRadius(BASE_TOOLBAR_HEIGHT / 2).attributeModifier(baseToolbarVisualModifier)
    }.width('100%').height(BASE_TOOLBAR_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
    .padding({ left: 14, right: 14, top: BASE_TOOLBAR_SHADOW_GUTTER, bottom: BASE_TOOLBAR_SHADOW_GUTTER })
    .clip(false).hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private FloatingToolbar() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      // 局部横向底部 TabBar 提供材质生效区域；容器本身仍定位在页面顶部。
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() { Column().width('100%').height('100%') }.tabBar(this.Toolbar)
      }.vertical(false).scrollable(false).animationDuration(0)
      // TabBar 内部同样预留透明区域，避免系统材质阴影在按钮边缘被截断。
      .barHeight(BASE_TOOLBAR_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
      .width('100%').height(BASE_TOOLBAR_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
      .clip(false).hitTestBehavior(HitTestMode.Transparent)
    } else {
      this.Toolbar()
    }
  }

  @Builder
  private Display() {
    Scroll() {
      Column({ space: 7 }) {
        if (this.session.mode !== 'numeric') {
          Scroll() {
            Text(this.session.mode === 'integer' ? this.session.expression : this.session.floatText)
              .fontSize(25).fontFamily('monospace').fontColor($r('sys.color.font_primary'))
              .copyOption(CopyOptions.LocalDevice).maxLines(1).padding({ left: 8, right: 8 })
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(40).width('100%').id('base.expression')
        }
        if (this.session.error.length > 0) {
          Text(this.session.error).fontSize(12).fontColor($r('sys.color.warning')).width('100%').id('base.error')
        } else if (this.session.mode === 'numeric' && !this.session.numeric.previewValid) {
          Text($r('app.string.base_numeric_preview_pending'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('sys.color.warning'))
            .id('base.numeric.preview')
        } else if (this.session.mode === 'integer' && !this.session.evaluated) {
          Text('输入预览 · 按 = 确认；不完整输入保留最近有效值')
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        } else if (this.session.mode === 'float' && !this.session.floatEvaluated) {
          Text(this.session.floatPreviewValid ? $r('app.string.programmer_float_preview_ready') :
            $r('app.string.programmer_float_preview_pending'))
            .fontSize(12).width('100%').id('base.float.preview')
            .fontColor(this.session.floatPreviewValid ? $r('sys.color.font_secondary') : $r('sys.color.warning'))
        }
        if (this.session.mode === 'numeric') {
          this.NumericRadixRow('HEX', 16)
          this.NumericRadixRow('DEC', 10)
          this.NumericRadixRow('OCT', 8)
          this.BinaryRadixRow()
          this.NumericControls()
        } else {
          this.RadixRow('HEX', 16)
          this.RadixRow('DEC', 10)
          if (this.session.mode === 'integer') { this.RadixRow('OCT', 8) }
          this.BinaryRadixRow()
        }
        if (this.session.mode === 'integer') {
          Row({ space: 6 }) {
            Select([{ value: '8 bit · BYTE' }, { value: '16 bit · WORD' }, { value: '32 bit · DWORD' }, { value: '64 bit · QWORD' }])
              .selected([8, 16, 32, 64].indexOf(this.session.width)).value(this.session.width + ' bit').font({ size: 14 }).height(34)
              .id('base.width').onSelect((index: number) => this.select(() => this.session.changeWidth([8, 16, 32, 64][index])))
            BaseChip({ label: this.session.signed ? '有符号' : '无符号', selected: this.session.signed,
              onActivate: () => this.apply(() => this.session.changeSigned()), semanticId: 'base.signed' })
            Blank()
            BaseChip({ label: '位', selected: this.panel === 'bits',
              onActivate: () => { this.panel = this.panel === 'bits' ? '' : 'bits'; }, semanticId: 'base.bits' })
            BaseChip({ label: '编码', selected: this.panel === 'encoding',
              onActivate: () => { this.panel = this.panel === 'encoding' ? '' : 'encoding'; }, semanticId: 'base.encoding' })
          }.width('100%')
          Row({ space: 12 }) {
            IntegerFlag({ label: 'CF', flagValue: this.session.flags.cf })
            IntegerFlag({ label: 'OF', flagValue: this.session.flags.of })
            IntegerFlag({ label: 'ZF', flagValue: this.session.flags.zf })
            IntegerFlag({ label: 'SF', flagValue: this.session.flags.sf })
            Blank()
            BaseChip({ label: 'C-in ' + this.session.carry, selected: this.session.carry === 1,
              onActivate: () => this.apply(() => { this.session.carry = 1 - this.session.carry; }), semanticId: 'base.carry' })
          }.width('100%')
        } else if (this.session.mode === 'float') {
          Row() {
            Select([{ value: 'binary16' }, { value: 'binary32' }, { value: 'binary64' }])
              .selected([16, 32, 64].indexOf(this.session.floatWidth))
              .value('binary' + this.session.floatWidth).font({ size: 14 }).height(34)
              .id('base.float.width')
              .onSelect((index: number) => this.select(() => this.session.changeFloatWidth([16, 32, 64][index])))
            Blank()
            BaseChip({ label: '字段', selected: this.panel === 'bits',
              onActivate: () => { this.panel = this.panel === 'bits' ? '' : 'bits'; }, semanticId: 'base.bits' })
          }.width('100%')
          Text(decodeFloat(this.session.displayedFloatBits(), this.session.floatWidth).category + ' · 按 = 确认输入')
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        }
        if (this.session.mode === 'numeric' && this.panel === 'help') {
          Text($r('app.string.base_numeric_help'))
            .width('100%')
            .padding(14)
            .fontSize(14)
            .lineHeight(23)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
        } else if (this.session.mode !== 'numeric' && this.panel.length > 0) {
          BaseInspector({ session: this.session, panel: this.panel,
            onFlip: (index: number) => this.select(() => this.session.flip(index)) })
        }
      }.width('100%').padding({ left: 14, right: 14, top: BASE_TOOLBAR_TOP_OFFSET + BASE_TOOLBAR_HEIGHT + BASE_CONTENT_TOP_GAP - BASE_PAGE_TOP_OFFSET,
        bottom: this.keyboardHeight() + 12 })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .padding({ top: this.statusBarHeight + BASE_PAGE_TOP_OFFSET })
  }

  private keyboardColumns(): number { return this.session.mode === 'numeric' ? 4 : 5; }

  private keyboardKeys(): string[] {
    if (this.session.mode === 'numeric') return NUMERIC_KEYS;
    return this.session.mode === 'integer' ? INTEGER_KEYS : FLOAT_KEYS;
  }

  private keyboardKeySpan(index: number): number {
    // GridItem 跨列时跳过被合并格；合并不能越过当前键盘的行边界。
    const keys = this.keyboardKeys();
    const columns = this.keyboardColumns();
    const column = index % columns;
    if (column > 0 && keys[index - 1] === keys[index]) return 0;
    let span = 1;
    while (column + span < columns && index + span < keys.length && keys[index + span] === keys[index]) span++;
    return span;
  }

  @Builder
  private Keyboard(immersive: boolean) {
    Grid() {
      ForEach(this.keyboardKeys(), (key: string, index: number) => {
        if (this.keyboardKeySpan(index) > 0) {
          GridItem() {
            BaseKey({ keyText: key, immersive: immersive, available: this.session.inputEnabled(key),
              integerMode: this.session.mode === 'integer', onPress: (action: string) => this.press(action) })
          }.rowStart(Math.floor(index / this.keyboardColumns())).rowEnd(Math.floor(index / this.keyboardColumns()))
            .columnStart(index % this.keyboardColumns()).columnEnd(index % this.keyboardColumns() + this.keyboardKeySpan(index) - 1)
        }
      }, (key: string, index: number) => this.session.mode + '.' + index.toString() + '.' + key)
    }.columnsTemplate(this.session.mode === 'numeric' ? '1fr 1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr').rowsTemplate(this.session.mode === 'numeric' ? '1fr 1fr 1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr 1fr')
    .rowsGap(8).columnsGap(8).width('100%').height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 + Math.max(0, this.navBarHeight - 8) })
  }

  @Builder
  private ImmersiveKeyboard() {
    Column() { this.Keyboard(true) }.width('100%').height('100%').borderRadius({ topLeft: 28, topRight: 28 })
      .backgroundColor($r('sys.color.comp_background_primary'))
  }
  @Builder
  private LegacyKeyboardLayout() {
    Column() { this.Keyboard(false) }.height('100%').width('100%').borderRadius({ topLeft: 28, topRight: 28 })
      .backgroundColor($r('sys.color.comp_background_primary'))
  }
  @Builder
  private ImmersiveKeyboardLayout() {
    // API 26 材质需位于受支持的底部 TabBar 区域，传统路径仍由独立容器承载。
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column().width('100%').height('100%')
      }.tabBar(this.ImmersiveKeyboard)
    }.vertical(false).scrollable(false).animationDuration(0).barHeight('100%').width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.Display()
      Column() {
        if (deviceInfo.apiAvailable('26.0.0')) {
          if (this.keyImmersiveMaterial) { this.ImmersiveKeyboardLayout() }
          else { this.LegacyKeyboardLayout() }
        } else { this.LegacyKeyboardLayout() }
      }.width('100%').height(this.keyboardHeight()).zIndex(1)
      // 阴影留白不改变可见顶栏位置，透明区域允许触摸传递给下方滚动页。
      Column() { this.FloatingToolbar() }
        .width('100%').height(BASE_TOOLBAR_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
        .clip(false).hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: this.statusBarHeight + BASE_TOOLBAR_TOP_OFFSET - BASE_TOOLBAR_SHADOW_GUTTER }).zIndex(2)
    }.width('100%').height('100%').backgroundColor($r('sys.color.comp_background_tertiary'))
    .onAreaChange((_, area: Area) => { this.pageHeight = Number(area.height); }).id('base.programmer')
    .accessibilityDescription(this.semanticState())
  }
}
