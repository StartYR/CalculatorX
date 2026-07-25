/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file UniversalHistoryList.ets
 * @description 通用历史记录列表组件，支持按模块类型筛选展示计算图文记录
* * @author 易睿 (Yi Rui)
 * @date 2026
 */

import { HistoryRepository, HistoryRecord } from '../../database/HistoryRepository';
import { mediaquery, LengthMetrics } from '@kit.ArkUI';

@Component
export struct UniversalHistoryList {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  @Prop moduleType: string = 'scientific';
  @Prop isGlobalPage: boolean = false;
  @Prop @Watch('loadData') refreshCounter: number = 0;

  @State historyList: HistoryRecord[] = [];

  @State isDarkMode: boolean = false;
  private darkModeListener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('(dark-mode: true)');

  onItemClick?: (record: HistoryRecord, insertType: 'input' | 'output') => void;

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

  // 判断单条历史记录所需的高度
  getDynamicHeight(content: string, isOutput: boolean): number {
    if (!content) return 24;
    if (content.includes('bmatrix')) return 48;
    if (content.includes('\\int')) {
      if (content.includes('\\frac')) {
        return 48
      }
      return 36;
    }
    if (content.includes('\\sum') || content.includes('\\prod')) return 48;
    if (content.includes('\\lim')) {
      if (content.includes('\\frac')) {
        return 40;
      }
      return 30;
    }
    if (content.includes('\\frac')) return 36;
    return 24;
  }

  // 根据模块类型动态分配图标资源
  getIconForModule(moduleType: string): Resource {
    switch (moduleType) {
      case 'basic':
        return $r('sys.symbol.calculator_1');
      case 'scientific':
        return $r('sys.symbol.calculator_fill');
      case 'matrix':
        return $r('sys.symbol.square_fill_grid_2x2');
      case 'equation':
        return $r('sys.symbol.exponentiation');
      default:
      // 兜底图标
        return $r('sys.symbol.list_bullet_square_fill');
    }
  }

  async loadData() {
    let limit = this.isGlobalPage ? 100 : 50;
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, limit);
  }

  // 智能日期转换器
  private getTitleForDate(timestamp: number): string {
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    const yesterdayStr = `${yesterday.getFullYear()}-${yesterday.getMonth()}-${yesterday.getDate()}`;

    const recordDate = new Date(timestamp || Date.now());
    const recordStr = `${recordDate.getFullYear()}-${recordDate.getMonth()}-${recordDate.getDate()}`;

    if (recordStr === todayStr) return '今天';
    if (recordStr === yesterdayStr) return '昨天';
    return `${recordDate.getMonth() + 1}月${recordDate.getDate()}日`;
  }

  // 动态抽取当前所有的分组标题（保持 Key 的极度纯净）
  private getGroupedTitles(): string[] {
    const titles: string[] = [];
    this.historyList.forEach((record) => {
      const title = this.getTitleForDate(record.timestamp);
      if (!titles.includes(title)) {
        titles.push(title);
      }
    });
    return titles;
  }

  @Builder
  itemHead(text: string) {
    Text(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })
      .backgroundColor(Color.Transparent)
  }

  async deleteRecord(item: HistoryRecord) {
    if (item.id !== undefined) {
      await HistoryRepository.deleteRecord(item.id);
    }

    animateTo({ duration: 350, curve: Curve.Friction }, () => {
      this.historyList = this.historyList.filter(record => record.id !== item.id);
    });
  }

  @Builder
  deleteAction(item: HistoryRecord) {
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
        this.deleteRecord(item);
      })
    }
    .height('100%')
    .padding({ left: 16, right: 24 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.historyList.length === 0) {
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
        List({ space: 8 }) {
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(96) }
          }
          // 外层循环只绑定纯净的标题字符串
          ForEach(this.getGroupedTitles(), (title: string) => {
            ListItemGroup({ header: this.itemHead(title), space: 8 }) {
              ForEach(this.historyList.filter(item => this.getTitleForDate(item.timestamp) === title), (item: HistoryRecord) => {
                ListItem() {
                  Row() {
                    // ==================== 【左侧模块图标】 ====================
                    SymbolGlyph(this.getIconForModule(item.moduleType))
                      .fontSize(22)
                      .fontColor([$r('sys.color.icon_emphasize')])
                      .margin({ right: 14 })
                      .alignSelf(ItemAlign.Center)

                    // ==================== 【右侧内容区】 ====================
                    Column() {
                      // 插入表达式热区
                      Column() {
                        if (item.inputBase64 && item.inputBase64.length > 0) {
                          Row() {
                            Image(item.inputBase64)
                              .height(this.getDynamicHeight(item.inputContent, false))
                              .objectFit(ImageFit.Contain)
                              .colorFilter(this.isDarkMode ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                              .opacity(0.7)
                          }
                          .width('100%')
                          .justifyContent(FlexAlign.Start)
                        } else {
                          Text(item.inputContent)
                            .fontSize(18)
                            .fontColor($r('sys.color.font_secondary'))
                            .width('100%')
                            .textAlign(TextAlign.Start)
                            .maxLines(3)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                      }
                      .width('100%')
                      .padding({ top: 12, bottom: 2 })
                      .onClick(() => {
                        if (this.onItemClick) this.onItemClick(item, 'input');
                      })

                      // 插入结果热区
                      Column() {
                        if (item.outputBase64 && item.outputBase64.length > 0) {
                          Row() {
                            Text('=  ').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                            Image(item.outputBase64)
                              .height(this.getDynamicHeight(item.outputContent, true))
                              .objectFit(ImageFit.Contain)
                              .colorFilter(this.isDarkMode ? [ -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0 ] : undefined)
                          }
                          .width('100%')
                          .justifyContent(FlexAlign.End)
                          .alignItems(VerticalAlign.Center)
                        } else {
                          Text(`=  ${item.outputContent}`).fontSize(18).fontWeight(FontWeight.Medium)
                            .fontColor($r('sys.color.font_primary')).width('100%').textAlign(TextAlign.End)
                        }
                      }
                      .width('100%')
                      .padding({ top: 2, bottom: 12 })
                      .onClick(() => {
                        if (this.onItemClick) this.onItemClick(item, 'output');
                      })
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
                  end: { builder: () => { this.deleteAction(item) } },
                  edgeEffect: SwipeEdgeEffect.Spring
                })
              }, (item: HistoryRecord) => item.id?.toString())

            }
          }, (title: string) => title)

          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(this.navBarHeight + 64) }
          } else {
            ListItem() { Row().width('100%').height(12) }
          }
        }
        .sticky(StickyStyle.Header)
        // .margin({ top: this.isGlobalPage ? 96 : 0 })
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