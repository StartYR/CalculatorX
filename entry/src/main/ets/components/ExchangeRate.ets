/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file ExchangeRate.ets
 * @description 请在此处输入文件描述...
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:53
 */

import Logger from '../utils/Logger';

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

// ==================== 2. 主件 ====================
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

  aboutToAppear() {
    Logger.info('[ExchangeRate] 模块初始化');
    this.calculateRate();
  }

  // --- 核心计算逻辑 ---
  calculateRate() {
    if (!this.amountFrom || this.amountFrom === 'Error') {
      this.amountTo = '';
      return;
    }

    try {
      let inputVal = parseFloat(this.amountFrom);
      if (isNaN(inputVal)) {
        this.amountTo = '';
        return;
      }

      let rateFrom = MOCK_CURRENCIES[this.currencyFrom].rate;
      let rateTo = MOCK_CURRENCIES[this.currencyTo].rate;

      // 交叉汇率计算公式：目标金额 = 输入金额 * (目标汇率 / 源汇率)
      let result = inputVal * (rateTo / rateFrom);

      // 保留合理的小数位数，避免精度浮点问题
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
    this.calculateRate();
  }

  openSelector(target: 'from' | 'to') {
    Logger.info(`[ExchangeRate] 打开货币选择器: ${target}`);
    this.selectingTarget = target;
    this.searchQuery = ''; // 打开时清空搜索
    this.isSelectorShow = true;
  }

  selectCurrency(code: string) {
    Logger.info(`[ExchangeRate] 选择货币 ${code} 作为 ${this.selectingTarget}`);
    if (this.selectingTarget === 'from') {
      // 如果选的货币和另一边一样，触发互换保护机制
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
    // TODO: 未来接入 Cloudflare Worker 代理，发起 HTTP 请求拉取最新 JSON 并缓存
  }

  // ==================== 3. 页面渲染 ====================
  build() {
    Column() {
      // --- 顶部汇率展示区 ---
      Column() {
        // [源货币区]
        Row() {
          // 点击左侧打开选择器
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

          // 输入金额显示
          Text(`${MOCK_CURRENCIES[this.currencyFrom].symbol} ${this.amountFrom}`)
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 32, bottom: 16 })

        // [互换按钮与分割线]
        Stack() {
          Divider().color($r('sys.color.comp_divider')).strokeWidth(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('sys.symbol.slider_horizontal_2_1')) // 这里暂时用系统的排序图标替代互换图标
              .width(24).height(24)
              .fillColor($r('sys.color.font_emphasize'))
          }
          .width(48).height(48)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
          .onClick(() => this.handleSwap())
        }.width('100%')

        // [目标货币区]
        Row() {
          // 点击左侧打开选择器
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

          // 转换结果显示
          Text(`${MOCK_CURRENCIES[this.currencyTo].symbol} ${this.amountTo}`)
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary')) // 结果使用次要颜色区分
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 24 })
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))

      // --- 信息提示条 (基准汇率与刷新时间) ---
      Row() {
        Column() {
          // 显示 1源货币 = X目标货币 的快捷参考
          Text(`1 ${this.currencyFrom} = ${(MOCK_CURRENCIES[this.currencyTo].rate / MOCK_CURRENCIES[this.currencyFrom].rate).toFixed(4)} ${this.currencyTo}`)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
          Text(`上次更新: ${this.lastUpdateTime}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 手动刷新按钮
        Button('更新')
          .fontSize(14)
          .fontColor($r('sys.color.font_emphasize'))
          .backgroundColor(Color.Transparent)
          .onClick(() => this.handleRefresh())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })

      Blank()

      // ==================== TODO: 自定义键盘区 ====================
      // 等待你贴入键盘 UI 代码。可以通过操作 this.amountFrom 来输入数字
      Text('（这里预留给键盘 UI）')
        .width('100%')
        .height(300)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))

    }
    .width('100%')
    .height('100%')
    // 绑定货币选择器半模态面板
    .bindSheet($$this.isSelectorShow, this.CurrencySelectorBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      title: { title: '选择货币' }
    })
  }

  // --- 货币选择器弹窗 UI (Builder) ---
  @Builder
  CurrencySelectorBuilder() {
    Column() {
      // 搜索框
      Search({ placeholder: '搜索货币代码或名称...', value: $$this.searchQuery })
        .width('100%')
        .margin({ bottom: 16 })
        .onChange((val: string) => {
          this.searchQuery = val.toUpperCase();
        })

      // 货币列表
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

              // 选中状态标识
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
      .layoutWeight(1) // 占满剩余空间，可滚动
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 16 })
  }
}