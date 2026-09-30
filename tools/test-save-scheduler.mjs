// 使用虚拟时钟覆盖连续输入的最长等待及离开页面后的定时器清理。
import { stripTypeScriptTypes } from 'node:module';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const source = stripTypeScriptTypes(readFileSync(new URL('../entry/src/main/ets/utils/SaveScheduler.ets', import.meta.url), 'utf8'));
const { SaveScheduler } = await import('data:text/javascript,' + encodeURIComponent(source));
const originalSet = globalThis.setTimeout;
const originalClear = globalThis.clearTimeout;
let now = 0;
let nextId = 0;
const timers = new Map();
globalThis.setTimeout = (callback, delay) => { const id = ++nextId; timers.set(id, {callback, at:now+delay}); return id; };
globalThis.clearTimeout = id => timers.delete(id);
function advance(to) {
  for (;;) {
    const due = [...timers.entries()].filter(([, timer]) => timer.at <= to).sort((a,b) => a[1].at-b[1].at)[0];
    if (!due) break;
    timers.delete(due[0]); now=due[1].at; due[1].callback();
  }
  now=to;
}
try {
  let saves = 0;
  const scheduler = new SaveScheduler(() => { saves++; }, 500, 2000);
  scheduler.schedule(); advance(499); assert.equal(saves, 0);
  scheduler.schedule(); advance(998); assert.equal(saves, 0);
  advance(999); assert.equal(saves, 1); assert.equal(timers.size, 0);
  for (let time=1000;time<3000;time+=200) { advance(time); scheduler.schedule(); }
  advance(3000); assert.equal(saves, 2); assert.equal(timers.size, 0);
  scheduler.schedule(); scheduler.flush(); assert.equal(saves, 3);
  scheduler.flush(); advance(10000); assert.equal(saves, 3); assert.equal(timers.size, 0);
  console.log('Save debounce, maximum delay and lifecycle cleanup checks passed');
} finally { globalThis.setTimeout=originalSet; globalThis.clearTimeout=originalClear; }
