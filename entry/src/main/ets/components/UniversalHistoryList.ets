// entry/src/main/ets/components/UniversalHistoryList.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { mediaquery, LengthMetrics } from '@kit.ArkUI';

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
    // 如果文本中包含 \frac (分数)、^ (指数)、_ (下标)、\int (积分) 等复杂结构
    if (content.includes('\\int')) {
      return isOutput ? 48 : 48; // 给予更高的高度
    }
    if (content.includes('\\frac')) {
      return isOutput ? 36 : 36; // 给予更高的高度
    }
    return isOutput ? 24 : 24; // 普通单行数字，保持紧凑高度
  }

  async loadData() {
    // 引擎不管外壳是谁，只管根据传进来的 moduleType 去查数据库
    let limit = this.isGlobalPage ? 100 : 50;
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, limit);
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
          // 将这条记录从当前数组中剔除，ArkUI 会自动播放一个极其完美的卡片向上收缩消散动画
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

          ForEach(this.historyList, (item: HistoryRecord) => {
            ListItem() {
              Row() {
                // ==================== 【左侧模块图标】 ====================
                SymbolGlyph($r('sys.symbol.calculator_fill'))
                .fontSize(22) // 尺寸与 18vp 的字号完美匹配，精致而不突兀
                .fontColor([$r('sys.color.icon_emphasize')]) // 使用次级图标色，保持低调优雅，不抢风头
                .margin({ right: 14 }) // 与右侧内容区域拉开舒适的呼吸间距
                .alignSelf(ItemAlign.Center)

                // ==================== 【右侧内容区】 ====================
                Column() {
                  // ==================== 【输入区靠左】 ====================
                  if (item.inputBase64 && item.inputBase64.length > 0) {
                    Row() {
                      Image(item.inputBase64)
                        .height(this.getDynamicHeight(item.inputContent, false))
                        .objectFit(ImageFit.Contain)
                        // 反色逻辑（适配深色模式）
                        .colorFilter(this.isDarkMode ? [
                          -1,  0,  0, 0, 255,
                          0, -1,  0, 0, 255,
                          0,  0, -1, 0, 255,
                          0,  0,  0, 1,   0
                        ] : undefined)
                        // 70% 透明度，降低输入的显示权重
                        .opacity(0.7)
                    }
                    .width('100%')
                    // 弹性容器靠左对齐
                    .justifyContent(FlexAlign.Start)
                  } else {
                    // 如果是纯文本，也使用系统的次级文本色
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
                    // 踢掉 Blank()，回归纯粹的靠右对齐！
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
              // 所有原本属于卡片主体的样式（边距、背景色、圆角、点击事件）全部平移升级到最外层的 Row 上
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
              end: {
                builder: () => { this.deleteAction(item) }, // 绑定我们上面打造的红色垃圾桶
              },
              edgeEffect: SwipeEdgeEffect.Spring // 注入灵魂：加上极其 Q 弹的原生果冻回弹（拉过头会弹回去）！
            })
          }, (item: HistoryRecord) => item.id?.toString())

          // 如果是全局页面，底部增加占位以避开 Tab 栏
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(this.navBarHeight + 64) }
          } else {
            // 为半模态抽屉增加底部小白条的安全避让高度
            ListItem() { Row().width('100%').height(12) }
          }
        }
        .layoutWeight(1)
        .width('100%')
        // 根据是否为全局页面调整内边距
        .padding({ top: 0, bottom: 0 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .fadingEdge(true, { fadingEdgeLength:LengthMetrics.vp(12) })
      }
    }
    .width('100%')
    .height('100%')
  }
}