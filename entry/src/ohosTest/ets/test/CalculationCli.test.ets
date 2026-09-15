import { describe, expect, it } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import {
  CalculationRequest,
  CalculationResponse,
  CalculationTestBridge
} from '../utils/CalculationTestBridge';

const RESULT_PREFIX = 'CALCX_TEST_RESULT:';
const MAX_RESULT_LINE_LENGTH = 9500;

function decodeRequest(payload: string): CalculationRequest {
  if (!/^[A-Za-z0-9_-]+$/.test(payload)) {
    throw new Error('calcxRequest is not URL-safe Base64');
  }
  const bytes = new util.Base64Helper().decodeSync(payload, util.Type.BASIC_URL_SAFE);
  const json = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
  const request = JSON.parse(json) as CalculationRequest;
  validateRequest(request);
  return request;
}

function validateRequest(request: CalculationRequest): void {
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

function encodeResponse(response: CalculationResponse): string {
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

export default function calculationCliTest(): void {
  describe('CalculationCliTest', () => {
    it('calculateFromLatex', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      const parameters = abilityDelegatorRegistry.getArguments().parameters;
      const payload = parameters['-s calcxRequest'] ?? parameters['calcxRequest'];
      let requestId = '';
      let response: CalculationResponse;
      try {
        const request = decodeRequest(payload ?? '');
        requestId = request.requestId;
        response = await CalculationTestBridge.calculate(request, 10000);
      } catch (error) {
        response = requestFailure(requestId, `${error}`);
      }

      let resultLine = RESULT_PREFIX + encodeResponse(response);
      if (resultLine.length > MAX_RESULT_LINE_LENGTH) {
        response = responseFailure(requestId);
        resultLine = RESULT_PREFIX + encodeResponse(response);
      }
      await delegator.print(resultLine);
      expect(response.ok).assertTrue();
    });
  });
}
