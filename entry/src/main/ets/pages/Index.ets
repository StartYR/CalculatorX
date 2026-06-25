/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file .ets
 * @description
 * * @author 易睿 (Yi Rui)
 * @date 2026
 */

import font from '@ohos.font';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { RoutePath } from '../utils/CalculatorConfigs';
import { TopBar } from '../components/TopBar';
import { SideBarMenu } from '../components/SideBarMenu';
import { HistorySheet } from '../components/HistorySheet';
import { HistoryRepository } from '../database/HistoryRepository';

// [新增] 引入我们刚刚抽离的独立科学计算器面板
import { ScientificCalc } from '../components/ScientificCalc';

@Entry
@Component
struct Index {
  // 只保留全局共用的状态
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('isRad') isRad: boolean = false;

  @State isSidebarOpen: boolean = false;
  @State isShowHistorySheet: boolean = false;

  // [新增] 动态路由状态，默认为科学计算器
  @State currentModule: string = 'scientific';

  // 历史记录面板的生成器 (作为全局遮罩，保留在主入口)
  @Builder HistorySheetBuilder() {
    HistorySheet({
      moduleType: this.currentModule, // 根据当前模块动态拉取历史记录
      onItemClick: (record, insertType: 'input' | 'output') => {
        // [重构解耦] Webview已在子组件，通过 EventHub 将点击的字符串发给子组件
        let insertStr = insertType === 'input' ? record.inputContent : record.outputContent;
        getContext(this).eventHub.emit('event_math_insert', insertStr);
      },
      onClose: () => {
        this.isShowHistorySheet = false;
      }
    })
  }

  aboutToAppear() {
    // 数据库与字体依然在 App 启动入口进行初始化
    HistoryRepository.init(getContext(this) as common.UIAbilityContext);
    font.registerFont({ familyName: 'Cambria Math', familySrc: $rawfile('fonts/Cambria Math.ttf') });
    font.registerFont({ familyName: 'Cambria Italic', familySrc: $rawfile('fonts/Cambria Italic.ttf') });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {

      // ================= 1. 动态内容区 (插槽) =================
      Column() {
        if (this.currentModule === 'scientific') {
          ScientificCalc() // 动态挂载科学计算器面板
        } else {
          // 未来预留给 EquationSolver() 或 Graphing() 等
          Column() {
            Text('模块正在开发中...')
              .fontSize(18)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      // 侧边栏开启时的缩放卡片动效保持不变
      .scale({ x: this.isSidebarOpen ? 0.92 : 1.0, y: this.isSidebarOpen ? 0.92 : 1.0 })
      .borderRadius(this.isSidebarOpen ? 32 : 0)
      .backgroundColor($r('sys.color.background_primary'))

      // ================= 2. 全局顶部悬浮控制栏 =================
      TopBar({
        isShift: false, // 占位：UI已解耦，未来若需在顶栏显示Shift，可通过 AppStorage 同步
        isRad: this.isRad,
        moduleTitle: '科学计算',
        onMenuClick: () => {
          animateTo({ duration: 350, curve: Curve.Friction }, () => {
            this.isSidebarOpen = true;
          });
        },
        onUndoClick: () => {
          // 跨组件触发撤销
          getContext(this).eventHub.emit('event_math_undo');
        },
        onRedoClick: () => {
          // 跨组件触发重做
          getContext(this).eventHub.emit('event_math_redo');
        },
        onHistoryClick: () => {
          this.isShowHistorySheet = true;
        }
      })
        .bindSheet($$this.isShowHistorySheet, this.HistorySheetBuilder(), {
          height: '75%',
          dragBar: true,
          backgroundColor: $r('sys.color.background_secondary'),
          showClose: false
        })

      // ================= 3. 全局左侧侧边栏 =================
      if (this.isSidebarOpen) {
        SideBarMenu({
          isSidebarOpen: $isSidebarOpen,
          onSettingsClick: () => { router.pushUrl({ url: RoutePath.SETTINGS }); },
          onHistoryClick: () => { router.pushUrl({ url: RoutePath.HISTORY }); }
        })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}