/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file HistorySheet.ets
 * @description 局部历史半模态抽屉
 * * @author StartYi
 * @date 2026
 */

import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { UniversalHistoryList } from './common/UniversalHistoryList';
import { router, SymbolGlyphModifier, TipsDialog } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { createDialogMaterial } from '../utils/ImmersiveMaterialUtils';

@Component
export struct HistorySheet {
  @Prop moduleType: string = 'scientific';
  @State refreshSignal: number = 0;
  @State hasData: boolean = true;

  private scroller: Scroller = new Scroller();

  onItemClick?: (item: HistoryRecord, insertType: 'input' | 'output') => void;
  onClose?: () => void;
  onHistoryClick?: () => void;

  private helpDialogController: CustomDialogController = new CustomDialogController({
    builder: this.helpDialogBuilder,
    alignment: DialogAlignment.Center,
    autoCancel: true,
    cornerRadius: 32,
    systemMaterial: createDialogMaterial()
  });

  @Builder
  helpDialogBuilder() {
    TipsDialog({
      imageRes: $rawfile('help/insert_history.webp'),
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

  private showClearHistoryDialog(): void {
    AlertDialog.show({
      title: '清空历史记录',
      message: '确定要清空此模式下的所有历史记录吗？此操作无法撤销。',
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -280 },
      systemMaterial: createDialogMaterial(),
      primaryButton: {
        value: '取消',
        action: () => {}
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
  }

  private getTitleBarMenuItems(): HdsNavigationMenuItemOptions[] {
    const menuItems: HdsNavigationMenuItemOptions[] = [
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.questionmark_circle'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')]),
          label: '历史记录使用帮助',
          action: () => this.helpDialogController.open()
        }
      },
      {
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.arrow_counterclockwise_clock_fill'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')]),
          label: '打开全局历史记录',
          action: () => {
            router.pushUrl({ url: 'pages/history/HistoryManager' })
          }
        }
      }
    ];

    if (this.hasData) {
      menuItems.push({
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_primary')]),
          label: '清空当前历史记录',
          action: () => this.showClearHistoryDialog()
        }
      });
    }

    return menuItems;
  }

  build() {
    HdsNavigation() {
      UniversalHistoryList({
        moduleType: this.moduleType,
        isGlobalPage: false,
        refreshCounter: this.refreshSignal,
        topContentPadding: 64,
        scroller: this.scroller,
        onItemClick: (item: HistoryRecord, insertType: 'input' | 'output') => {
          if (this.onItemClick) this.onItemClick(item, insertType);
          if (this.onClose) this.onClose();
        }
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: '历史记录' },
        menu: {
          value: this.getTitleBarMenuItems(),
          maxCount: 3
        }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: { iconColor: $r('sys.color.icon_primary') }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: { iconColor: $r('sys.color.icon_primary') }
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      enableComponentSafeArea: false
    })
    .hideBackButton(true)
    .bindToScrollable([this.scroller])
    .titleMode(HdsNavigationTitleMode.MODAL)
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
