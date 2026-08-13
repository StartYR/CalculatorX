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
  @State amountFrom: string = '100'; // 上方输入金额
  @State amountTo: string = '';      // 下方转换结果

  @State currencyFrom: string = 'USD'; // 上方选中的货币代码
  @State currencyTo: string = 'CNY';   // 下方选中的货币代码

  @State lastUpdateTime: string = '刚刚 (Mock)'; // 最后更新时间显示

  // --- 货币选择器 (bindSheet) 状态 ---
  @State isSelectorShow: boolean = false;
  @State selectingTarget: 'from' | 'to' = 'from'; // 当前正在为哪个输入框选择货币
  @State searchQuery: string = ''; // 搜索关键字
  @StorageProp('topRectHeight') topRectHeight: number = 80; // 预留顶部安全距离

  aboutToAppear() {
    Logger.info('[ExchangeRate] 模块初始化');
    this.calculateRate();
  }

  // --- 核心计算逻辑 ---
  calculateRate() {
    if (!this.amountFrom || this.amountFrom === 'Error' || this.amountFrom === '0') {
      this.amountTo = '0';
      return;
    }

    try {
      let inputVal = parseFloat(this.amountFrom);
      if (isNaN(inputVal)) {
        this.amountTo = '0';
        return;
      }

      let rateFrom = MOCK_CURRENCIES[this.currencyFrom].rate;
      let rateTo = MOCK_CURRENCIES[this.currencyTo].rate;

      let result = inputVal * (rateTo / rateFrom);

      // 避免出现无意义的长小数，最多保留4位小数，并去掉末尾的0
      this.amountTo = parseFloat(result.toFixed(4)).toString();
    } catch (err) {
      Logger.error(`[ExchangeRate] 计算异常: ${err}`);
      this.amountTo = 'Error';
    }
  }

  // --- 交互处理函数 ---
  handleSwap() {
    Logger.info(`[ExchangeRate] 互换货币: ${this.currencyFrom} <-> ${this.currencyTo}`);
    let temp = this.currencyFrom;
    this.currencyFrom = this.currencyTo;
    this.currencyTo = temp;

    // 互换时，将下方的结果变成上方的输入，体验更好
    this.amountFrom = this.amountTo;
    this.calculateRate();
  }

  openSelector(target: 'from' | 'to') {
    Logger.info(`[ExchangeRate] 打开货币选择器: ${target}`);
    this.selectingTarget = target;
    this.searchQuery = '';
    this.isSelectorShow = true;
  }

  selectCurrency(code: string) {
    Logger.info(`[ExchangeRate] 选择货币 ${code} 作为 ${this.selectingTarget}`);
    if (this.selectingTarget === 'from') {
      if (code === this.currencyTo) {
        this.handleSwap();
      } else {
        this.currencyFrom = code;
      }
    } else {
      if (code === this.currencyFrom) {
        this.handleSwap();
      } else {
        this.currencyTo = code;
      }
    }
    this.isSelectorShow = false;
    this.calculateRate();
  }

  handleRefresh() {
    Logger.info('[ExchangeRate] 用户点击手动刷新');
    // TODO: 接入真实 API 请求
  }

  // --- 键盘输入处理 ---
  handleKeyboardInput(btn: string | Resource) {
    let action = getLocalActionId(btn);

    if (action === 'AC') {
      this.amountFrom = '0';
    } else if (action === '⌫') {
      if (this.amountFrom.length > 1) {
        this.amountFrom = this.amountFrom.slice(0, -1);
      } else {
        this.amountFrom = '0';
      }
    } else if (action === '确定' || action === '−') {
      // 汇率转换中不需要减号，确定键也没有特定提交动作，仅作震动反馈
    } else {
      // 处理数字和小数点输入
      if (this.amountFrom === '0' && action !== '.') {
        this.amountFrom = action;
      } else {
        // 防止输入多个小数点
        if (action === '.' && this.amountFrom.includes('.')) return;
        // 限制长度，防止溢出
        if (this.amountFrom.length < 15) {
          this.amountFrom += action;
        }
      }
    }
    this.calculateRate();
  }

  // ==================== 3. 页面渲染 ====================
  build() {
    Column() {
      Scroll() {
        Column() {
          Row().width('100%').height(this.topRectHeight)
          // --- 顶部汇率展示区 ---
          Column() {
            // [源货币区]
            Row() {
              Row() {
                Text(this.currencyFrom)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Image($r('sys.media.ohos_ic_public_arrow_down'))
                  .width(20).height(20)
                  .fillColor($r('sys.color.font_secondary'))
                  .margin({ left: 8 })
              }
              .padding(8)
              .borderRadius(8)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => this.openSelector('from'))

              Blank()

              Text(`${MOCK_CURRENCIES[this.currencyFrom].symbol} ${this.amountFrom}`)
                .fontSize(32)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({
              left: 24,
              right: 24,
              top: 32,
              bottom: 16
            })

            // [互换按钮与分割线]
            Stack() {
              Divider().color($r('sys.color.comp_divider')).strokeWidth(1)
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                Image($r('sys.symbol.slider_horizontal_2_1')) // 这里暂时用系统的排序图标替代互换图标
                  .width(24).height(24)
                  .fillColor($r('sys.color.font_emphasize'))
              }
              .width(48)
              .height(48)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
              .onClick(() => this.handleSwap())
            }.width('100%')

            // [目标货币区]
            Row() {
              Row() {
                Text(this.currencyTo)
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Image($r('sys.media.ohos_ic_public_arrow_down'))
                  .width(20).height(20)
                  .fillColor($r('sys.color.font_secondary'))
                  .margin({ left: 8 })
              }
              .padding(8)
              .borderRadius(8)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => this.openSelector('to'))

              Blank()

              Text(`${MOCK_CURRENCIES[this.currencyTo].symbol} ${this.amountTo}`)
                .fontSize(32)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({
              left: 24,
              right: 24,
              top: 16,
              bottom: 24
            })
          }
          .width('100%')
          .backgroundColor($r('sys.color.comp_background_primary'))

          // --- 信息提示条 ---
          Row() {
            Column() {
              Text(`1 ${this.currencyFrom} = ${(MOCK_CURRENCIES[this.currencyTo].rate /
                MOCK_CURRENCIES[this.currencyFrom].rate).toFixed(4)} ${this.currencyTo}`)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
              Text(`上次更新: ${this.lastUpdateTime}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start) // 已修复属性方法调用

            Blank()

            Button('更新')
              .fontSize(14)
              .fontColor($r('sys.color.font_emphasize'))
              .backgroundColor(Color.Transparent)
              .onClick(() => this.handleRefresh())
          }
          .width('100%')
          .padding({
            left: 24,
            right: 24,
            top: 12,
            bottom: 12
          })

          Blank()

          // ==================== 键盘区 (完全搬运自 DomainKeyboard) ====================
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
    }
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

              if ((this.selectingTarget === 'from' && this.currencyFrom === currency.code) ||
                (this.selectingTarget === 'to' && this.currencyTo === currency.code)) {
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