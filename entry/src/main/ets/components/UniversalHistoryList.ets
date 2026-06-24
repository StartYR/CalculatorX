// entry/src/main/ets/components/UniversalHistoryList.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { mediaquery, LengthMetrics } from '@kit.ArkUI';

// 定义分组数据的接口模型
interface HistoryGroup {
  title: string;
  records: HistoryRecord[];
}

@Component
export struct UniversalHistoryList {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 核心参数：决定去数据库捞哪个模块的数据
  @Prop moduleType: string = 'scientific';
  // 核心参数：决定是否需要为了沉浸式导航栏在首尾留出空白占位
  @Prop isGlobalPage: boolean = false;
  // 核心参数：用于接收外部传来的刷新信号
  @Prop @Watch('loadData') refreshCounter: number = 0;

  @State historyList: HistoryRecord[] = [];
  @State isDarkMode: boolean = false;
  private darkModeListener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('(dark-mode: true)');

  // 暴露点击事件给外部容器处理
  onItemClick?: (record: HistoryRecord) => void;

  aboutToAppear() {
    this.darkModeListener.on('change', (mediaQueryResult: mediaquery.MediaQueryResult) => {
      this.isDarkMode = mediaQueryResult.matches;
    });
    this.isDarkMode = this.darkModeListener.matches;
    this.loadData();
  }

  aboutToDisappear() {
    this.darkModeListener.off('change');
  }

  // 智能识别长得高的公式！
  getDynamicHeight(content: string, isOutput: boolean): number {
    if (!content) return isOutput ? 24 : 24;
    // 如果文本中包含 \frac (分数)、\int (积分) 等复杂结构
    if (content.includes('\\int')) {
      return isOutput ? 48 : 48; // 给予更高的高度
    }
    else if (content.includes('\\frac')) {
      return isOutput ? 36 : 36; // 给予更高的高度
    }
    return isOutput ? 24 : 24; // 普通单行数字，保持紧凑高度
  }

