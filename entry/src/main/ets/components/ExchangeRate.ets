/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file ExchangeRate.ets
 * @description 请在此处输入文件描述...
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:53
 */

import Logger from '../utils/Logger';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor, icon_backspace, PreferenceConfigs } from '../utils/CalculatorConfigs';
import { KeyGestureWrapper } from './common/KeyGestureWrapper';

// ==================== 1. 模拟数据层 (Mock) ====================
// TODO: 未来将被 API 真实数据替换
interface CurrencyInfo {
  code: string;    // 货币代码 (如 USD)
  name: string;    // 货币名称 (如 美元)
  symbol: string;  // 符号 (如 $)
  rate: number;    // 相对基准货币(如USD)的汇率
}

const MOCK_CURRENCIES: Record<string, CurrencyInfo> = {
  'USD': { code: 'USD', name: '美元', symbol: '$', rate: 1 },
  'CNY': { code: 'CNY', name: '人民币', symbol: '¥', rate: 7.15 },
  'EUR': { code: 'EUR', name: '欧元', symbol: '€', rate: 0.92 },
  'JPY': { code: 'JPY', name: '日元', symbol: '¥', rate: 150.5 },
  'GBP': { code: 'GBP', name: '英镑', symbol: '£', rate: 0.79 },
  'HKD': { code: 'HKD', name: '港币', symbol: 'HK$', rate: 7.82 },
};

// 显式声明类
export class CurrencyListItem {
  id: string;
  code: string;
  constructor(id: string, code: string) {
    this.id = id;
    this.code = code;
  }
}

// ==================== 局部样式函数 (完全照搬) ====================
function getLocalFontColor(btn: string | Resource): ResourceColor {
  if (btn === 'π' || btn === 'e') return getFontColor('0');
  if (btn === '确定' || btn === '关闭') return getFontColor('=');
  return getFontColor(btn);
}

function getLocalBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  if (btn === 'π' || btn === 'e') return getBgColor('0', false);
  if (btn === '确定') return getBgColor('=', false);
  if (btn === '关闭') return Color.Red;
  return getBgColor(btn, isShift);
}

function getLocalFontSize(btn: string | Resource): number {
  if (btn === 'π' || btn === 'e') return getFontSize('0');
  if (btn === 't' || btn === 'θ' || btn === 'x' || btn === 'y') return getFontSize('0');
  return getFontSize(btn);
}

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

// ==================== 2. 主组件 ====================
@Component
export struct ExchangeRate {
  // --- 状态变量 ---
  @State currencyList: Array<CurrencyListItem> = [
    new CurrencyListItem('1', 'USD'),
    new CurrencyListItem('2', 'CNY')
  ];
  @State activeId: string = '1'; // 当前正在输入的目标 ID
  @State baseAmount: string = '100'; // 当前激活项的输入金额

  @State lastUpdateTime: string = '刚刚 (Mock)'; // 最后更新时间显示

  // --- 货币选择器 (bindSheet) 状态 ---
  @State isSelectorShow: boolean = false;
  @State selectingId: string = ''; // 当前正在为哪个列表项选择货币
  @State searchQuery: string = ''; // 搜索关键字

  // 预留顶部安全距离（包含状态栏与 TopBar），具体 key 名请根据实际情况微调
  @StorageProp('topRectHeight') topRectHeight: number = 80;

  aboutToAppear() {
    Logger.info('[ExchangeRate] 模块初始化');
  }

  // --- 核心计算逻辑 ---
  getConvertedAmount(targetCode: string, isEditing: boolean): string {
    if (isEditing) return this.baseAmount;
    if (!this.baseAmount || this.baseAmount === 'Error' || this.baseAmount === '0') return '0';

    try {
      let inputVal = parseFloat(this.baseAmount);
      if (isNaN(inputVal)) return '0';

      let activeItem = this.currencyList.find(item => item.id === this.activeId);
      if (!activeItem) return '0';

      let rateFrom = MOCK_CURRENCIES[activeItem.code].rate;
      let rateTo = MOCK_CURRENCIES[targetCode].rate;
      let result = inputVal * (rateTo / rateFrom);

      return parseFloat(result.toFixed(4)).toString();
    } catch (err) {
      Logger.error(`[ExchangeRate] 计算异常: ${err}`);
      return 'Error';
    }
  }

  // 获取当前激活项的提示文本
  getActiveCurrencyText(): string {
    let activeItem = this.currencyList.find(i => i.id === this.activeId);
    return activeItem ? `基准货币: 1 ${activeItem.code}` : '当前无选中项';
  }

  // 判断选择器中的某一项是否为当前正在选择的项
  isCurrencySelected(code: string): boolean {
    let selectingItem = this.currencyList.find(c => c.id === this.selectingId);
    return selectingItem ? selectingItem.code === code : false;
  }

