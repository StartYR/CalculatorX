// 直接验证生产快照校验；设备重启和网络生命周期仍需集成验收。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { runInNewContext } from 'node:vm';
registerHooks({
  resolve(specifier, context, next) {
    if (context.parentURL?.endsWith('.ets') && specifier.startsWith('./')) specifier += '.ets';
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module', shortCircuit: true,
      source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')) };
    return next(url, context);
  }
});
const { normalizeExchangeUser: user, normalizeExchangeRates: rates, normalizeExchangeCache: cache,
  validExchangeAmount: amount, exchangeCacheValid: valid, defaultExchangeUser: defaults } =
  await import('../entry/src/main/ets/components/exchange/rates/ExchangeSnapshot.ets');
assert.deepEqual(user(null), defaults());
assert.deepEqual(user([]), defaults());
const saved = { schemaVersion: 1, currencyList: [{id:'b',code:'CNY'}, {id:'a',code:'USD'},
  {id:'c',code:'USD'}, {id:'a',code:'HKD'}, null, {id:'d',code:'BAD'}], activeId:'c', baseAmount:'200.' };
const restored = user(JSON.parse(JSON.stringify(saved)));
assert.deepEqual(restored.currencyList.map(item => item.id), ['b','a','c']);
assert.equal(restored.activeId, 'c');
assert.equal(restored.baseAmount, '200.');
assert.equal(user({...saved, activeId:'missing'}).activeId, 'b');
assert.deepEqual(user({currencyList:[{id:'a',code:'toString'},{id:'b',code:'constructor'}]}), defaults());
for (const value of ['0','0.','12.','100','1e+25','-1.25']) assert.equal(amount(value), true);
for (const value of ['--','Error','NaN','Infinity','1e999','100oops','',null,{},42]) {
  assert.equal(amount(value), false);
  assert.equal(user({...saved,baseAmount:value}).baseAmount, '100');
}
assert.deepEqual(rates({USD:1,CNY:7,HKD:0,EUR:-1,JPY:Infinity,GBP:'2',BAD:1}), {USD:1,CNY:7});
assert.deepEqual(rates([]), {});
assert.deepEqual(rates(JSON.parse('{"toString":1,"constructor":2,"__proto__":3,"USD":1}')), {USD:1});
const now = new Date(2026,8,30,10,20).getTime();
const old = new Date(2026,8,30,10,1).getTime();
const state = cache({ rates:{USD:1,CNY:7}, fetchedAt:old }, now);
assert.equal(valid(state, now), true);
assert.equal(valid(state, new Date(2026,8,30,11).getTime()), false);
assert.equal(valid({...state, fetchedAt:now+1}, now), false);
assert.equal(cache({ rates:{}, fetchedAt:old }, now).fetchedAt, 0);
assert.equal(cache({ rates:{CNY:7}, fetchedAt:now+1 }, now).fetchedAt, 0);
assert.equal(cache({ rates:{CNY:7}, fetchedAt:old }, now).fetchedAt, old);
assert.equal(cache({ rates:{CNY:7}, fetchedAt:old }, now).rates.CNY, 7);

// 只提取组件的非 UI 读取方法，验证实际保护逻辑；不模拟 ArkUI 或设备存储。
const component = readFileSync(new URL('../entry/src/main/ets/components/exchange/rates/ExchangeRate.ets', import.meta.url), 'utf8');
const begin = component.indexOf('private loadSnapshot(');
const end = component.indexOf('  loadData(): void', begin);
assert.ok(begin >= 0 && end > begin);
let readResult;
const backups = [];
const Reader = runInNewContext(stripTypeScriptTypes('class SnapshotReader {' + component.slice(begin, end) + '}\nSnapshotReader;'), {
  PreferenceManager: {read() {return readResult;}, set(key, value) {backups.push({key, value});}}
});
const reader = new Reader();
let migrations = 0;
const migrate = () => { migrations++; return {baseAmount:'200.'}; };
readResult = {ok:false, exists:false, value:''};
assert.equal(reader.loadSnapshot('user', migrate), undefined);
assert.equal(migrations, 0);
readResult = {ok:true, exists:false, value:''};
assert.equal(reader.loadSnapshot('user', migrate).baseAmount, '200.');
assert.equal(migrations, 1);
assert.equal(reader.loadSnapshot('user', () => { throw Error('legacy read'); }), undefined);
readResult = {ok:true, exists:true, value:JSON.stringify({...saved, schemaVersion:2})};
assert.equal(reader.loadSnapshot('user', migrate), undefined);
assert.equal(migrations, 1);
assert.equal(backups.length, 0);
readResult.value = JSON.stringify(saved);
assert.deepEqual(JSON.parse(JSON.stringify(reader.loadSnapshot('user', migrate))), saved);
readResult.value = '{broken' + 'x'.repeat(10000);
reader.loadSnapshot('user', migrate);
assert.equal(backups.length, 1);
assert.equal(backups[0].key, 'user.invalid');
assert.equal(backups[0].value.length, 8192);
console.log('Exchange snapshot validation and cache time checks passed');
