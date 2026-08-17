/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 *
 * @file ExchangeRate.ets
 * @description 汇率换算主视图控制器，负责列表交互、网络拉取与持久化调度
 * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:53
 */

import Logger from '../../../utils/Logger';
import { getActionId, PreferenceConfigs } from '../../../utils/CalculatorConfigs';
import { LengthMetrics } from '@kit.ArkUI';
import { PreferenceManager } from '../../../utils/PreferenceManager';
import http from '@ohos.net.http';
import { ApiConfig } from '../../../utils/ApiConfig';
import { CURRENCY_WHITELIST, CURRENCY_MAP, CurrencyInfo } from './CurrencyData';
import { CurrencyListItem, ExchangeApiResponse } from './ExchangeTypes';
import { ExchangeKeyboard } from './ExchangeKeyboard';
import promptAction from '@ohos.promptAction';
import connection from '@ohos.net.connection';

// ==================== 主组件 ====================
@Component
export struct ExchangeRate {
  // ---------------------------------------------------------
  // 1. 状态管理与变量声明 (State & Properties)
  // ---------------------------------------------------------

  // [核心数据状态]
  @State currencyList: Array<CurrencyListItem> = [];
  @State rateMap: Record<string, number> = {};
  @State lastUpdateTimeStamp: number = 0; // 底层记录最后一次成功联网获取数据的真实时间戳

  // [UI 交互与双向绑定状态]
  @State activeId: string = '';
  @State baseAmount: string = '';
  @State lastUpdateTime: string = '加载中...'; // 顶部显示的格式化时间文本
  @State searchQuery: string = ''; // 货币搜索框的输入关键字

  // [视图控制状态]
  @State isSelectorShow: boolean = false; // 控制货币选择半模态窗口的显隐
  @State selectingId: string = ''; // 记录当前正在选择货币的列表项 ID

  // [网络与反馈动效状态]
  @State isRefreshing: boolean = false; // 是否处于更新（或模拟更新）状态
  @State isUpdateFailed: boolean = false; // 控制失败提示 UI 的显隐
  @State isUpdateSuccess: boolean = false; // 控制成功提示 UI 的显隐
  private feedbackTimer: number = -1; // 反馈动画淡出定时器句柄，用于防抖

  // [拖拽排序状态]
  @State draggingId: string = ''; // 当前被拖拽的列表项 ID
  @State isDragGhostReady: boolean = false; // 控制拖拽跟手虚影的出场动画状态
  private draggedIndex: number = -1; // 当前被拖拽项的原始索引

  // [系统环境变量]
  @StorageProp('topRectHeight') topRectHeight: number = 80; // 顶部状态栏避让高度

  // ---------------------------------------------------------
  // 2. 生命周期 (Lifecycle)
  // ---------------------------------------------------------

  /**
   * 组件即将出现时触发
   * 负责调度初始化数据的加载，并触发统一的刷新中枢
   */
  aboutToAppear() {
    Logger.info('[ExchangeRate] 模块初始化');
    this.loadData();
    this.handleRefresh();
  }

  // ---------------------------------------------------------
  // 3. 数据初始化与持久化 (Data & Persistence)
  // ---------------------------------------------------------

  /**
   * 从本地首选项 (Preferences) 中读取货币列表、汇率字典和时间戳
   * 加载完成后同步触发 UI 时间的初始渲染
   */
  loadData() {
    // 1. 加载 UI 状态（列表、选中项、金额等）
    let listStr = AppStorage.get<string>(PreferenceConfigs.KEY_EXCHANGE_CURRENCY_LIST) || '[]';
    try {
      let parsedList = JSON.parse(listStr) as Array<CurrencyListItem>;
      if (parsedList && parsedList.length > 0) {
        this.currencyList = parsedList;
      } else {
        // 无缓存时的默认兜底数据
        this.currencyList = [
          new CurrencyListItem('1', 'USD'),
          new CurrencyListItem('2', 'CNY')
        ];
      }
    } catch (err) {
      this.currencyList = [new CurrencyListItem('1', 'USD'), new CurrencyListItem('2', 'CNY')];
    }

    this.activeId = AppStorage.get<string>(PreferenceConfigs.KEY_EXCHANGE_ACTIVE_ID) || this.currencyList[0].id;
    this.baseAmount = AppStorage.get<string>(PreferenceConfigs.KEY_EXCHANGE_BASE_AMOUNT) || '100';

    // 2. 加载网络动态汇率字典
    let ratesStr = AppStorage.get<string>(PreferenceConfigs.KEY_EXCHANGE_RATES) || '{}';
    try {
      this.rateMap = JSON.parse(ratesStr);
    } catch (err) {
      this.rateMap = {};
    }

    // 3. 加载上次更新时间戳
    this.lastUpdateTimeStamp = AppStorage.get<number>(PreferenceConfigs.KEY_EXCHANGE_LAST_UPDATE) || 0;
    this.updateTimeDisplay();
  }

