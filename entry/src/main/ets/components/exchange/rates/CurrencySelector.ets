/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file CurrencySelector.ets
 * @description 货币选择器半模态窗口，负责全量货币的检索、分组与选择展示
 * @author 易睿 (Yi Rui)
 * @date 2026/8/19 23:35
 */

import Logger from '../../../utils/Logger';
import { CURRENCY_WHITELIST, CURRENCY_MAP, CurrencyInfo } from './CurrencyData';
import { GroupHeader, MenuGroup, ItemDivider } from '../../common/MenuComponents';

// 定义分组数据接口
class CurrencyGroup {
  letter: string;
  data: CurrencyInfo[];

  constructor(letter: string, data: CurrencyInfo[]) {
    this.letter = letter;
    this.data = data;
  }
}

// 定义高频货币白名单
const POPULAR_CURRENCIES: string[] = ['USD', 'EUR', 'CNY', 'GBP', 'JPY', 'HKD', 'AUD', 'CAD', 'CHF', 'SGD', 'KRW'];

// ==================== 独立组件 ====================
@Component
export struct CurrencySelector {
  // ---------------------------------------------------------
  // 1. 父子通信接口 (Props & Callbacks)
  // ---------------------------------------------------------

  /**
   * 当前正在编辑的货币代码（由父组件传入，用于在列表中高亮打钩）
   */
  @Prop currentCurrencyCode: string = '';

  /**
   * 用户选中货币后的回调函数，将选中结果回传给父组件
   */
  onSelect: (code: string) => void = () => {};

  // ---------------------------------------------------------
  // 2. 内部独立状态 (State)
  // ---------------------------------------------------------

  @State searchQuery: string = '';                  // 货币搜索框的输入关键字
  @State selectedIndex: number = 0;                 // 侧边字母索引条的当前选中状态
  @State keyboardAvoidHeight: number = 40;          // 底部软键盘避让高度
  private scroller: Scroller = new Scroller();      // 内部列表的专属滚动控制器

  // ---------------------------------------------------------
  // 3. 核心业务逻辑 (Business Logic)
  // ---------------------------------------------------------

  /**
   * 判断某个货币代码是否为传入的当前选中项
   * @param code - 需要比对的货币代码
   * @returns {boolean} 匹配则返回 true
   */
  isCurrencySelected(code: string): boolean {
    return this.currentCurrencyCode === code;
  }

  /**
   * 数据分组与搜索过滤逻辑
   * @returns {CurrencyGroup[]} 渲染可用的分组数据
   */
  getGroupedCurrencies(): CurrencyGroup[] {
    // 场景一：搜索状态
    if (this.searchQuery) {
      const query = this.searchQuery.toLowerCase();
      let filtered: CurrencyInfo[] = [];

      try {
        // 检测是否为纯英文、数字或空格
        const isPureEnglish = /^[a-zA-Z0-9\s]+$/.test(this.searchQuery);
        Logger.debug(`[CurrencySelector] [纯英文检测] searchQuery: ${this.searchQuery}, isPureEnglish: ${isPureEnglish}`);

        // 安全拆分与正则转义
        const rawChars = Array.from(this.searchQuery);
        const safeChars = rawChars.map(char => char.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));

        // 动态构建正则表达式
        // 如果是纯英文，使用连续匹配；否则使用模糊匹配
        const regexPattern = isPureEnglish ? safeChars.join('') : safeChars.join('.*');
        const searchRegex = new RegExp(regexPattern, 'i');

        // 执行全维度匹配
        filtered = CURRENCY_WHITELIST.filter(currency =>
        searchRegex.test(currency.name) ||
          searchRegex.test(currency.code) ||
          (currency.symbol && searchRegex.test(currency.symbol)) ||
          // 使用 .some() 对关键词进行遍历，只要有一个词命中就展示该货币
          currency.keywords.some(keyword => searchRegex.test(keyword))
        );
      } catch (err) {
        // 捕获正则匹配异常
        Logger.error(`[CurrencySelector] 正则解析异常，已降级为基础搜索: ${err}`);
        filtered = CURRENCY_WHITELIST.filter(currency =>
        currency.code.toLowerCase().includes(query) ||
          currency.name.includes(query) ||
          (currency.symbol && currency.symbol.includes(query)) ||
          // 兜底方案中同样需要加入关键词的比对（记得统一转小写）
          currency.keywords.some(keyword => keyword.toLowerCase().includes(query))
        );
      }

      // 空状态识别：一条匹配的数据都没有，返回空数组，触发 UI 提示
      if (filtered.length === 0) {
        return [];
      }

      return [new CurrencyGroup('搜索结果', filtered)];
    }

    // 场景二：默认状态 (常用分组 + A-Z 分组)
    const groups: CurrencyGroup[] = [];

