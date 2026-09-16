import { describe, expect, it } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import {
  CalculationRequest,
  CalculationResponse,
  CalculationTestBridge
} from '../utils/CalculationTestBridge';

const RESULT_PREFIX = 'CALCX_TEST_RESULT:';
const BATCH_SUMMARY_PREFIX = 'CALCX_TEST_BATCH_SUMMARY:';
const MAX_RESULT_LINE_LENGTH = 9500;
const MAX_BATCH_ITEMS = 50;

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

async function printResponse(response: CalculationResponse): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  let resultLine = RESULT_PREFIX + encodeResponse(response);
  if (resultLine.length > MAX_RESULT_LINE_LENGTH) {
    resultLine = RESULT_PREFIX + encodeResponse(responseFailure(response.requestId));
  }
  await delegator.print(resultLine);
}

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
        } else if (request.command === 'settings.set') {
          const response = await CalculationTestBridge.setSetting(
            request.requestId,
            request.setting ?? '',
            request.value ?? '',
            10000
          );
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