  /**
   * 监听关键状态变化，统一下发落盘指令
   * 保证内存状态与本地存储的一致性
   */
  saveData() {
    PreferenceManager.set(PreferenceConfigs.KEY_EXCHANGE_CURRENCY_LIST, JSON.stringify(this.currencyList));
    PreferenceManager.set(PreferenceConfigs.KEY_EXCHANGE_ACTIVE_ID, this.activeId);
    PreferenceManager.set(PreferenceConfigs.KEY_EXCHANGE_BASE_AMOUNT, this.baseAmount);
  }


  // ---------------------------------------------------------
  // 4. 网络请求与状态调度 (Network & State Dispatching)
  // ---------------------------------------------------------

  /**
   * 统一的刷新调度中枢 (Single Source of Truth)
   * 负责网络连通性探测、缓存校验拦截、发起 HTTP 请求，以及分发状态反馈
   */
  async handleRefresh() {
    // 防抖拦截
    if (this.isRefreshing) return;

    // 1. 毫秒级原生探网
    let hasNet = false;
    let isNetCheckSuccess = true;

    try {
      hasNet = connection.hasDefaultNetSync();
    } catch (e) {
      isNetCheckSuccess = false;
      Logger.warn(`[ExchangeRate] 底层探网 API 异常，降级为 HTTP 真实探测: ${JSON.stringify(e)}`);
    }

    // 2. 缓存有效时的【前端拦截与障眼法逻辑】(去掉了 isForceNetwork 参数校验)
    if (this.isCacheValid()) {
      if (isNetCheckSuccess) {
        if (!hasNet) {
          Logger.info('[ExchangeRate] 明确无网，拦截假装更新，防止穿帮');
          this.commitUpdateState(false, '网络连接异常，请检查网络设置');
          return;
        }

        Logger.info('[ExchangeRate] 明确有网且缓存有效，执行视觉障眼法...');
        this.isRefreshing = true;
        setTimeout(() => {
          this.commitUpdateState(true);
          this.isRefreshing = false;
        }, 400);
        return;
      }
    }

    // 3. 真实请求前的最后防线
    if (isNetCheckSuccess && !hasNet) {
      Logger.info('[ExchangeRate] 明确无网，拦截真实请求');
      this.commitUpdateState(false, '网络连接异常，请检查网络设置');
      return;
    }

    // ================= 以下为真实的 HTTP 请求逻辑 =================
    this.isRefreshing = true;
    Logger.info('[ExchangeRate] 触发真实汇率刷新任务，开始请求 API...');
    let httpRequest = http.createHttp();

    try {
      let response = await httpRequest.request(
        'https://api.startyi.com/rates',
        {
          method: http.RequestMethod.GET,
          header: { 'x-token': ApiConfig.EXCHANGE_API_TOKEN },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );

      if (response.responseCode === http.ResponseCode.OK) {
        let resObj = (typeof response.result === 'string'
          ? JSON.parse(response.result)
          : response.result) as Record<string, Object>;

        let rawRates = resObj['rates'] as Record<string, number>;

        if (rawRates) {
          let newRateMap: Record<string, number> = {};
          let rateKeys = Object.keys(rawRates);

          for (let i = 0; i < rateKeys.length; i++) {
            newRateMap[rateKeys[i]] = Number(rawRates[rateKeys[i]]);
          }

          this.rateMap = newRateMap;
          Logger.info(`[ExchangeRate] 真实更新成功！已缓存 ${rateKeys.length} 种货币汇率。`);

          // 真实请求成功后，只落盘核心的汇率数值字典
          PreferenceManager.set(PreferenceConfigs.KEY_EXCHANGE_RATES, JSON.stringify(this.rateMap));

          // 提交成功状态（内部会自动把时间戳落盘，并刷新 UI）
          this.commitUpdateState(true);
        } else {
          Logger.error(`[ExchangeRate] 数据结构异常，未能提取到 rates 字段`);
          this.commitUpdateState(false, '数据解析异常，已使用本地缓存');
        }
      } else {
        Logger.error(`[ExchangeRate] 网络请求失败，状态码: ${response.responseCode}`);
        this.commitUpdateState(false, `更新失败 (错误码: ${response.responseCode})`);
      }
    } catch (err) {
      Logger.error(`[ExchangeRate] 网络请求底层异常: ${JSON.stringify(err)}`);
      this.commitUpdateState(false, '网络连接异常，请检查网络设置');
    } finally {
      httpRequest.destroy();
      this.isRefreshing = false;
    }
  }

  /**
   * 判断当前汇率缓存是否在整点有效期内
   * @returns {boolean} 缓存有效返回 true，跨越整点或无缓存返回 false
   */
  isCacheValid(): boolean {
    if (this.lastUpdateTimeStamp === 0) return false;
    let now = new Date();
    let cachedDate = new Date(this.lastUpdateTimeStamp);

    let nowHourStr = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}-${now.getHours()}`;
    let cachedHourStr = `${cachedDate.getFullYear()}-${cachedDate.getMonth()}-${cachedDate.getDate()}-${cachedDate.getHours()}`;

    return nowHourStr === cachedHourStr;
  }

  /**
   * 统一的状态提交与动画触发器
   * 负责拦截冗余定时器、下发时间戳落盘、调用时间格式化，并执行 UI 视觉反馈
   * @param isSuccess - 更新是否成功（无论是真实联网成功还是模拟拦截成功）
   * @param toastMsg - 失败时展示的错误提示信息
   */
  commitUpdateState(isSuccess: boolean, toastMsg?: string) {
    // 掐断未完成的定时器，防止狂点导致状态错乱
    if (this.feedbackTimer !== -1) {
      clearTimeout(this.feedbackTimer);
    }

    if (isSuccess) {
      // 统一下发最新时间戳并落盘（无论真假更新都走这里，确保杀后台重启时不穿帮）
      this.lastUpdateTimeStamp = new Date().getTime();
      PreferenceManager.set(PreferenceConfigs.KEY_EXCHANGE_LAST_UPDATE, this.lastUpdateTimeStamp);

      // 统一调用格式化方法，更新顶部 UI 显示的“今天 HH:mm”字符串
      this.updateTimeDisplay();

      this.isUpdateSuccess = true;
      this.isUpdateFailed = false;
    } else {
      // 失败：显示错误状态并弹窗
      this.isUpdateFailed = true;
      this.isUpdateSuccess = false;
      if (toastMsg) {
        promptAction.showToast({
          message: toastMsg,
          duration: 2500,
          bottom: '270vp'
        });
      }
    }

    // 3秒后平滑重置状态，让界面的绿字/红字温柔淡出
    this.feedbackTimer = setTimeout(() => {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.isUpdateFailed = false;
        this.isUpdateSuccess = false;
      });
    }, 3000);
  }

  /**
   * 格式化最后更新时间戳，并更新顶部 UI 显示的文本
   * 内部包含当天、跨天及补零等日期处理逻辑
   */
  updateTimeDisplay() {
    if (this.lastUpdateTimeStamp === 0) {
      this.lastUpdateTime = '从未更新';
      return;
    }

    let date = new Date(this.lastUpdateTimeStamp);
    let hours = date.getHours().toString().padStart(2, '0');
    let minutes = date.getMinutes().toString().padStart(2, '0');

    let today = new Date();
    if (date.getDate() === today.getDate() && date.getMonth() === today.getMonth() && date.getFullYear() === today.getFullYear()) {
      this.lastUpdateTime = `今天 ${hours}:${minutes}`;
    } else {
      let month = (date.getMonth() + 1).toString().padStart(2, '0');
      let day = date.getDate().toString().padStart(2, '0');
      this.lastUpdateTime = `${month}-${day} ${hours}:${minutes}`;
    }
  }

  // ---------------------------------------------------------
  // 5. 核心业务逻辑计算 (Business Logic)
  // ---------------------------------------------------------

  /**
   * 实时计算目标货币的折算金额
   * @param targetCode - 目标货币代码 (如 "CNY")
   * @param isEditing - 该项是否为当前正在被编辑的基准项
   * @returns {string} 格式化后的金额字符串
   */
  getConvertedAmount(targetCode: string, isEditing: boolean): string {
    // 1. 状态拦截：如果正在被编辑，直接显示用户输入的原始内容
    if (isEditing) return this.baseAmount;

    // 2. 空值与异常拦截：输入为空、为 0 或错误状态，直接返回 '0'
    if (!this.baseAmount || this.baseAmount === 'Error' || this.baseAmount === '0') return '0';

    try {
      let inputVal = parseFloat(this.baseAmount);
      if (isNaN(inputVal)) return '0';

      let activeItem = this.currencyList.find(item => item.id === this.activeId);
      if (!activeItem) return '0';

      // 3. 获取汇率值，并进行极其严格的安全兜底
      // 如果字典中没有查到，或者查到的是 0（防止除零异常），则默认赋为 1
      let rateFrom = this.rateMap[activeItem.code];
      let rateTo = this.rateMap[targetCode];

      // 针对 API 可能不返回基准货币本身的特殊处理
      if (activeItem.code === 'USD') rateFrom = 1;
      if (targetCode === 'USD') rateTo = 1;

      // 彻底的防崩溃兜底
      if (!rateFrom || rateFrom === 0) rateFrom = 1;
      if (!rateTo) rateTo = 1;

      // 4. 交叉换算核心公式：
      // (输入金额 / 源货币兑USD汇率) * 目标货币兑USD汇率
      let amountInUSD = inputVal / rateFrom;
      let result = amountInUSD * rateTo;

      // 5. 精度控制：最多保留 4 位小数，并通过 parseFloat 去除末尾无意义的 0 (如 1.5000 -> 1.5)
      return parseFloat(result.toFixed(4)).toString();
    } catch (err) {
      Logger.error(`[ExchangeRate] 计算引擎异常: ${err}`);
      return 'Error';
    }
  }

  /**
   * 判断某个货币代码是否为当前正在选择/修改的列表项的原有货币
   * 用于在半模态选择窗口中渲染高亮或打钩状态
   * @param code - 需要比对的货币代码
   * @returns {boolean} 如果匹配则返回 true
   */
  isCurrencySelected(code: string): boolean {
    let selectingItem = this.currencyList.find(c => c.id === this.selectingId);
    return selectingItem ? selectingItem.code === code : false;
  }

  // ---------------------------------------------------------
  // 6. 用户交互与事件处理 (Event Handlers)
  // ---------------------------------------------------------

  /**
   * 设置指定的货币项为当前激活（输入）状态
   * 切换时会自动将该项当前的折算结果反写为新的基准金额，确保视觉上的平滑过渡
   * @param id - 被点击激活的列表项 ID
   * @param code - 被点击激活的列表项的货币代码
   */
  setActiveCurrency(id: string, code: string) {
    if (this.activeId !== id) {
      this.baseAmount = this.getConvertedAmount(code, false);
      this.activeId = id;
      this.saveData();
    }
  }

  /**
   * 处理自定义数字键盘的输入事件
   * @param btn - 按下的按键值或资源标识
   */
  handleKeyboardInput(btn: string | Resource) {
    let action = getActionId(btn);

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
    this.saveData();
  }

  /**
   * 打开货币选择半模态窗口，并记录当前操作的项 ID
   * @param id - 触发选择的列表项 ID
   */
  openSelector(id: string) {
    this.selectingId = id;
    this.searchQuery = '';
    this.isSelectorShow = true;
  }

  /**
   * 确认选择货币，并更新对应项的货币代码
   * @param code - 选中的货币代码
   */
  selectCurrency(code: string) {
    let index = this.currencyList.findIndex(item => item.id === this.selectingId);
    if (index !== -1) {
      this.currencyList.splice(index, 1, new CurrencyListItem(this.selectingId, code));
      this.saveData();
    }
    this.isSelectorShow = false;
  }

  /**
   * 在列表尾部新增一条货币转换项
   */
  addCurrency() {
    let newId = new Date().getTime().toString();
    // 启动物理阻尼动画，确保新元素自然滑入列表尾部
    animateTo({ duration: 350, curve: Curve.Friction }, () => {
      this.currencyList.push(new CurrencyListItem(newId, 'USD'));
    });
    this.saveData();
  }

  /**
   * 删除指定的货币转换项
   * @param id - 要删除的列表项 ID
   */
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
    this.saveData();
  }

  // ---------------------------------------------------------
  // 7. UI 构建器 (UI Builders)
  // ---------------------------------------------------------

  /**
   * 侧滑删除操作区：复用组件统一样式
   * @param id - 绑定的列表项 ID
   */
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

  /**
   * 拖拽占位符：带有轻微放大和高级阴影的跟手虚影
   * @param item - 正在拖拽的货币项数据
   */
  @Builder
  dragFeedback(item: CurrencyListItem) {
    Stack() {
      Column() {
        this.CurrencyCardView(item)
      }
      .backgroundColor($r('sys.color.background_primary'))
      .borderRadius(16)
      .scale({ x: 1.05, y: 1 }) // 轻微放大，产生“拿起来”的视觉差
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
  }

  /**
   * 独立的货币转换卡片 UI 封装
   * @param item - 当前渲染的货币项数据
   */
  @Builder
  CurrencyCardView(item: CurrencyListItem) {
    Row() {
      // 左侧功能区：货币类型选择器
      Button() {
        Row() {
          Text(item.code)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(16)
            .height(16)
            .fillColor(this.activeId === item.id ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
            .margin({ left: 4 })
        }
      }
      .type(ButtonType.Normal) // 指定为 Normal，保留自定义的矩形和圆角
      .padding({ top: 8, bottom: 8, left: 12, right: 12 })
      .borderRadius(12)
      .backgroundColor(this.activeId === item.id ? $r('sys.color.comp_background_primary') : $r('sys.color.background_secondary'))
      .onClick(() => this.openSelector(item.id))
      .margin({ right: 14 })
      .alignSelf(ItemAlign.Center)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 }) // 轻微且顺滑的向内缩放效果

      // 右侧内容区：两行式布局
      Column() {
        Column() {
          // 查表获取中文名，找不到就直接显示代码
          Text(CURRENCY_MAP[item.code]?.name || item.code)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .padding({ top: 12, bottom: 2 })
        .onClick(() => this.setActiveCurrency(item.id, item.code))

        Column() {
          // 查表获取符号，找不到就留空
          Text(`${CURRENCY_MAP[item.code]?.symbol || ''} ${this.getConvertedAmount(item.code, this.activeId === item.id)}`)
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
    .stateStyles({
      normal: {
        .backgroundColor(this.activeId === item.id ? $r('sys.color.comp_background_tertiary') : $r('sys.color.comp_background_primary'))
      },
      pressed: {
        .backgroundColor($r('sys.color.interactive_pressed'))
      }
    })
    .borderRadius(16)
    .borderWidth(this.activeId === item.id ? 1.0 : 0.5)
    .borderColor($r('sys.color.comp_divider'))
  }

  /**
   * 带有搜索框的货币选择半模态窗口内容
   */
  @Builder
  CurrencySelectorBuilder() {
    Stack({ alignContent: Alignment.Top }) {

      // ================= 层级 1 (底层)：全屏滚动的列表 =================
      List() {
        // 顶部幽灵占位项：高度 = 搜索框 top margin(16) + 搜索框高度(40) + 搜索框底部预留间距(16) = 72
        ListItem() {
          Row().width('100%').height(72)
        }

        // 真实数据遍历
        ForEach(CURRENCY_WHITELIST.filter(item =>
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
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontColor([$r('sys.color.font_emphasize')])
                  .fontSize(20)
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 8, right: 8 })
          }
          .onClick(() => this.selectCurrency(currency.code))
        }, (item: CurrencyInfo) => item.code)

        // 底部安全区占位项
        ListItem() {
          Row().width('100%').height(40)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // ================= 层级 2 (上层)：纯粹悬浮的药丸形搜索框 =================
      Column() {
        Search({ placeholder: '搜索货币代码或名称...', value: $$this.searchQuery })
          .width('100%')
          .height(40)
          .backgroundColor(Color.Transparent)
          // 毛玻璃材质只贴在搜索框上
          .backgroundBlurStyle(BlurStyle.Thin)
          .onChange((val: string) => {
            this.searchQuery = val.toUpperCase();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16 })
    }
    .width('100%')
    .height('100%')
  }

  // ---------------------------------------------------------
  // 8. 主界面渲染 (Main Build)
  // ---------------------------------------------------------

  /**
   * 主界面渲染 (Main Build)
   */
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

            // 状态反馈区：失败显示红字，成功显示绿字
            if (this.isUpdateFailed) {
              Text('✘ 更新失败')
                .fontSize(12)
                .fontColor(Color.Red)
                .margin({ right: 8 })
                .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
            } else if (this.isUpdateSuccess) {
              Text('🗸 更新成功')
                .fontSize(12)
                .fontColor(Color.Green)
                .margin({ right: 8 })
                .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
            }

            // 根据状态动态切换文字和颜色
            Button(this.isRefreshing ? '更新中...' : (this.isUpdateFailed ? '重试 ↻' : '更新 ↻'))
              .fontSize(14)
              // 更新中显示次级灰色，失败显示红色，正常状态显示主题强调色
              .fontColor(this.isRefreshing ? $r('sys.color.font_tertiary') : (this.isUpdateFailed ? Color.Red : $r('sys.color.font_emphasize')))
              .backgroundColor(Color.Transparent)
              .onClick(() => this.handleRefresh())
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: this.topRectHeight + 12, bottom: 4 })
        }

        // 核心循环：采用一维拍平结构提升性能与交互可塑性
        ForEach(this.currencyList, (item: CurrencyListItem, index: number) => {
          ListItem() {
            // 直接调用抽离的 Builder，传入当前项的数据
            this.CurrencyCardView(item)
          }
          .padding({ left: 16, right: 16 })
          .opacity(this.draggingId === item.id ? 0 : 1) // 如果是被拖拽的项，直接变透明作为占位符
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
                  .fontSize(18)
                  .fontColor([$r('sys.color.font_emphasize')])
                  .margin({ right: 8 })
                Text('添加货币')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_emphasize'))
              }
              .justifyContent(FlexAlign.Center)
            }
            .type(ButtonType.Normal)
            .borderRadius(24)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .width('60%')
            .height(48)
            .onClick(() => this.addCurrency())
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16, top: 8, bottom: 32 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ top: 0, bottom: 0 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(12) })
      .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
        let actualIndex = itemIndex - 1;
        if (actualIndex < 0 || actualIndex >= this.currencyList.length) return undefined;

        this.draggedIndex = actualIndex;
        let draggedItem = this.currencyList[actualIndex];

        // 触发重绘：让列表中的原项变透明
        this.draggingId = draggedItem.id;

        // 返回我们刚刚写好的高级复印件
        return this.dragFeedback(draggedItem);
      })
      .onItemDragMove((event: ItemDragInfo, itemIndex: number, insertIndex: number) => {
        let actualInsertIndex = insertIndex - 1;
        if (actualInsertIndex < 0) actualInsertIndex = 0;
        if (actualInsertIndex >= this.currencyList.length) actualInsertIndex = this.currencyList.length - 1;

        if (this.draggedIndex === actualInsertIndex) return;

        // 透明占位符在列表中实时挤位
        animateTo({ duration: 350, curve: Curve.Friction }, () => {
          let item = this.currencyList.splice(this.draggedIndex, 1)[0];
          this.currencyList.splice(actualInsertIndex, 0, item);
          this.draggedIndex = actualInsertIndex;
        });
      })
      .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
        // 拖拽结束，重置所有状态，透明项瞬间恢复实体
        this.draggedIndex = -1;
        this.draggingId = '';
        // 拖拽结束，列表顺序已定，此时调用保存
        this.saveData();
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
      height: SheetSize.LARGE,
      dragBar: true,
      title: { title: '选择货币' }
    })
  }
}