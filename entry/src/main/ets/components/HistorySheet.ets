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
    Column() {
      // 1. 顶部标题和清空按钮（保留外壳特征）
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
              this.refreshSignal++; // 改变变量，触发引擎刷新列表
            })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 12 })

      // 2. 召唤引擎！极其简洁！
      UniversalHistoryList({
        moduleType: this.moduleType,
        isGlobalPage: false,
        refreshCounter: this.refreshSignal,
        onItemClick: (item: HistoryRecord) => {
          // TODO: 未来如果新增函数图像、单位换算等模块，在此处根据 this.moduleType 编写不同的回填拦截逻辑！
          // 目前所有模块均执行标准的插入回填操作：
          if (this.onItemClick) {
            this.onItemClick(item);
          }
          if (this.onClose) {
            this.onClose();
          }
        }
      })
        .layoutWeight(1) // 撑满剩余空间
    }
    .width('100%')
    .constraintSize({ maxHeight: '75%' })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}