  // --- 交互处理函数 ---
  openSelector(id: string) {
    Logger.info(`[ExchangeRate] 打开货币选择器: ${id}`);
    this.selectingId = id;
    this.searchQuery = '';
    this.isSelectorShow = true;
  }

  selectCurrency(code: string) {
    Logger.info(`[ExchangeRate] 选择货币 ${code} 替换列表项 ${this.selectingId}`);
    let index = this.currencyList.findIndex(item => item.id === this.selectingId);
    if (index !== -1) {
      this.currencyList[index].code = code;
    }
    this.isSelectorShow = false;
  }

  deleteCurrency(id: string) {
    Logger.info(`[ExchangeRate] 删除货币项: ${id}`);
    let index = this.currencyList.findIndex(item => item.id === id);
    if (index !== -1) {
      this.currencyList.splice(index, 1);
      // 如果删除了当前激活项，将焦点转移给第一个（如果还有剩余）
      if (this.activeId === id && this.currencyList.length > 0) {
        this.activeId = this.currencyList[0].id;
      }
    }
  }

  addCurrency() {
    let newId = new Date().getTime().toString();
    Logger.info(`[ExchangeRate] 新增货币项: ${newId}`);
    this.currencyList.push(new CurrencyListItem(newId, 'USD'));
  }

  handleRefresh() {
    Logger.info('[ExchangeRate] 用户点击手动刷新');
    // TODO: 接入真实 API 请求
  }

  // --- 键盘输入处理 ---
  handleKeyboardInput(btn: string | Resource) {
    let action = getLocalActionId(btn);

    if (action === 'AC') {
      this.baseAmount = '0';
    } else if (action === '⌫') {
      if (this.baseAmount.length > 1) {
        this.baseAmount = this.baseAmount.slice(0, -1);
      } else {
        this.baseAmount = '0';
      }
    } else if (action === '确定' || action === '−') {
      // 仅作震动反馈
    } else {
      if (this.baseAmount === '0' && action !== '.') {
        this.baseAmount = action;
      } else {
        if (action === '.' && this.baseAmount.includes('.')) return;
        if (this.baseAmount.length < 15) {
          this.baseAmount += action;
        }
      }
    }
  }

