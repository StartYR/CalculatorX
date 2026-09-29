/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BaseConverter.ets
 * @description 进制转换页面、输入会话与双路径键盘装配
 * @author StartYi
 * @date 2026/7/24 22:53
 */

import deviceInfo from '@ohos.deviceInfo';
import pasteboard from '@ohos.pasteboard';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

import { createTopBarMaterial, createDialogMaterial } from '../../../utils/ImmersiveMaterialUtils';
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
const BASE_TOOLBAR_TOP_OFFSET: number = 48   // 顶栏距状态栏底部的距离
const BASE_TOOLBAR_HEIGHT: number = 38;      // 顶栏可见高度
const BASE_CONTENT_TOP_GAP: number = 12;     // 初始内容与顶栏底部的间距
// 页面视口避开应用标题栏；材质留白仅容纳阴影，不计入顶栏可见高度。
const BASE_PAGE_TOP_OFFSET: number = 56;
const BASE_TOOLBAR_SHADOW_GUTTER: number = 24;
const BASE_KEYBOARD_SLIDE_DURATION: number = 280;
// 唤起按钮的可见尺寸；外层另加阴影留白。
const BASE_KEYBOARD_RESTORE_WIDTH: number = 72;
const BASE_KEYBOARD_RESTORE_HEIGHT: number = 50;

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

@CustomDialog
struct BaseHelpDialog {
  controller?: CustomDialogController;
  @Link mode: string;

  private title(): string {
    return (this.mode === 'numeric' ? '数值' : this.mode === 'integer' ? '整数' : 'IEEE 754') + '帮助';
  }

  private message(): Resource {
    return this.mode === 'numeric' ? $r('app.string.base_numeric_help') :
      this.mode === 'integer' ? $r('app.string.base_integer_help') : $r('app.string.programmer_float_help');
  }

