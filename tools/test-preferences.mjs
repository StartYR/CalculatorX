// SDK 替身只验证提交顺序和失败处理；落盘正确性仍需正式 Ability 的重启测试。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { runInNewContext } from 'node:vm';

const cache = new Map();
const disk = new Map();
const store = {
  failInit: false, failRead: false, failPut: false, failFlush: false, flushes: 0, gate: null,
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
      url: 'data:text/javascript,export const preferences={getPreferencesSync:()=>{const s=globalThis.preferenceTestStore;if(s.failInit)throw Error("init");return s;}};' };
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
store.failInit = true;
assert.equal(manager.init({}), false);
assert.equal(manager.get('before-init', 0), 7);
store.failInit = false;
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

// 后台必须先收集防抖窗口中的输入，回调异常不能阻止其他模块提交。
let collected = 0;
const onSave = () => { collected++; manager.stage('lifecycle', 'latest'); };
const brokenSave = () => { throw Error('callback'); };
manager.registerSave(brokenSave);
manager.registerSave(onSave);
manager.registerSave(onSave);
manager.savePending();
await manager.commit();
assert.equal(collected, 1);
assert.equal(disk.get('lifecycle'), 'latest');
manager.unregisterSave(onSave);
manager.unregisterSave(brokenSave);
manager.savePending();
await manager.commit();
assert.equal(collected, 1);

// 合成绘图样本验证大字符串经过生产提交层后没有缺项；不代表真实 SDK 容量或渲染性能。
const graph = Array.from({length:10}, (_, index) => ({id:String(index), color:'#FF0000', isVisible:true,
  type:1, latex:'x(t)='+'t+'.repeat(1024)+'0', latex2:'y(t)=sin(t)',
  base64:Buffer.alloc(256*1024, index).toString('base64'), base64_2:Buffer.alloc(256*1024, index+1).toString('base64'),
  ast:JSON.stringify({sample:'x'.repeat(64*1024)}), ast2:JSON.stringify({sample:'y'.repeat(64*1024)}),
  tMin:-10, tMax:10}));
const graphJson = JSON.stringify(graph);
const graphBytes = Buffer.byteLength(graphJson, 'utf8');
assert.ok(graphBytes < 16*1024*1024);
manager.set('graphingFunctions', graphJson);
assert.equal((await manager.commit()).ok, true);
assert.deepEqual(JSON.parse(disk.get('graphingFunctions')), graph);

// 提取绘图组件的非 UI 存储路径，覆盖读失败、类型损坏和原有迁移备份。
const graphSource = readFileSync(new URL('../entry/src/main/ets/components/graphing/GraphingCalc.ets', import.meta.url), 'utf8');
const helperStart = graphSource.indexOf('private createDefaultFunction()');
const appearStart = graphSource.indexOf('  aboutToAppear()', helperStart);
const appearEnd = graphSource.indexOf('    this.darkMediaQuery.on(', appearStart);
const saveStart = graphSource.indexOf('private saveFunctions =');
const saveEnd = graphSource.indexOf('  onShiftChange()', saveStart);
assert.ok(helperStart >= 0 && appearStart > helperStart && appearEnd > appearStart && saveStart >= 0 && saveEnd > saveStart);
const GraphStorage = runInNewContext(stripTypeScriptTypes('class GraphStorage {\n' +
  'graphingFunctionsJson = "[]"; functionList = []; canPersistFunctions = true;\n' +
  graphSource.slice(helperStart, appearEnd) + '}\n' + graphSource.slice(saveStart, saveEnd) + '}\nGraphStorage;'), {
  PreferenceManager: manager,
  PreferenceConfigs: {KEY_GRAPHING_FUNCTIONS:'graphingFunctions', KEY_GRAPHING_FUNCTIONS_MIGRATION_BACKUP:'graphingBackup'},
  GRAPHING_COLORS:['#FF0000'],
  FunctionType:{NORMAL:0, PARAMETRIC:1, POLAR:2, IMPLICIT:3, POINT:4}
});
store.failRead = true;
const unreadGraph = new GraphStorage();
const graphFlushes = store.flushes;
unreadGraph.aboutToAppear();
unreadGraph.saveFunctions();
await manager.commit();
assert.equal(unreadGraph.canPersistFunctions, false);
assert.equal(store.flushes, graphFlushes);
assert.equal(cache.get('graphingFunctions'), graphJson);
store.failRead = false;
cache.set('graphingFunctions', 42);
const wrongTypeGraph = new GraphStorage();
wrongTypeGraph.aboutToAppear();
wrongTypeGraph.saveFunctions();
await manager.commit();
assert.equal(wrongTypeGraph.canPersistFunctions, false);
assert.equal(cache.get('graphingFunctions'), 42);
assert.equal(store.flushes, graphFlushes);

cache.set('graphingFunctions', graphJson);
const loadedGraph = new GraphStorage();
loadedGraph.aboutToAppear();
assert.deepEqual(JSON.parse(JSON.stringify(loadedGraph.functionList)), graph);
loadedGraph.saveFunctions();
await manager.commit();
assert.deepEqual(JSON.parse(disk.get('graphingFunctions')), graph);
const legacyGraph = '[{"id":"old","latex":"x^2","base64":"image"}]';
cache.set('graphingFunctions', legacyGraph);
const migratedGraph = new GraphStorage();
migratedGraph.aboutToAppear();
await manager.commit();
assert.equal(disk.get('graphingBackup'), legacyGraph);
assert.equal(JSON.parse(disk.get('graphingFunctions'))[0].latex, 'x^2');
cache.set('graphingFunctions', '{broken');
new GraphStorage().aboutToAppear();
await manager.commit();
assert.equal(disk.get('graphingBackup'), '{broken');
console.log(`Synthetic graph snapshot: ${graphBytes} UTF-8 bytes, 10 functions`);
console.log('Preferences commit, failure and retry checks passed');
