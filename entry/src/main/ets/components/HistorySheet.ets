// entry/src/main/ets/components/HistorySheet.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { UniversalHistoryList } from './UniversalHistoryList';

@Component
export struct HistorySheet {
  @Prop moduleType: string = 'scientific';
  @State refreshSignal: number = 0;
  @State hasData: boolean = true;

  onItemClick?: (record: HistoryRecord) => void;
  onClose?: () => void;

  aboutToAppear() {
    HistoryRepository.queryRecords(this.moduleType, 1).then(res => {
      this.hasData = res.length > 0;
    })
  }

  build() {
    // 褪去所有花里胡哨的 Stack，回归最清爽的 Column！
    Column() {
      // 1. 顶部实体标题栏
      Row() {
        Text('历史记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        Blank()
        if (this.hasData) {
          Text('清空').fontSize(14).fontColor($r('sys.color.font_secondary')).padding(8)
            .stateStyles({
              pressed: { .backgroundColor($r('sys.color.comp_background_secondary')) },
              normal: { .backgroundColor(Color.Transparent) }
            })
            .borderRadius(8)
            .onClick(async () => {
              await HistoryRepository.clearHistory(this.moduleType);
              this.hasData = false;
              this.refreshSignal++;
            })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 8 })
      // 没有任何毛玻璃，没有任何透明背景，就是最原生的样子

      // 2. 召唤底层引擎！
      UniversalHistoryList({
        moduleType: this.moduleType,
        isGlobalPage: false,
        refreshCounter: this.refreshSignal,
        onItemClick: (item: HistoryRecord) => {
          if (this.onItemClick) this.onItemClick(item);
          if (this.onClose) this.onClose();
        }
      })
        .layoutWeight(1) // 撑满标题下方的所有剩余空间
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}