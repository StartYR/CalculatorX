/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file .ets
 * @description
* * @author 易睿 (Yi Rui)
 * @date 2026
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 历史记录数据模型
 */
export interface HistoryRecord {
  id?: number;          // 自增主键
  moduleType: string;   // 模块类型：'scientific'-科学计算, 'equation'-方程求解, 'graph'-函数图像 等
  inputContent: string; // 用户的输入内容（例如科学计算存原始 LaTeX 串）
  outputContent: string;// 计算出来的结果（例如科学计算存 C++ 返回的 LaTeX 结果）
  inputBase64?: string; // 输入的 PNG 图片 Base64
  outputBase64?: string;// 结果的 PNG 图片 Base64
  extraParams?: string; // 核心扩展槽：未来异构数据使用，存 JSON 字符串（如坐标轴边界、矩阵阶数等）
  timestamp: number;    // 毫秒级时间戳，用于排序
}

/**
 * 历史记录关系型数据库仓库
 */
export class HistoryRepository {
  private static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'CalculatorXHistory.db', // 数据库文件名
    securityLevel: relationalStore.SecurityLevel.S1 // 安全等级
  };

  // 统一的单表结构，支持未来全功能模块扩展
  private static readonly SQL_CREATE_TABLE = `
    CREATE TABLE IF NOT EXISTS history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      module_type TEXT NOT NULL,
      input_content TEXT NOT NULL,
      output_content TEXT NOT NULL,
      input_base64 TEXT,
      output_base64 TEXT,
      extra_params TEXT,
      timestamp INTEGER NOT NULL
    );
  `;

  private static rdbStore: relationalStore.RdbStore | null = null;

  /**
   * 初始化数据库并建表、建索引
   * @param context 应用上下文
   */
  public static async init(context: common.Context): Promise<void> {
    if (HistoryRepository.rdbStore !== null) {
      return; // 避免重复初始化
    }
    try {
      const store = await relationalStore.getRdbStore(context, HistoryRepository.STORE_CONFIG);
      // 执行建表语句
      await store.executeSql(HistoryRepository.SQL_CREATE_TABLE);
      // 创建复合索引，优化按功能分类并且按时间倒序查询的性能（BindSheet 与 Tabs 切换的核心优化点）
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_module_timestamp ON history (module_type, timestamp DESC);');

      HistoryRepository.rdbStore = store;
      console.info('HistoryRepository: 数据库及索引初始化成功');
    } catch (err) {
      let e = err as Error;
      console.error(`HistoryRepository: 数据库初始化失败. message: ${e.message}`);
      throw new Error(e.message);
    }
  }


  /**
   * 插入一条历史记录
   * @param record 历史记录对象（不含id）
   * @returns 返回插入行的 rowId，失败返回 -1
   */
  public static async insertRecord(record: HistoryRecord): Promise<number> {
    if (!HistoryRepository.rdbStore) {
      console.error('HistoryRepository: 数据库未初始化，无法插入数据');
      return -1;
    }
    try {
      // ==================== 【新增核心：静默防刷屏机制】 ====================
      const predicates = new relationalStore.RdbPredicates('history');
      // 只查当前同一个计算模块的记录
      predicates.equalTo('module_type', record.moduleType);
      // 按时间倒序，最新的在最上面
      predicates.orderByDesc('timestamp');
      // 极其关键：只取这最顶上的一条数据（LIMIT 1），性能消耗趋近于 0
      predicates.limitAs(1);

      // 查询时只抽取出我们需要的字段，进一步压榨性能
      const resultSet = await HistoryRepository.rdbStore.query(predicates, ['id', 'input_content']);

      if (resultSet.goToFirstRow()) {
        const lastInput = resultSet.getString(resultSet.getColumnIndex('input_content'));
        const lastId = resultSet.getLong(resultSet.getColumnIndex('id'));

        // 如果用户刚刚算过的公式，和现在企图插入的公式完全一样
        if (lastInput === record.inputContent) {
          console.info('HistoryRepository: 拦截到连续重复计算，已执行静默去重');
          resultSet.close();
          // 极其致命的细节：返回上一条记录的 ID，骗过外部 UI，完成静默拦截！
          return lastId;
        }
      }
      resultSet.close(); // 必须关闭防泄漏
      // ====================================================================

      // 下面是原本正常的插入逻辑
      const valueBucket: relationalStore.ValuesBucket = {
        'module_type': record.moduleType,
        'input_content': record.inputContent,
        'output_content': record.outputContent,
        'input_base64': record.inputBase64 || '',
        'output_base64': record.outputBase64 || '',
        'extra_params': record.extraParams || '',
        'timestamp': record.timestamp
      };

      let rowId = await HistoryRepository.rdbStore.insert('history', valueBucket);

      // 滚动清理：保证单一模块最多只保留 100 条记录
      const sql = `DELETE FROM history WHERE module_type = '${record.moduleType}' AND id NOT IN (SELECT id FROM history WHERE module_type = '${record.moduleType}' ORDER BY timestamp DESC LIMIT 100)`;
      await HistoryRepository.rdbStore.executeSql(sql);

      return rowId;
    } catch (err) {
      // 增加类型断言，解决你之前的 err.message 隐式 any 报错风险
      let e = err as Error;
      console.error(`HistoryRepository: 插入记录失败. message: ${e.message}`);
      return -1;
    }
  }

  /**
   * 查询历史记录
   * @param moduleType 模块类型，如果传 'all' 或空则查询全部功能的混排记录
   * @param limit 查询数量上限，默认最多 50 条
   */
  public static async queryRecords(moduleType: string, limit: number = 50): Promise<HistoryRecord[]> {
    if (!HistoryRepository.rdbStore) {
      console.error('HistoryRepository: 数据库未初始化，无法查询');
      return [];
    }
    try {
      const predicates = new relationalStore.RdbPredicates('history');

      // 如果指定了具体模块且不是 'all'，则进行条件过滤
      if (moduleType && moduleType !== 'all') {
        predicates.equalTo('module_type', moduleType);
      }

      // 按时间戳从新到旧进行倒序排列
      predicates.orderByDesc('timestamp');

      if (limit > 0) {
        predicates.limitAs(limit);
      }

      const resultSet = await HistoryRepository.rdbStore.query(predicates);
      const records: HistoryRecord[] = [];

      while (resultSet.goToNextRow()) {
        const id = resultSet.getLong(resultSet.getColumnIndex('id'));
        const mType = resultSet.getString(resultSet.getColumnIndex('module_type'));
        const input = resultSet.getString(resultSet.getColumnIndex('input_content'));
        const output = resultSet.getString(resultSet.getColumnIndex('output_content'));
        const inputImg = resultSet.getString(resultSet.getColumnIndex('input_base64'));
        const outputImg = resultSet.getString(resultSet.getColumnIndex('output_base64'));

        console.info(`【探针2】DB读出 id=${id}, inputImg 长度: ${inputImg ? inputImg.length : 'undefined/null'}`);

        const extra = resultSet.getString(resultSet.getColumnIndex('extra_params'));
        const time = resultSet.getLong(resultSet.getColumnIndex('timestamp'));

        records.push({
          id: id,
          moduleType: mType,
          inputContent: input,
          outputContent: output,
          inputBase64: inputImg,
          outputBase64: outputImg,
          extraParams: extra,
          timestamp: time
        });
      }
      resultSet.close(); // 必须手动关闭结果集，防止内存泄漏
      return records;
    } catch (err) {
      console.error(`HistoryRepository: 查询历史记录失败. message: ${err.message}`);
      return [];
    }
  }

  /**
   * 清空指定模块的历史记录（或全量清空）
   * @param moduleType 模块类型，传 'all' 或不传则清空全表
   */
  public static async clearHistory(moduleType?: string): Promise<number> {
    if (!HistoryRepository.rdbStore) {
      return 0;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('history');
      if (moduleType && moduleType !== 'all') {
        predicates.equalTo('module_type', moduleType);
      }
      return await HistoryRepository.rdbStore.delete(predicates);
    } catch (err) {
      console.error(`HistoryRepository: 清空历史记录失败. message: ${err.message}`);
      return 0;
    }
  }

  /**
   * 删除单条指定 ID 的历史记录（供列表单条滑动删除或长按删除使用）
   * @param id 主键ID
   */
  public static async deleteRecord(id: number): Promise<number> {
    if (!HistoryRepository.rdbStore) {
      return 0;
    }
    try {
      const predicates = new relationalStore.RdbPredicates('history');
      predicates.equalTo('id', id);
      return await HistoryRepository.rdbStore.delete(predicates);
    } catch (err) {
      console.error(`HistoryRepository: 删除单条记录失败. message: ${err.message}`);
      return 0;
    }
  }
}