  build() {
    Column({ space: 14 }) {
      Text(this.title())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')

      Scroll() {
        Text(this.message())
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 360 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row() {
        Button('关闭')
          .type(ButtonType.Capsule)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .height(40)
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .padding(20)
    .width('100%')
  }
}

@Component
export struct BaseConverter {
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @State @Watch('syncKeyboardAnimation') session: BaseConversionSession = new BaseConversionSession();
  @State @Watch('syncKeyboardAnimation') panel: string = '';
  @State keyboardSlide: number = 0;
  @State restoreButtonMounted: boolean = false;
  @State private helpMode: string = 'numeric';
  private helpDialogController: CustomDialogController = new CustomDialogController({
    builder: BaseHelpDialog({ mode: $helpMode }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    cornerRadius: 28,
    systemMaterial: createDialogMaterial()
  });
  private keyboardHiddenTarget: boolean = false;
  private keyboardAnimationRevision: number = 0;
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
    this.keyboardAnimationRevision++;
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
      numericPreviewValid: this.session.numeric.previewValid, panel: this.panel, keyboardHidden: this.keyboardHidden() });
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

  private showPasteToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000, bottom: 80 });
  }

  private pastePending: boolean = false;

  private async requestPaste(): Promise<void> {
    if (this.pastePending) return;
    this.pastePending = true;
    const sourceSession = this.session;
    try {
      // 只在点击后检查文本类型，空剪贴板不触发权限申请，也不提前读取内容。
      const board = pasteboard.getSystemPasteboard();
      if (!board.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN)) {
        this.showPasteToast('剪贴板没有可粘贴的文本');
        return;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(
        context, ['ohos.permission.READ_PASTEBOARD']);
      if (result.authResults.length !== 1 || result.authResults[0] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.showPasteToast('未获得剪贴板权限，可在系统设置中允许；也可继续手动输入');
        return;
      }
      // 授权等待期间输入会话可能被切换或编辑，不把结果写入另一份输入。
      if (this.session !== sourceSession) return;
      await this.paste();
    } catch (_) {
      this.showPasteToast('无法申请剪贴板权限，请检查应用授权配置');
    } finally {
      this.pastePending = false;
    }
  }

  private async paste(): Promise<void> {
    let text: string;
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      text = data.getPrimaryText().trim();
    } catch (_) {
      this.showPasteToast('粘贴失败：无法读取剪贴板');
      return;
    }
    // 先在副本校验，失败不替换输入、不新增撤销记录，也不生成页面内提示行。
    const next = this.session.copy();
    try {
      if (text.length === 0) throw new Error('剪贴板没有可粘贴的文本');
      if (text.length > (next.mode === 'integer' ? 1024 : 768)) throw new Error('剪贴板输入过长');
      next.error = '';
      if (next.mode === 'numeric') {
        next.numeric.replaceInput(text);
        if (!next.numeric.previewValid) next.numeric.confirm();
      } else if (next.mode === 'integer') {
        next.expression = text;
        next.evaluated = false;
        next.confirm();
      } else {
        next.replaceFloatInput(text);
        if (!next.floatPreviewValid) next.confirm();
      }
    } catch (error) {
      this.showPasteToast('粘贴失败：' + (error as Error).message);
      return;
    }
    // 浮点与数值仍停留在有效预览，只有整数粘贴直接确认。
    this.apply(() => { this.session = next; });
    this.showPasteToast('已粘贴');
  }

  private changeMode(mode: string): void {
    if (this.session.mode === mode) return;
    // 面板只属于当前页面；切换模式收起面板，输入会话仍各自保留。
    this.apply(() => { this.session.mode = mode; this.session.error = ''; this.panel = ''; });
  }

  private keyboardHidden(): boolean {
    // 数值模式始终显示键盘；帮助弹窗不改变升降状态，位/编码切换时保持收起。
    return this.session.mode !== 'numeric' && (this.panel === 'bits' || this.panel === 'encoding');
  }

  private syncKeyboardAnimation(): void {
    const hidden = this.keyboardHidden();
    if (hidden === this.keyboardHiddenTarget) return;
    this.keyboardHiddenTarget = hidden;
    const revision = ++this.keyboardAnimationRevision;
    // 下滑前挂载按钮，上滑完成才卸载；旧动画回调不能覆盖后一次切换。
    if (hidden) this.restoreButtonMounted = true;
    this.getUIContext().animateTo({
      duration: BASE_KEYBOARD_SLIDE_DURATION, curve: Curve.EaseInOut,
      onFinish: () => {
        if (revision === this.keyboardAnimationRevision && !this.keyboardHidden()) {
          this.restoreButtonMounted = false;
        }
      }
    }, () => { this.keyboardSlide = hidden ? 1 : 0; });
  }

  private restoreButtonBottom(): number {
    return Math.max(this.navBarHeight, 12) + 0;
  }

  private contentBottomInset(): number {
    return this.keyboardHidden() ? this.restoreButtonBottom() + BASE_KEYBOARD_RESTORE_HEIGHT + 12 :
      this.keyboardHeight() + 12;
  }

  private keyboardHeight(): number {
    return Math.min(390, Math.max(200, this.pageHeight * 0.42)) + Math.max(0, this.navBarHeight - 8);
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

  private async copyRadix(radix: number): Promise<void> {
    try {
      // 分行仅用于排版，复制仍提供连续完整文本，避免换行混入后续输入。
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.value(radix)));
    } catch (_) { this.session.error = '无法复制数值'; this.session = this.session.copy(); }
  }

  @Builder
  private RadixCopyMenu(radix: number) {
    Menu() {
      MenuItem({ content: $r('app.string.base_copy_value') }).onClick(() => { this.copyRadix(radix); })
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
      .bindContextMenu(() => { this.RadixCopyMenu(2); }, ResponseType.LongPress)
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
        .fontColor($r('sys.color.font_primary'))
        .bindContextMenu(() => { this.RadixCopyMenu(radix); }, ResponseType.LongPress)
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
        .bindContextMenu(() => { this.RadixCopyMenu(radix); }, ResponseType.LongPress)
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

  private showHelp(): void {
    // 帮助使用独立弹窗，不更改检查面板和键盘的当前状态。
    this.helpMode = this.session.mode;
    this.helpDialogController.open();
  }

  @Builder
  private Toolbar() {
    Row({ space: 8 }) {
      Row() {
        BaseChip({ label: $r('app.string.base_numeric_tab'), selected: this.session.mode === 'numeric', stretch: true,
          onActivate: () => {
            this.changeMode('numeric');
          }, semanticId: 'base.mode.numeric' }).layoutWeight(1)
        BaseChip({ label: '整数', selected: this.session.mode === 'integer', stretch: true,
          onActivate: () => {
            this.changeMode('integer');
          }, semanticId: 'base.mode.integer' }).layoutWeight(1)
        BaseChip({ label: 'IEEE 754', selected: this.session.mode === 'float', stretch: true,
          onActivate: () => {
            this.changeMode('float');
          }, semanticId: 'base.mode.float' }).layoutWeight(1.35)
      }.layoutWeight(1).height(BASE_TOOLBAR_HEIGHT).padding(4).borderRadius(BASE_TOOLBAR_HEIGHT / 2)
      .attributeModifier(baseToolbarVisualModifier)
      Row() {
        Button('粘贴').width('100%').height('100%').padding(0).fontSize(13)
          .fontColor($r('sys.color.font_primary')).backgroundColor(Color.Transparent)
          .id('base.paste').accessibilityText('粘贴')
          .onClick(() => {
            HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
            this.requestPaste();
          })
      }.width(52).height(BASE_TOOLBAR_HEIGHT).borderRadius(BASE_TOOLBAR_HEIGHT / 2).attributeModifier(baseToolbarVisualModifier)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(22)
            .fontColor([$r('sys.color.font_secondary')])
        }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
        .id('base.help').accessibilityText('帮助')
        .onClick(() => {
          HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
          this.showHelp();
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

  private restoreKeyboard(): void {
    HapticUtils.playVibration('select', this.hapticFeedback, this.vibrationCurve);
    this.panel = '';
  }

  @Builder
  private KeyboardRestoreButton() {
    Row() {
      Row() {
        Button() {
          Column() {
            Text('△').fontFamily('Cambria Math').fontSize(12).lineHeight(14).fontColor($r('sys.color.font_emphasize'))
            Text('⌨').fontFamily('Cambria Math').fontSize(24).lineHeight(26).fontColor($r('sys.color.font_emphasize'))
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
          .id('base.keyboard.show').accessibilityText('显示键盘并关闭展开面板')
          .onClick(() => this.restoreKeyboard())
      }.width(BASE_KEYBOARD_RESTORE_WIDTH).height(BASE_KEYBOARD_RESTORE_HEIGHT).borderRadius(BASE_KEYBOARD_RESTORE_HEIGHT / 2)
      .attributeModifier(baseToolbarVisualModifier)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    .padding(BASE_TOOLBAR_SHADOW_GUTTER).clip(false).hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private FloatingKeyboardRestore() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      // 独立 TabBar 为悬浮按钮提供光感区域，透明留白容纳材质阴影。
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() { Column().width('100%').height('100%') }.tabBar(this.KeyboardRestoreButton)
      }.vertical(false).scrollable(false).animationDuration(0).barHeight('100%')
      .width('100%').height('100%').clip(false).hitTestBehavior(HitTestMode.Transparent)
    } else {
      this.KeyboardRestoreButton()
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
        } else if (this.session.mode === 'float' && !this.session.floatEvaluated && !this.session.floatPreviewValid) {
          Text($r('app.string.programmer_float_preview_pending'))
            .fontSize(12).width('100%').id('base.float.preview')
            .fontColor($r('sys.color.warning'))
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
          Text(decodeFloat(this.session.displayedFloatBits(), this.session.floatWidth).category)
            .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
        }
        if (this.session.mode !== 'numeric' && this.panel.length > 0) {
          BaseInspector({ session: this.session, panel: this.panel,
            onFlip: (index: number) => this.select(() => this.session.flip(index)) })
        }
      }.width('100%').padding({ left: 14, right: 14, top: BASE_TOOLBAR_TOP_OFFSET + BASE_TOOLBAR_HEIGHT + BASE_CONTENT_TOP_GAP - BASE_PAGE_TOP_OFFSET,
        bottom: this.contentBottomInset() })
      .animation({ duration: BASE_KEYBOARD_SLIDE_DURATION, curve: Curve.EaseInOut })
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
    .padding({ left: 12, right: 12, top: 12, bottom: Math.max(0, this.navBarHeight - 8) })
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
      }.width('100%').height(this.keyboardHeight()).zIndex(2)
      // 键盘保持挂载以完成进出动画；收起后立即退出命中和无障碍遍历。
      .enabled(!this.keyboardHidden())
      .hitTestBehavior(this.keyboardHidden() ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.keyboardHidden() ? 'no-hide-descendants' : 'auto')
      .translate({ y: this.keyboardSlide * (this.keyboardHeight() + BASE_TOOLBAR_SHADOW_GUTTER) })
      if (this.restoreButtonMounted) {
        Column() { this.FloatingKeyboardRestore() }
        .width(BASE_KEYBOARD_RESTORE_WIDTH + BASE_TOOLBAR_SHADOW_GUTTER * 2)
        .height(BASE_KEYBOARD_RESTORE_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
        .margin({ bottom: this.restoreButtonBottom() - BASE_TOOLBAR_SHADOW_GUTTER })
        .clip(false).hitTestBehavior(HitTestMode.Transparent).zIndex(1)
        .enabled(this.keyboardHidden())
        .accessibilityLevel(this.keyboardHidden() ? 'auto' : 'no-hide-descendants')
      }
      // 阴影留白不改变可见顶栏位置，透明区域允许触摸传递给下方滚动页。
      Column() { this.FloatingToolbar() }
      .width('100%').height(BASE_TOOLBAR_HEIGHT + BASE_TOOLBAR_SHADOW_GUTTER * 2)
      .clip(false).hitTestBehavior(HitTestMode.Transparent)
      .position({ x: 0, y: this.statusBarHeight + BASE_TOOLBAR_TOP_OFFSET - BASE_TOOLBAR_SHADOW_GUTTER }).zIndex(3)
    }.width('100%').height('100%').backgroundColor($r('sys.color.comp_background_tertiary'))
    .onAreaChange((_, area: Area) => { this.pageHeight = Number(area.height); }).id('base.programmer')
    .accessibilityDescription(this.semanticState())
  }
}
