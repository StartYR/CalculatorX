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
      imageRes: $r('app.media.image_dialog_help'),
      imageSize: { width: '100%', height: 180 },
      title: '如何插入历史记录？',
      content: '如图，历史记录分为上下两个区域：\n\n点击表达式区，即可插入表达式；\n点击结果区，即可插入结果。',
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
    Column() {
      // 1. 顶部实体标题栏
      Row() {
        Text('历史记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))

        // 帮助引导按钮
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ left: 0 })
        .onClick(() => {
          this.helpDialogController.open(); // 召唤图文弹窗
        })

        Blank()

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