// 直接验证生产快照校验；设备重启和网络生命周期仍需集成验收。
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
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
for (const value of ['0','0.','12.','100','1e+25','-1.25']) assert.equal(amount(value), true);
for (const value of ['--','Error','NaN','Infinity','1e999','100oops','',null,{},42]) {
  assert.equal(amount(value), false);
  assert.equal(user({...saved,baseAmount:value}).baseAmount, '100');
}
assert.deepEqual(rates({USD:1,CNY:7,HKD:0,EUR:-1,JPY:Infinity,GBP:'2',BAD:1}), {USD:1,CNY:7});
assert.deepEqual(rates([]), {});
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
console.log('Exchange snapshot validation and cache time checks passed');
