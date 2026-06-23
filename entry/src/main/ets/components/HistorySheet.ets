// entry/src/main/ets/components/HistorySheet.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { UniversalHistoryList } from './UniversalHistoryList';

@Component
export struct HistorySheet {
  @Prop moduleType: string = 'scientific';
  // 维护一个刷新标记，点清空时自增，触发内部引擎重新查库
  @State refreshSignal: number = 0;
  @State hasData: boolean = true;

  onItemClick?: (record: HistoryRecord) => void;
  onClose?: () => void;

  aboutToAppear() {
    // 初始化时简单查一下有没有数据，用来控制“清空”按钮的显示
    HistoryRepository.queryRecords(this.moduleType, 1).then(res => {
      this.hasData = res.length > 0;
    })
  }

  build() {
    // 【修改 1】：从 Column 改为 Stack，让内部组件可以在 Z 轴上前后层叠！
    // alignContent: Alignment.Top 保证标题栏始终吸顶
    Stack({ alignContent: Alignment.Top }) {

      // 第 1 层（底层）：我们的渲染引擎，让它占满整个 100% 屏幕
      UniversalHistoryList({
        moduleType: this.moduleType,
        isGlobalPage: false,
        refreshCounter: this.refreshSignal,
        onItemClick: (item: HistoryRecord) => {
          if (this.onItemClick) this.onItemClick(item);
          if (this.onClose) this.onClose();
        }
      })
        .width('100%')
        .height('100%')

      // 第 2 层（顶层）：标题栏悬浮在列表上方
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
      .padding({ left: 24, right: 24, top: 24, bottom: 12 })
      // 毛玻璃材质！
      .backgroundColor(Color.Transparent)
      .backgroundBlurStyle(BlurStyle.Regular)

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}