  async loadData() {
    // 引擎不管外壳是谁，只管根据传进来的 moduleType 去查数据库
    let limit = this.isGlobalPage ? 100 : 50;
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, limit);
  }

  // 将扁平的记录按时间智能分组
  getGroupedHistory(): HistoryGroup[] {
    const groups: Map<string, HistoryRecord[]> = new Map();

    // 获取今天和昨天的极值基准
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    const yesterdayStr = `${yesterday.getFullYear()}-${yesterday.getMonth()}-${yesterday.getDate()}`;

    this.historyList.forEach((record) => {
      const recordDate = new Date(record.timestamp || Date.now());
      const recordStr = `${recordDate.getFullYear()}-${recordDate.getMonth()}-${recordDate.getDate()}`;

      let groupTitle = '';
      if (recordStr === todayStr) {
        groupTitle = '今天';
      } else if (recordStr === yesterdayStr) {
        groupTitle = '昨天';
      } else {
        groupTitle = `${recordDate.getMonth() + 1}月${recordDate.getDate()}日`;
      }

      if (!groups.has(groupTitle)) {
        groups.set(groupTitle, []);
      }
      groups.get(groupTitle)?.push(record);
    });

    // 转换为数组返回
    const result: HistoryGroup[] = [];
    groups.forEach((records, title) => {
      result.push({ title, records });
    });
    return result;
  }

  // 吸顶时间标题栏
  @Builder
  itemHead(text: string) {
    Text(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 24, top: 8, bottom: 8 }) // 给分组留出舒适的呼吸感
      .backgroundColor(Color.Transparent)
  }

  // 左滑显示红色删除按钮
  @Builder
  deleteAction(item: HistoryRecord) {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(24)
          .fontColor([Color.White]) // 垃圾桶图标使用纯白，视觉冲击力极强
      }
      .width(48)
      .height(48)
      .backgroundColor('#FF3B30') // 极其纯正的系统级破坏性红色（Destructive Red）
      .shadow({ radius: 8, color: '#33FF3B30', offsetY: 4 }) // 加上一点点红色弥散阴影，质感拉满
      .onClick(async () => {
        // 通知底层数据库真正删除这条记录
        if (item.id !== undefined) {
          await HistoryRepository.deleteRecord(item.id);
        }

        // 触发原生的 UI 移除动画
        animateTo({ duration: 350, curve: Curve.Friction }, () => {
          // 将这条记录从当前数组中剔除，触发重新分组渲染
          this.historyList = this.historyList.filter(record => record.id !== item.id);
        });
      })
    }
    .height('100%') // 撑满当前这一条历史记录的高度
    .padding({ left: 16, right: 24 }) // 给滑动留出舒适的阻尼空间
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.historyList.length === 0) {
        // 空状态展现
        Column() {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
            .fontSize(48)
            .fontColor([$r('sys.color.icon_tertiary')])
            .margin({ bottom: 12 })
          Text ('暂无历史记录')
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        // 核心渲染列表
        List({ space: 8 }) {
          // 如果是全局页面，顶部增加占位以避开沉浸式标题栏
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(96) }
          }

          // 【核心替换】：从循环扁平数组，改为循环分组数据
          ForEach(this.getGroupedHistory(), (group: HistoryGroup) => {
            // 召唤系统分组包裹器，并挂载刚刚写的吸顶头部！
            ListItemGroup({ header: this.itemHead(group.title), space: 8 }) {

              // 在分组内部，依然用之前极其完美的卡片代码循环渲染记录
              ForEach(group.records, (item: HistoryRecord) => {
                ListItem() {
                  Row() {
                    // ==================== 【左侧模块图标】 ====================
                    SymbolGlyph($r('sys.symbol.calculator_fill'))
                      .fontSize(22)
                      .fontColor([$r('sys.color.icon_emphasize')])
                      .margin({ right: 14 })
                      .alignSelf(ItemAlign.Center)

                    // ==================== 【右侧内容区】 ====================
                    Column() {
                      // ==================== 【输入区靠左】 ====================
                      if (item.inputBase64 && item.inputBase64.length > 0) {
                        Row() {
                          Image(item.inputBase64)
                            .height(this.getDynamicHeight(item.inputContent, false))
                            .objectFit(ImageFit.Contain)
                            .colorFilter(this.isDarkMode ? [
                              -1,  0,  0, 0, 255,
                              0, -1,  0, 0, 255,
                              0,  0, -1, 0, 255,
                              0,  0,  0, 1,   0
                            ] : undefined)
                            .opacity(0.7)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.Start)
                      } else {
                        Text(item.inputContent).fontSize(18).fontColor($r('sys.color.font_secondary'))
                          .width('100%').textAlign(TextAlign.Start).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                      }

                      // ==================== 【输出区靠右】 ====================
                      if (item.outputBase64 && item.outputBase64.length > 0) {
                        Row() {
                          Text('=  ').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                          Image(item.outputBase64)
                            .height(this.getDynamicHeight(item.outputContent, true))
                            .objectFit(ImageFit.Contain)
                            .colorFilter(this.isDarkMode ? [
                              -1,  0,  0, 0, 255,
                              0, -1,  0, 0, 255,
                              0,  0, -1, 0, 255,
                              0,  0,  0, 1,   0
                            ] : undefined)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.End)
                        .margin({ top: 8 })
                        .alignItems(VerticalAlign.Center)
                      } else {
                        Text(`=  ${item.outputContent}`).fontSize(18).fontWeight(FontWeight.Medium)
                          .fontColor($r('sys.color.font_primary')).width('100%').textAlign(TextAlign.End).margin({ top: 8 })
                      }
                    }
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .backgroundColor($r('sys.color.comp_background_primary'))
                  .borderRadius(16)
                  .onClick(() => {
                    if (this.onItemClick) this.onItemClick(item);
                  })
                }
                .padding({ left: 16, right: 16 })
                .swipeAction({
                  end: { builder: () => { this.deleteAction(item) } },
                  edgeEffect: SwipeEdgeEffect.Spring
                })
              }, (item: HistoryRecord) => item.id?.toString())

            }
          }, (group: HistoryGroup) => group.title)

          // 底部占位
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(this.navBarHeight + 64) }
          } else {
            ListItem() { Row().width('100%').height(12) }
          }
        }
        // 【最核心的属性】：赋予 List 原生的吸顶魔法！
        .sticky(StickyStyle.Header)

        .layoutWeight(1)
        .width('100%')
        .padding({ top: 0, bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(12) })
      }
    }
    .width('100%')
    .height('100%')
  }
}