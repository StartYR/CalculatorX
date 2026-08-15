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
import { LengthMetrics } from '@kit.ArkUI';

// ==================== 1. 模拟数据层 ====================
interface CurrencyInfo {
  code: string;
  name: string;
  symbol: string;
  rate: number;
}

const MOCK_CURRENCIES: Record<string, CurrencyInfo> = {
  'USD': { code: 'USD', name: '美元', symbol: '$', rate: 1 },
  'CNY': { code: 'CNY', name: '人民币', symbol: '¥', rate: 7.15 },
  'EUR': { code: 'EUR', name: '欧元', symbol: '€', rate: 0.92 },
  'JPY': { code: 'JPY', name: '日元', symbol: '¥', rate: 150.5 },
  'GBP': { code: 'GBP', name: '英镑', symbol: '£', rate: 0.79 },
  'HKD': { code: 'HKD', name: '港币', symbol: 'HK$', rate: 7.82 },
};

export class CurrencyListItem {
  id: string;
  code: string;
  constructor(id: string, code: string) {
    this.id = id;
    this.code = code;
  }
}

// ==================== 局部样式辅助函数 ====================
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
  @State currencyList: Array<CurrencyListItem> = [
    new CurrencyListItem('1', 'USD'),
    new CurrencyListItem('2', 'CNY')
  ];
  @State activeId: string = '1';
  @State baseAmount: string = '100';

  @State lastUpdateTime: string = '刚刚';
  @State isSelectorShow: boolean = false;
  @State selectingId: string = '';
  @State searchQuery: string = '';

  private draggedIndex: number = -1;

  @StorageProp('topRectHeight') topRectHeight: number = 80;

  aboutToAppear() {
    Logger.info('[ExchangeRate] 模块初始化');
  }

  // --- 核心换算与状态管理逻辑 ---
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

  isCurrencySelected(code: string): boolean {
    let selectingItem = this.currencyList.find(c => c.id === this.selectingId);
    return selectingItem ? selectingItem.code === code : false;
  }

  setActiveCurrency(id: string, code: string) {
    if (this.activeId !== id) {
      this.baseAmount = this.getConvertedAmount(code, false);
      this.activeId = id;
    }
  }

  // --- 列表交互操作 ---
  openSelector(id: string) {
    this.selectingId = id;
    this.searchQuery = '';
    this.isSelectorShow = true;
  }

  selectCurrency(code: string) {
    let index = this.currencyList.findIndex(item => item.id === this.selectingId);
    if (index !== -1) {
      this.currencyList.splice(index, 1, new CurrencyListItem(this.selectingId, code));
    }
    this.isSelectorShow = false;
  }

  deleteCurrency(id: string) {
    // 启动物理阻尼动画，平滑移除元素并使下方项自动补位
    animateTo({ duration: 350, curve: Curve.Friction }, () => {
      let index = this.currencyList.findIndex(item => item.id === id);
      if (index !== -1) {
        this.currencyList.splice(index, 1);
        if (this.activeId === id && this.currencyList.length > 0) {
          this.activeId = this.currencyList[0].id;
          this.baseAmount = '0';
        }
      }
    });
  }

  addCurrency() {
    let newId = new Date().getTime().toString();
    // 启动物理阻尼动画，确保新元素自然滑入列表尾部
    animateTo({ duration: 350, curve: Curve.Friction }, () => {
      this.currencyList.push(new CurrencyListItem(newId, 'USD'));
    });
  }

  handleRefresh() {
    Logger.info('[ExchangeRate] 触发汇率刷新任务');
  }

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
      // 保留作为纯震动反馈键
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

  // --- UI 构建器区 ---

  // 侧滑删除操作区：复用组件统一样式
  @Builder
  deleteAction(id: string) {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(24)
          .fontColor([Color.White])
      }
      .width(48)
      .height(48)
      .backgroundColor('#FF3B30')
      .shadow({ radius: 8, color: '#33FF3B30', offsetY: 4 })
      .onClick(() => {
        this.deleteCurrency(id);
      })
    }
    .height('100%')
    .padding({ left: 16, right: 24 })
    .justifyContent(FlexAlign.Center)
  }

  // 拖拽占位符：利用透明视图完全屏蔽原生拖拽视觉残留
  @Builder
  dragFeedback() {
    Column()
      .width('100%')
      .height(84)
      .opacity(0)
  }

  build() {
    Column() {
      // 全局数据渲染列表
      List({ space: 8 }) {
        // 列表头部：非货币项，避免干扰主数据序列
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
          .padding({ left: 24, right: 24, top: this.topRectHeight + 12, bottom: 4 })
        }

        // 核心循环：采用一维拍平结构提升性能与交互可塑性
        ForEach(this.currencyList, (item: CurrencyListItem, index: number) => {
          ListItem() {
            Row() {
              // 左侧功能区：货币类型选择器
              Row() {
                Text(item.code)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                Image($r('sys.media.ohos_ic_public_arrow_down'))
                  .width(16).height(16)
                  .fillColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                  .margin({ left: 4 })
              }
              .padding({ top: 8, bottom: 8, left: 12, right: 12 })
              .borderRadius(12)
              .backgroundColor(this.activeId === item.id ? $r('sys.color.comp_background_tertiary') : Color.Transparent)
              .onClick(() => this.openSelector(item.id))
              .margin({ right: 14 })
              .alignSelf(ItemAlign.Center)

              // 右侧内容区：两行式布局（输入区/输出区映射）
              Column() {
                Column() {
                  Text(MOCK_CURRENCIES[item.code].name)
                    .fontSize(14)
                    .fontColor($r('sys.color.font_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                }
                .width('100%')
                .padding({ top: 12, bottom: 2 })
                .onClick(() => this.setActiveCurrency(item.id, item.code))

                Column() {
                  Text(`${MOCK_CURRENCIES[item.code].symbol} ${this.getConvertedAmount(item.code, this.activeId === item.id)}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.End)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ top: 2, bottom: 12 })
                .onClick(() => this.setActiveCurrency(item.id, item.code))
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16 })
          .swipeAction({
            end: { builder: () => { this.deleteAction(item.id) } },
            edgeEffect: SwipeEdgeEffect.Spring
          })
        }, (item: CurrencyListItem) => item.id + '_' + item.code)

        // 列表尾部：追加新项
        ListItem() {
          Row() {
            Button() {
              Row() {
                SymbolGlyph($r('sys.symbol.plus'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.font_emphasize')])
                  .margin({ right: 8 })
                Text('添加货币')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_emphasize'))
              }
              .justifyContent(FlexAlign.Center)
            }
            .type(ButtonType.Normal)
            .borderRadius(16)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .width('100%')
            .height(56)
            .onClick(() => this.addCurrency())
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 32 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ top: 0, bottom: 0 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(12) })
      // 启用拖拽排序拦截
      .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
        let actualIndex = itemIndex - 1;
        if (actualIndex < 0 || actualIndex >= this.currencyList.length) return undefined;

        this.draggedIndex = actualIndex;
        return this.dragFeedback();
      })
      .onItemDragMove((event: ItemDragInfo, itemIndex: number, insertIndex: number) => {
        let actualInsertIndex = insertIndex - 1;
        if (actualInsertIndex < 0) actualInsertIndex = 0;
        if (actualInsertIndex >= this.currencyList.length) actualInsertIndex = this.currencyList.length - 1;

        if (this.draggedIndex === actualInsertIndex) return;

        // 核心交互：通过响应式状态绑定阻尼曲线，在手指拖拽区间实现列表项动态规避
        animateTo({ duration: 350, curve: Curve.Friction }, () => {
          let item = this.currencyList.splice(this.draggedIndex, 1)[0];
          this.currencyList.splice(actualInsertIndex, 0, item);
          this.draggedIndex = actualInsertIndex;
        });
      })
      .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
        this.draggedIndex = -1;
      })

      Blank()

      // ==================== 底部输入键盘 ====================
      ExchangeKeyboard({
        onKeyPress: (btn: string | Resource) => {
          this.handleKeyboardInput(btn);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
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

// ==================== 底层键盘组件 ====================
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