    // 1. “常用”分组
    const popularData: CurrencyInfo[] = [];
    POPULAR_CURRENCIES.forEach(code => {
      const currency = CURRENCY_WHITELIST.find(c => c.code === code);
      if (currency) {
        popularData.push(currency);
      }
    });

    if (popularData.length > 0) {
      groups.push(new CurrencyGroup('常用', popularData));
    }

    // 2. 标准的 A-Z 分组
    const azMap = new Map<string, CurrencyInfo[]>();
    CURRENCY_WHITELIST.forEach(currency => {
      const firstLetter = currency.code.charAt(0).toUpperCase();
      if (!azMap.has(firstLetter)) {
        azMap.set(firstLetter, []);
      }
      azMap.get(firstLetter)?.push(currency);
    });

    // 排序 A-Z 分组并追加到总组中
    const sortedKeys = Array.from(azMap.keys()).sort();
    sortedKeys.forEach(key => {
      groups.push(new CurrencyGroup(key, azMap.get(key) || []));
    });

    return groups;
  }

  // ---------------------------------------------------------
  // 4. UI 渲染 (Main Build)
  // ---------------------------------------------------------

  build() {
    Stack({ alignContent: Alignment.Top }) {

      // ================= 层级 1 (底层)：全屏滚动的列表 =================
      List({ scroller: this.scroller }) {

        // 调用刚刚写好的分组函数获取数据
        if (this.getGroupedCurrencies().length === 0) {
          // 空状态提示
          ListItem() {
            Column() {
              Text('未搜索到任何内容')
                .fontSize(16)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 32 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        } else {
          // 真实数据遍历 (分组渲染)
          ForEach(this.getGroupedCurrencies(), (group: CurrencyGroup) => {
            ListItem() {
              Column() {
                // 1. 渲染分组的 Header (如 "A", "B", 或 "搜索结果")
                GroupHeader({ title: group.letter })

                // 2. 渲染统一的卡片底板
                MenuGroup() {
                  ForEach(group.data, (currency: CurrencyInfo, index: number) => {

                    // 3. 横向排版
                    Row() {
                      // 货币符号圆形头像图标
                      Text(currency.symbol)
                        .width(32)
                        .height(32)
                        .backgroundColor(this.isCurrencySelected(currency.code)
                          ? $r('sys.color.background_emphasize')
                          : $r('sys.color.comp_background_tertiary'))
                        .borderRadius(16) // 高度一半，完美圆形
                        .textAlign(TextAlign.Center)
                        .fontColor(this.isCurrencySelected(currency.code)
                          ? Color.White
                          : $r('sys.color.font_primary'))
                        .fontWeight(FontWeight.Medium)
                        // 自适应缩放
                        .maxLines(1)
                        .maxFontSize(16)       // 默认字号 ($, ¥, €)
                        .minFontSize(4)        // 最小字号
                        .padding({ left: 6, right: 6 }) // 安全内边距，防止贴死边缘
                        .margin({ right: 20 })  // 与右侧的代码距离

                      // 货币代码
                      Text(currency.code)
                        .fontSize(18)
                        .fontWeight(this.isCurrencySelected(currency.code)
                          ? FontWeight.Bold
                          : FontWeight.Medium)
                        .fontColor(this.isCurrencySelected(currency.code)
                          ? $r('sys.color.font_emphasize')
                          : $r('sys.color.font_primary'))
                        .width(60)
                        .margin({ right: 8 })

                      // 货币名称
                      Text(currency.name)
                        .fontSize(16)
                        .fontWeight(this.isCurrencySelected(currency.code)
                          ? FontWeight.Medium
                          : FontWeight.Regular)
                        .fontColor(this.isCurrencySelected(currency.code)
                          ? $r('sys.color.font_emphasize_contrary')
                          : $r('sys.color.font_secondary'))
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ right: 4 })

                      // 选中打钩状态
                      if (this.isCurrencySelected(currency.code)) {
                        SymbolGlyph($r('sys.symbol.checkmark'))
                          .fontColor([$r('sys.color.font_emphasize')])
                          .fontSize(20)
                      }
                    }
                    .width('100%')
                    .constraintSize({ minHeight: 46 }) // 最小点击高度
                    .padding({ left: 10, right: 16, top: 10, bottom: 10 })
                    .borderRadius(16) // 内部条目圆角，配合按压反馈
                    // 添加点击变色的交互反馈
                    .stateStyles({
                      pressed: {
                        .backgroundColor($r('sys.color.comp_background_secondary'))
                      },
                      normal: {
                        .backgroundColor(Color.Transparent)
                      }
                    })
                    .onClick(() => {
                      // 触发向外发射事件
                      this.onSelect(currency.code);
                    })

                    // 4. 分隔线控制
                    if (index < group.data.length - 1) {
                      ItemDivider({ marginLeft: 60 })
                    }

                  }, (currency: CurrencyInfo) => `${group.letter}_${currency.code}`)
                }
              }
              .width('100%')
              .padding({ bottom: 8 }) // 不同的字母分组之间留出呼吸空间
            }
          }, (group: CurrencyGroup) => group.letter === '搜索结果' ? `搜索结果_${this.searchQuery}` : group.letter)

          // 动态底部统计
          ListItem() {
            Text(
              this.searchQuery
                ? `搜索到 ${this.getGroupedCurrencies()[0].data.length} 种货币`
                : `共 ${CURRENCY_WHITELIST.length} 种货币`
            )
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 12 })
          }
        }

        // 底部安全区占位项
        ListItem() {
          Row().width('100%').height(this.keyboardAvoidHeight)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 36, top: 120})
      .clip(false)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // 监听列表滚动事件，实现反向联动 (滑动列表 -> 点亮字母)
      .onScrollIndex((firstIndex: number) => {
        // 如果处于搜索状态，右侧索引条是隐藏的，不需要进行任何计算
        if (this.searchQuery) return;

        // List 分组对应右侧字母
        let activeGroupIndex = firstIndex;

        // 越界安全兜底：防止用户在最顶部使劲往下拉，导致 firstIndex 小于0
        if (activeGroupIndex < 0) {
          activeGroupIndex = 0;
        }

        // 只有当索引真正发生变化时才更新状态，避免无意义的 UI 重绘
        if (this.selectedIndex !== activeGroupIndex) {
          this.selectedIndex = activeGroupIndex;
        }
      })

      // ================= 层级 2 (中层)：真正的渐变毛玻璃特效引擎 =================
      Stack() {
        // 2.1 毛玻璃实体层
        Column()
          .width('100%')
          .height(84)
          .backgroundBlurStyle(BlurStyle.Thin)

        // 2.2 渐变透明度遮罩层 (Alpha Mask)
        Column()
          .width('100%')
          .height(84)
          .linearGradient({
            angle: 180,
            colors: [
              // 顶部到搜索框下半部分：100% 纯白（完整保留底层毛玻璃效果）
              ['#FFFFFFFF', 0.0],
              ['#FFFFFFFF', 0.4],
              // 指定透明色，底部边缘：过渡到 100% 透明白（让毛玻璃平滑羽化溶解）
              ['#32ffffff', 1.0]
            ]
          })
          // 将自己的透明度通道作为蒙版，扣除下方的毛玻璃
          .blendMode(BlendMode.DST_IN)
      }
      .width('100%')
      .height(84)
      // 开启离屏渲染，隔离混合作用域，确保蒙版只作用于内部的毛玻璃，不破坏底部的 List
      .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      // 中层特效无需接收点击事件，放行给底部的列表滑动
      .hitTestBehavior(HitTestMode.None)

      // ================= 层级 3 (上层)：纯粹悬浮的药丸形搜索框 =================
      Column() {
        // 标题
        Text('选择货币')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ left: 20, top: 4, bottom: 8 })

        // 搜索框
        Search({ placeholder: '搜索货币代码或名称...', value: $$this.searchQuery })
          .width('100%')
          .height(40)
          .borderWidth(0.1)
          .borderColor($r('sys.color.comp_divider'))
          .backgroundColor(Color.Transparent)
          .backgroundBlurStyle(BlurStyle.Thin)
          .onChange((val: string) => {
            this.searchQuery = val.toUpperCase();
          })
          // 监听焦点，动态撑开底部空间
          .onFocus(() => {
            // 键盘弹出时，用动画将底部留白撑高
            animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
              this.keyboardAvoidHeight = 340;
            });
          })
          .onBlur(() => {
            // 键盘收起时，恢复原本的安全区高度
            animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
              this.keyboardAvoidHeight = 40;
            });
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24 })

      // ================= 层级 4 (最上层)：右侧字母索引条 =================
      // 只有在非搜索状态下才显示索引条
      if (!this.searchQuery) {
        AlphabetIndexer({
          // 动态映射数据源，把“常用”替换成星星图标，保持右侧字母表的窄宽度
          arrayValue: this.getGroupedCurrencies().map(group => group.letter === '常用' ? '★' : group.letter),
          selected: this.selectedIndex
        })
          .alignStyle(IndexerAlign.Right)    // 右侧对齐
          .position({ right: 4, top: 150 })  // 避开顶部的搜索框和毛玻璃区域
          .itemSize(18)                      // 字母触控热区大小
          .itemBorderRadius(10086)           // 字母圆角
          .usingPopup(true)                  // 放大气泡反馈
          .popupPosition({ x: 48, y: 0 })    // 气泡向左偏移，防止被手指遮挡
          .selectedBackgroundColor($r('sys.color.background_emphasize')) // 选中项底色
          .selectedColor(Color.White)        // 选中项文字颜色
          .popupColor($r('sys.color.font_emphasize'))          // 气泡文字颜色
          .onSelect((index: number) => {
            // 手按索引条，列表跟随跳转
            this.selectedIndex = index;
            this.scroller.scrollToIndex(index);
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}