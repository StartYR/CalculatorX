// SDK 替身只验证提交顺序和失败处理；落盘正确性仍需正式 Ability 的重启测试。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const cache = new Map();
const disk = new Map();
const store = {
  failRead: false, failPut: false, failFlush: false, flushes: 0, gate: null,
  hasSync(key) { if (this.failRead) throw Error('read'); return cache.has(key); },
  getSync(key, fallback) { if (this.failRead) throw Error('read'); return cache.has(key) ? cache.get(key) : fallback; },
  putSync(key, value) { if (this.failPut) throw Error('put'); cache.set(key, value); },
  deleteSync(key) { cache.delete(key); },
  async flush() {
    this.flushes++;
    const snapshot = new Map(cache);
    if (this.gate) await this.gate;
    if (this.failFlush) throw Error('flush');
    disk.clear(); snapshot.forEach((value, key) => disk.set(key, value));
  }
};
globalThis.preferenceTestStore = store;
globalThis.$rawfile = name => name;
globalThis.$r = name => name;
const appStorage = new Map();
globalThis.AppStorage = { setOrCreate(key, value) { appStorage.set(key, value); } };
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === '@kit.ArkData') return { shortCircuit: true,
      url: 'data:text/javascript,export const preferences={getPreferencesSync:()=>globalThis.preferenceTestStore};' };
    if (specifier === '@kit.AbilityKit') return { shortCircuit: true, url: 'data:text/javascript,export const common={};' };
    if (specifier === '@ohos.hilog') return { shortCircuit: true,
      url: 'data:text/javascript,export default {info(){},error(){},warn(){},debug(){}};' };
    if (context.parentURL?.endsWith('.ets') && specifier.startsWith('./')) specifier += '.ets';
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', shortCircuit: true,
      source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')) };
    return next(url, context);
  }
});
const { PreferenceManager: manager } = await import('../entry/src/main/ets/utils/PreferenceManager.ets');
assert.equal(manager.read('absent', 3).ok, false);
manager.set('before-init', 7);
assert.deepEqual(await manager.commit(), { ok: false, pending: true });
assert.equal(manager.get('before-init', 0), 7);
manager.init({});
assert.equal((await manager.commit()).ok, true);
assert.equal(disk.get('before-init'), 7);
manager.setMany([{ key: 'a', value: 1 }, { key: 'b', value: 2 }]);
const flushes = store.flushes;
assert.equal((await manager.commit()).ok, true);
assert.equal(store.flushes, flushes + 1);
assert.equal(disk.get('b'), 2);
let release;
store.gate = new Promise(resolve => { release = resolve; });
manager.set('a', 10);
const waiting = manager.commit();
manager.set('a', 20);
manager.set('c', 30);
store.gate = null;
release();
assert.equal((await waiting).ok, true);
assert.equal(disk.get('a'), 20);
assert.equal(disk.get('c'), 30);
store.failFlush = true;
manager.set('a', 40);
assert.deepEqual(await manager.commit(), { ok: false, pending: true });
assert.equal(disk.get('a'), 20);
manager.stage('a', 50);
store.failFlush = false;
assert.equal((await manager.commit()).ok, true);
assert.equal(disk.get('a'), 50);
store.failPut = true;
manager.set('a', 60);
assert.equal((await manager.commit()).ok, false);
assert.equal(manager.get('a', 0), 60);
store.failPut = false;
assert.equal((await manager.commit()).ok, true);
assert.equal(disk.get('a'), 60);
store.failRead = true;
assert.deepEqual(manager.read('b', 99), { ok: false, exists: false, value: 99 });
store.failRead = false;
manager.remove('b');
assert.equal(manager.read('b', 99).exists, false);
await manager.commit();
assert.equal(disk.has('b'), false);
const finalFlushes = store.flushes;
manager.set('a', 60);
await manager.commit();
assert.equal(store.flushes, finalFlushes);
cache.set('isRad', 'bad');
cache.set('decimalPrecision', 99);
cache.set('colorModeIndex', 1);
cache.set('lastUsedModule', 'missing');
manager.loadAllToAppStorage();
assert.equal(appStorage.get('isRad'), true);
assert.equal(appStorage.get('decimalPrecision'), 6);
assert.equal(appStorage.get('colorModeIndex'), 1);
assert.equal(appStorage.get('lastUsedModule'), 'scientific');
assert.equal(cache.get('decimalPrecision'), 99);
cache.set('isRad', false);
cache.set('decimalPrecision', 16);
manager.loadAllToAppStorage();
assert.equal(appStorage.get('isRad'), false);
assert.equal(appStorage.get('decimalPrecision'), 16);
console.log('Preferences commit, failure and retry checks passed');
