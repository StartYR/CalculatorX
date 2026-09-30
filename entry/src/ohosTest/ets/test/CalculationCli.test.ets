/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file CalculationCli.test.ets
 * @description 从 aa test 请求执行计算与设置预置并输出机器可读结果
 * @author StartYi
 * @date 2026/09/15 23:35
 */
import { describe, expect, it } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import {
  CalculationRequest,
  CalculationResponse,
  CalculationTestBridge
} from '../utils/CalculationTestBridge';

// aa test 日志还包含框架输出，宿主只解析此前缀后的 URL-safe Base64 响应。
const RESULT_PREFIX = 'CALCX_TEST_RESULT:';
const BATCH_SUMMARY_PREFIX = 'CALCX_TEST_BATCH_SUMMARY:';
const MAX_RESULT_LINE_LENGTH = 9500;
const MAX_BATCH_ITEMS = 50;

/** 一次性请求可为计算、批量计算或调试预置；字段长度与宿主侧校验共同限制负载。 */
interface CalculationCliRequest {
  protocolVersion: number;
  requestId: string;
  command?: string;
  latex?: string;
  mode?: string;
  angle?: string;
  precision?: string;
  items?: CalculationRequest[];
  setting?: string;
  value?: string;
}

interface CalculationBatchSummary {
  protocolVersion: number;
  requestId: string;
  ok: boolean;
  total: number;
  succeeded: number;
  failed: number;
}

interface EntryAbilityMonitor {
  abilityName: string;
  moduleName: string;
}

/** 拒绝非 URL-safe 输入，再用严格 UTF-8 解码，避免损坏的请求进入计算核心。 */
function decodeRequest(payload: string): CalculationCliRequest {
  if (!/^[A-Za-z0-9_-]+$/.test(payload)) {
    throw new Error('calcxRequest is not URL-safe Base64');
  }
  const bytes = new util.Base64Helper().decodeSync(payload, util.Type.BASIC_URL_SAFE);
  const json = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
  const request = JSON.parse(json) as CalculationCliRequest;
  validateRequest(request);
  return request;
}

function validateCalculationRequest(request: CalculationRequest): void {
  if (request.protocolVersion !== 1) {
    throw new Error('protocolVersion must be 1');
  }
  if (!request.requestId || request.requestId.length > 128) {
    throw new Error('requestId must contain 1 to 128 characters');
  }
  if (!request.latex || request.latex.length > 4096) {
    throw new Error('latex must contain 1 to 4096 characters');
  }
  if (!['standard', 'matrix', 'equation'].includes(request.mode)) {
    throw new Error('mode is invalid');
  }
  if (!['degree', 'radian'].includes(request.angle)) {
    throw new Error('angle is invalid');
  }
  if (request.precision !== 'auto' && request.precision !== 'decimal-auto' &&
    !/^(?:[0-9]|1[0-5])$/.test(request.precision)) {
    throw new Error('precision is invalid');
  }
}

/** 先按命令类型校验专属字段；普通计算复用单项校验。 */
function validateRequest(request: CalculationCliRequest): void {
  if (request.protocolVersion !== 1) {
    throw new Error('protocolVersion must be 1');
  }
  if (!request.requestId || request.requestId.length > 128) {
    throw new Error('requestId must contain 1 to 128 characters');
  }
  if (request.command === 'batch') {
    if (!request.items || request.items.length < 1 || request.items.length > MAX_BATCH_ITEMS) {
      throw new Error(`batch must contain 1 to ${MAX_BATCH_ITEMS} items`);
    }
    request.items.forEach((item: CalculationRequest) => validateCalculationRequest(item));
    return;
  }
  if (request.command === 'settings.set') {
    if (!request.setting || !request.value || request.setting.length > 64 || request.value.length > 64) {
      throw new Error('settings.set requires setting and value');
    }
    return;
  }
  if (request.command === 'formula.set') {
    if (request.latex === undefined || request.latex.length > 4096) {
      throw new Error('formula.set requires latex with at most 4096 characters');
    }
    return;
  }
  validateCalculationRequest(request as CalculationRequest);
}

