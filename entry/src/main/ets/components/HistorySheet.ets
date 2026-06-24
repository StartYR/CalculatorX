// entry/src/main/ets/components/HistorySheet.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { UniversalHistoryList } from './UniversalHistoryList';
import { TipsDialog } from '@kit.ArkUI';

@Component
export struct HistorySheet {
  @Prop moduleType: string = 'scientific';
  @State refreshSignal: number = 0;
  @State hasData: boolean = true;

  onItemClick?: (item: HistoryRecord, insertType: 'input' | 'output') => void;
  onClose?: () => void;

  private helpDialogController: CustomDialogController = new CustomDialogController({
    builder: this.helpDialogBuilder,
    alignment: DialogAlignment.Center,
    autoCancel: true,
    cornerRadius: 16
  });

  @Builder
  helpDialogBuilder() {
    TipsDialog({
      // 注意：你需要自己在项目的 media 目录下放一张直观的示意图（比如画一条虚线把卡片切两半的图片）
      imageRes: $r('app.media.image_dialog_help'),
      imageSize: { width: '100%', height: 180 },
      title: '如何快速插入记录？',
      content: '为了提升计算效率，我们加入了“盲操”分区：\n\n👆 点击记录的上半部分（灰色公式），即可插入表达式。\n👇 点击记录的下半部分（黑色结果），即可插入答案。',
      // 精简掉不再提醒的 CheckBox，因为用户是主动点击问号的
      primaryButton: {
        value: '我知道了',
        action: () => {
          this.helpDialogController.close();
        }
      }
    })
  }

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

        // 【新增】：帮助引导按钮
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ right: 8 }) // 和右边的垃圾桶拉开一点间距
        .onClick(() => {
          this.helpDialogController.open(); // 召唤图文弹窗
        })



        if (this.hasData) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(20)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('sys.color.background_primary')) // 透明背景，只保留点击波纹
          .onClick(() => {
            // 防误触弹窗
            AlertDialog.show({
              title: '清空历史记录',
              message: '确定要清空此模式下的所有历史记录吗？此操作无法撤销。',
              alignment: DialogAlignment.Bottom,
              offset: { dx: 0, dy: -280 },
              primaryButton: {
                value: '取消',
                action: () => {} // 点击取消
              },
              secondaryButton: {
                value: '清空',
                fontColor: '#FF3B30',
                action: async () => {
                  await HistoryRepository.clearHistory(this.moduleType);
                  this.hasData = false;
                  this.refreshSignal++;
                }
              }
            })
          })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 0 })

      // 2. 召唤底层引擎！
      UniversalHistoryList({
        moduleType: this.moduleType,
        isGlobalPage: false,
        refreshCounter: this.refreshSignal,
        // onItemClick: (item: HistoryRecord) => {
        //   if (this.onItemClick) this.onItemClick(item);
        //   if (this.onClose) this.onClose();
        // }
        onItemClick: (item: HistoryRecord, insertType: 'input' | 'output') => {
          if (this.onItemClick) this.onItemClick(item, insertType);
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