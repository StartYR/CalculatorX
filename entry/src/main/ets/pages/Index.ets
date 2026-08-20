/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file Index.ets
 * @description 全局唯一主入口，负责处理组件的动态挂载和系统级返回逻辑
 * * @author 易睿 (Yi Rui)
 * @date 2026
 */

import font from '@ohos.font';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { RoutePath, PreferenceConfigs, CURRENT_PRIVACY_VERSION } from '../utils/CalculatorConfigs';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { TopBar } from '../components/TopBar';
import { SideBarMenu } from '../components/SideBarMenu';
import { HistorySheet } from '../components/HistorySheet';
import { HistoryRepository } from '../database/HistoryRepository';

// 所有功能模块组件
import { ScientificCalc } from '../components/ScientificCalc';
import { BasicCalc } from '../components/BasicCalc';
import { MatrixCalc } from '../components/MatrixCalc';
import { GraphingCalc } from '../components/graphing/GraphingCalc';
import { EquationSolver } from '../components/EquationSolver';
import { StatisticsCalc } from '../components/StatisticsCalc';
import { UnitConverter } from '../components/UnitConverter';
import { BaseConverter } from '../components/exchange/BaseConverter';
import { ExchangeRate } from '../components/exchange/rates/ExchangeRate';

@Entry
@Component
struct Index {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('isRad') isRad: boolean = true;

  @State isSidebarOpen: boolean = false;
  @State isShowHistorySheet: boolean = false;

  @State currentModule: string = 'scientific'; // 默认值，将在 aboutToAppear 中被接管
  @State topBarIsShift: boolean = false;

  // 定义隐私弹窗控制器
  privacyDialogController: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog(),
    autoCancel: false, // 禁止点击弹窗外部的遮罩层关闭，必须显式点击“同意”或“不同意”
    alignment: DialogAlignment.Center,
    customStyle: true  // 允许使用在 PrivacyDialog 内部定义的背景色和圆角
  });

  // 历史记录面板的生成器 (作为全局遮罩，保留在主入口)
  @Builder HistorySheetBuilder() {
    HistorySheet({
      moduleType: this.currentModule, // 根据当前模块动态拉取历史记录
      onItemClick: (record, insertType: 'input' | 'output') => {
        let insertStr = insertType === 'input' ? record.inputContent : record.outputContent;
        getContext(this).eventHub.emit('event_math_insert', insertStr);
      },
      onClose: () => {
        this.isShowHistorySheet = false;
      }
    })
  }

  aboutToAppear() {
    HistoryRepository.init(getContext(this) as common.UIAbilityContext);
    font.registerFont({ familyName: 'Cambria Math', familySrc: $rawfile('fonts/Cambria Math.ttf') });
    font.registerFont({ familyName: 'Cambria Italic', familySrc: $rawfile('fonts/Cambria Italic.ttf') });

    PreferenceManager.init(getContext(this) as common.UIAbilityContext);
    PreferenceManager.loadAllToAppStorage();

    // 隐私声明弹窗，版本号比对
    let storedPrivacyVersion = AppStorage.get<number>(PreferenceConfigs.KEY_PRIVACY_VERSION) || 0;

    // 如果本地记录的版本号 小于 当前应用要求的版本号（新用户 0 < 10000），则唤起弹窗
    if (storedPrivacyVersion < CURRENT_PRIVACY_VERSION) {
      setTimeout(() => {
        this.privacyDialogController.open();
      }, 100);
    }

    const MODULE_MAP: string[] = [
      '',
      'scientific',
      'basic',
      'matrix',
      'graphing',
      'equation',
      'statistics',
      'unit',
      'base',
      'exchange'
    ];

    let startupMode = PreferenceManager.get(PreferenceConfigs.KEY_STARTUP_PAGE, 0) as number;

    if (startupMode === 0) {
      this.currentModule = PreferenceManager.get(PreferenceConfigs.KEY_LAST_USED_MODULE, 'scientific') as string;
    } else if (startupMode > 0 && startupMode < MODULE_MAP.length) {
      this.currentModule = MODULE_MAP[startupMode];
    } else {
      this.currentModule = 'scientific';
    }

    getContext(this).eventHub.on('event_shift_change', (isShiftActive: boolean) => {
      this.topBarIsShift = isShiftActive;
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ================= 1. 动态内容区 =================
      Column() {
        if (this.currentModule === 'scientific') {
          ScientificCalc()
        } else if (this.currentModule === 'basic') {
          BasicCalc()
        } else if (this.currentModule === 'matrix') {
          MatrixCalc()
        } else if (this.currentModule === 'graphing') {
          GraphingCalc()
        } else if (this.currentModule === 'equation') {
          EquationSolver()
        } else if (this.currentModule === 'statistics') {
          StatisticsCalc()
        } else if (this.currentModule === 'unit') {
          UnitConverter()
        } else if (this.currentModule === 'base') {
          BaseConverter()
        } else if (this.currentModule === 'exchange') {
          ExchangeRate()
        } else {
          // 兜底保护，防止出现白屏
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
        isShift: this.topBarIsShift,
        isRad: this.isRad,
        // 根据当前模块动态显示顶栏标题
        currentModule: this.currentModule,
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
          onSettingsClick: () => {
            router.pushUrl({ url: RoutePath.SETTINGS });
          },
          onHistoryClick: () => {
            router.pushUrl({ url: RoutePath.HISTORY });
          },
          // 响应侧边栏的模块切换，更新当前主板的状态
          onModuleSelect: (module: string) => {
            this.currentModule = module;
            this.topBarIsShift = false;

            // 每次切换时，静默记忆当前模块
            PreferenceManager.set(PreferenceConfigs.KEY_LAST_USED_MODULE, module);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}