  // --- UI 构建器：左滑删除按钮 ---
  @Builder
  deleteButton(id: string) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Image($r('sys.symbol.trash_fill'))
        .width(24).height(24)
        .fillColor(Color.White)
    }
    .width(48).height(48)
    .backgroundColor(Color.Red)
    .margin({ left: 16, right: 16 })
    .onClick(() => this.deleteCurrency(id))
  }

  // --- UI 构建器：拖拽时的视觉反馈 ---
  @Builder
  dragFeedback(item: CurrencyListItem) {
    Row() {
      Text(item.code)
        .fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Blank()
      Text(`${MOCK_CURRENCIES[item.code].symbol} ${this.getConvertedAmount(item.code, this.activeId === item.id)}`)
        .fontSize(32).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
    }
    .width('90%')
    .padding({ left: 24, right: 24, top: 20, bottom: 20 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .shadow({ radius: 20, color: '#33000000', offsetY: 10 })
    .scale({ x: 1.05, y: 1.05 })
  }

  // ==================== 3. 页面渲染 ====================
  build() {
    Column() {
      // 动态货币列表
      List({ space: 8 }) {
        // 将更新时间作为普通列表项，随列表滚动，彻底移除基准货币提示
        ListItem() {
          Row() {
            Text(`上次更新: ${this.lastUpdateTime}`)
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))

            Blank()

            Button('更新')
              .fontSize(14)
              .fontColor($r('sys.color.font_emphasize'))
              .backgroundColor(Color.Transparent)
              .onClick(() => this.handleRefresh())
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: this.topRectHeight + 12, bottom: 12 })
        }

        ForEach(this.currencyList, (item: CurrencyListItem, index: number) => {
          ListItem() {
            Row() {
              // 货币选择器按钮
              Row() {
                Text(item.code)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                Image($r('sys.media.ohos_ic_public_arrow_down'))
                  .width(20).height(20)
                  .fillColor($r('sys.color.font_secondary'))
                  .margin({ left: 8 })
              }
              .padding(8)
              .borderRadius(8)
              .backgroundColor(this.activeId === item.id ? $r('sys.color.comp_background_tertiary') : Color.Transparent)
              .onClick(() => this.openSelector(item.id))

              Blank()

              // 转换结果显示区
              Text(`${MOCK_CURRENCIES[item.code].symbol} ${this.getConvertedAmount(item.code, this.activeId === item.id)}`)
                .fontSize(32)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 20, bottom: 20 })
            .backgroundColor(this.activeId === item.id ? $r('sys.color.comp_background_primary') : Color.Transparent)
            .borderRadius(16)
            .borderWidth(this.activeId === item.id ? 1 : 0)
            .borderColor($r('app.color.btn_highlight'))
            .onClick(() => {
              if (this.activeId !== item.id) {
                this.baseAmount = this.getConvertedAmount(item.code, false);
                this.activeId = item.id;
              }
            })
          }
          .swipeAction({ end: this.deleteButton(item.id) })
        }, (item: CurrencyListItem) => item.id)

        // 列表尾部：添加货币按钮
        ListItem() {
          Row() {
            Button('+ 添加货币')
              .fontSize(16)
              .fontColor($r('sys.color.font_emphasize'))
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .width('60%')
              .height(48)
              .onClick(() => this.addCurrency())
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 16, bottom: 32 })
        }
      }
      .width('100%')
      .layoutWeight(1) // 占满键盘上方空间
      .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
        if (itemIndex >= this.currencyList.length) return undefined;
        return this.dragFeedback(this.currencyList[itemIndex]);
      })
      .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
        if (!isSuccess || itemIndex === insertIndex || itemIndex >= this.currencyList.length) return;
        // 原生拖拽释放，交换数组项位置
        let draggedItem = this.currencyList.splice(itemIndex, 1)[0];
        let actualInsertIndex = insertIndex > itemIndex ? insertIndex - 1 : insertIndex;
        this.currencyList.splice(actualInsertIndex, 0, draggedItem);
      })

      Blank()

      // ==================== 键盘区 ====================
      ExchangeKeyboard({
        onKeyPress: (btn: string | Resource) => {
          this.handleKeyboardInput(btn);
        }
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isSelectorShow, this.CurrencySelectorBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      title: { title: '选择货币' }
    })
  }

  @Builder
  CurrencySelectorBuilder() {
    Column() {
      Search({ placeholder: '搜索货币代码或名称...', value: $$this.searchQuery })
        .width('100%')
        .margin({ bottom: 16 })
        .onChange((val: string) => {
          this.searchQuery = val.toUpperCase();
        })

      List() {
        ForEach(Object.values(MOCK_CURRENCIES).filter(item =>
        item.code.includes(this.searchQuery) || item.name.includes(this.searchQuery)
        ), (currency: CurrencyInfo) => {
          ListItem() {
            Row() {
              Text(currency.code)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .width(60)

              Text(currency.name)
                .fontSize(16)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ left: 16 })

              Blank()

              if (this.isCurrencySelected(currency.code)) {
                Image($r('sys.media.ohos_ic_public_ok'))
                  .width(20).height(20)
                  .fillColor($r('sys.color.font_emphasize'))
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 8, right: 8 })
          }
          .onClick(() => this.selectCurrency(currency.code))
        }, (item: CurrencyInfo) => item.code)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 16 })
  }
}
// ==================== 底层键盘组件 (完全照搬) ====================
@Component
export struct BottomKeyItem {
  btn: string | Resource = '';
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  customRadius?: number = 16;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    KeyGestureWrapper({
      actionId: getLocalActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'graphing',
      isShiftMode: $isShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      Button() {
        if (typeof this.btn === 'string') {
          Text(this.btn)
            .fontFamily(getFontFamily(this.btn))
            .fontSize(getLocalFontSize(this.btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getLocalFontColor(this.btn))
        } else {
          Image(this.btn)
            .width(48)
            .height(40)
            .fillColor(getFontColor(this.btn))
            .draggable(false)
        }
      }
      .type(ButtonType.Normal)
      .borderRadius(this.customRadius)
      .width('100%')
      .height('100%')
      .padding({ left: 4, right: 4 })
      .backgroundColor(getLocalBgColor(this.btn, false))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
      .borderColor($r('app.color.btn_highlight'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .stateStyles({
        pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
        normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
      })
    }
  }
}

export const domainButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace,
  '4', '5', '6', 'AC',
  '1', '2', '3', '−',
  '0', '.', '确定'
];

@Component
export struct ExchangeKeyboard {
  @State private isShift: boolean = false;
  onKeyPress: (btn: string | Resource) => void = () => {};

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  build() {
    Column() {
      Grid() {
        ForEach(domainButtons, (btn: string | Resource) => {
          GridItem() {
            BottomKeyItem({
              btn: btn,
              isShift: $isShift,
              customRadius: 36,
              onKeyPress: (b: string | Resource) => {
                let action = getActionId(b);
                HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
                this.onKeyPress(b);
              }
            })
          }
          .columnStart(btn === '0' ? 0 : undefined)
          .columnEnd(btn === '0' ? 1 : undefined)
        }, (btn: string | Resource) => typeof btn === 'string' ? btn : 'icon_backspace')
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      .height(260)
      .padding({ left: 10, right: 10, top: 12, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 16})
  }
}