function encodeResponse(response: CalculationResponse | CalculationBatchSummary): string {
  const bytes = util.TextEncoder.create('utf-8').encodeInto(JSON.stringify(response));
  return new util.Base64Helper().encodeToStringSync(bytes, util.Type.BASIC_URL_SAFE);
}

function requestFailure(requestId: string, error: string): CalculationResponse {
  return {
    protocolVersion: 1,
    requestId: requestId,
    ok: false,
    stage: 'request',
    error: error
  };
}

function responseFailure(requestId: string): CalculationResponse {
  return {
    protocolVersion: 1,
    requestId: requestId,
    ok: false,
    stage: 'response',
    error: 'Encoded response exceeds the test console limit'
  };
}

/** 控制单条日志长度；超限时返回可关联 requestId 的明确失败标记。 */
async function printResponse(response: CalculationResponse): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  let resultLine = RESULT_PREFIX + encodeResponse(response);
  if (resultLine.length > MAX_RESULT_LINE_LENGTH) {
    resultLine = RESULT_PREFIX + encodeResponse(responseFailure(response.requestId));
  }
  await delegator.print(resultLine);
}

// 顺序执行并逐项打印，宿主侧再依 requestId 聚合，最后输出批次摘要。
async function runBatch(request: CalculationCliRequest): Promise<CalculationBatchSummary> {
  const items = request.items ?? [];
  let succeeded = 0;
  for (const item of items) {
    const response = await CalculationTestBridge.calculate(item, 10000);
    if (response.ok) {
      succeeded++;
    }
    await printResponse(response);
  }
  return {
    protocolVersion: 1,
    requestId: request.requestId,
    ok: succeeded === items.length,
    total: items.length,
    succeeded: succeeded,
    failed: items.length - succeeded
  };
}

export default function calculationCliTest(): void {
  describe('CalculationCliTest', () => {
    it('calculateFromLatex', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const parameters = abilityDelegatorRegistry.getArguments().parameters;
      // 测试框架版本可能用两种参数键名，保留两条读取路径。
      const payload = parameters['-s calcxRequest'] ?? parameters['calcxRequest'];
      let requestId = '';
      let succeeded = false;
      try {
        const request = decodeRequest(payload ?? '');
        requestId = request.requestId;
        if (request.command === 'batch') {
          const summary = await runBatch(request);
          await delegator.print(BATCH_SUMMARY_PREFIX + encodeResponse(summary));
          succeeded = summary.ok;
        } else if (request.command === 'settings.set' || request.command === 'formula.set') {
          const entryMonitor: EntryAbilityMonitor = {
            abilityName: 'EntryAbility',
            moduleName: 'entry'
          };
          const entryWant: Want = {
            bundleName: abilityDelegatorRegistry.getArguments().bundleName,
            abilityName: 'EntryAbility'
          };
          let response: CalculationResponse = requestFailure(request.requestId, 'EntryAbility did not start');
          // 预置命令需要 UIAbilityContext；无论执行结果如何都释放监视器。
          await delegator.addAbilityMonitor(entryMonitor);
          try {
            await delegator.startAbility(entryWant);
            const entryAbility = await delegator.waitAbilityMonitor(entryMonitor, 10000);
            if (request.command === 'settings.set') {
              response = await CalculationTestBridge.setSetting(
                request.requestId,
                request.setting ?? '',
                request.value ?? '',
                10000,
                entryAbility.context
              );
            } else {
              response = await CalculationTestBridge.setFormula(
                request.requestId,
                request.latex ?? '',
                entryAbility.context
              );
            }
          } finally {
            await delegator.removeAbilityMonitor(entryMonitor);
          }
          await printResponse(response);
          succeeded = response.ok;
        } else {
          const response = await CalculationTestBridge.calculate(request as CalculationRequest, 10000);
          await printResponse(response);
          succeeded = response.ok;
        }
      } catch (error) {
        const response = requestFailure(requestId, `${error}`);
        await printResponse(response);
      }
      expect(succeeded).assertTrue();
    });
  });
}
