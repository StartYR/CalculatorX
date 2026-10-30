// SDK 替身验证版本边界、关闭语义和缓存；不模拟系统材质的实际绘制。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

let apiVersion = 26;
let allocations = 0;
const emptyMaterial = {};
globalThis.materialTestDevice = { apiAvailable: () => apiVersion >= 26 };
globalThis.materialTestSdk = new Proxy({
  Material: { empty: emptyMaterial },
  ImmersiveStyle: { REGULAR: 1, ULTRA_THICK: 2, THICK: 3, THIN: 4, ULTRA_THIN: 5 },
  ImmersiveMaterial: class {
    constructor(options) { this.options = options; allocations++; }
  }
}, {
  get(target, key) {
    assert.ok(apiVersion >= 26, `Low API must not read uiMaterial.${String(key)}`);
    return target[key];
  }
});
globalThis.$r = name => name;
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === '@ohos.deviceInfo') return { shortCircuit: true,
      url: 'data:text/javascript,export default globalThis.materialTestDevice;' };
    if (specifier === '@kit.ArkUI') return { shortCircuit: true,
      url: 'data:text/javascript,export const uiMaterial=globalThis.materialTestSdk;' };
    if (specifier === '@kit.UIDesignKit') return { shortCircuit: true,
      url: 'data:text/javascript,export const SystemMaterialParams={};export const hdsMaterial={MaterialType:{NONE:0,ADAPTIVE:100},MaterialLevel:{ADAPTIVE:10}};' };
    if (context.parentURL?.endsWith('.ets') && specifier.startsWith('.')) specifier += '.ets';
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', shortCircuit: true,
      source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8'), { mode: 'transform' }) };
    return next(url, context);
  }
});

const material = await import('../entry/src/main/ets/utils/ImmersiveMaterialUtils.ets');
const { KeyboardKeyRole: role } = await import('../entry/src/main/ets/components/common/keyboard/KeyboardKeyTypes.ets');
const factories = [material.createSheetMaterial, material.createDialogMaterial, material.createMenuMaterial,
  material.createSearchMaterial, material.createTopBarMaterial];
const roles = [role.CORE, role.FUNCTION, role.OPERATOR, role.DANGER, role.EMPHASIS, role.SHIFT];

for (const version of [23, 24, 25, 26]) {
  apiVersion = version;
  for (const globalEnabled of [false, true]) {
    for (const keyboardEnabled of [false, true]) {
      assert.equal(material.isKeyboardMaterialEnabled(keyboardEnabled, globalEnabled),
        version >= 26 && globalEnabled && keyboardEnabled);
    }
    assert.equal(material.isImmersiveMaterialEnabled(globalEnabled), version >= 26 && globalEnabled);
    assert.deepEqual(material.createNavigationMaterial(globalEnabled),
      { materialType: globalEnabled ? 100 : 0, materialLevel: 10 });
    for (const create of factories) {
      const result = create(globalEnabled);
      if (version < 26) assert.equal(result, undefined);
      else if (!globalEnabled) assert.equal(result, emptyMaterial);
      else assert.ok(result.options);
    }
    for (const keyRole of roles) {
      for (const shift of [false, true]) {
        const result = material.createKeyboardMaterial(keyRole, shift, globalEnabled);
        if (version < 26) assert.equal(result, undefined);
        else if (!globalEnabled) assert.equal(result, emptyMaterial);
        else assert.ok(result.options);
      }
    }
  }
  if (version < 26) assert.equal(allocations, 0);
}

// 已缓存的按键仍须响应关闭；重新开启复用原材质且不混淆 Shift 的两种语义。
const cached = material.createKeyboardMaterial(role.SHIFT, true);
const before = allocations;
assert.equal(material.createKeyboardMaterial(role.SHIFT, true, false), emptyMaterial);
assert.equal(material.createKeyboardMaterial(role.SHIFT, true), cached);
assert.notEqual(material.createKeyboardMaterial(role.SHIFT, false), cached);
assert.equal(material.createKeyboardMaterial(role.OPERATOR), material.createKeyboardMaterial(role.FUNCTION));
assert.equal(allocations, before);
assert.equal(material.isKeyboardMaterialEnabled(false), false);
assert.equal(material.isKeyboardMaterialEnabled(true), true);
assert.equal(material.createTopBarMaterial().options.lightEffect !== undefined, true);
// 低版本即使已有缓存也不能接触新 API 或返回缓存的沉浸材质。
apiVersion = 23;
assert.equal(material.createKeyboardMaterial(role.SHIFT, true), undefined);
console.log('Immersive policy, API 23–26 fallback, explicit disable and material cache checks passed.');
