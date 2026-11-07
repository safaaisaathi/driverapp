// Unit tests for the adoption regression guard.
// Run with `npm --prefix scripts run test:adoption`.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { compareRecords } from './check-adoption.mjs';

function record(overrides = {}) {
  return {
    contractVersion: '2.3.0',
    extensionVersion: '1',
    coreChanges: {
      'CHG-0001': {
        status: 'adopted',
        progress: 1,
        checklist: [
          { task: 'first', done: true },
          { task: 'second', done: false },
        ],
      },
      'CHG-0002': { status: 'in_progress', progress: 0.5 },
    },
    extensionChanges: {},
    ...overrides,
  };
}

function withChange(id, change) {
  const base = record();
  return {
    ...base,
    coreChanges: { ...base.coreChanges, [id]: change },
  };
}

test('an unchanged record passes', () => {
  assert.deepEqual(compareRecords(record(), record()), []);
});

test('a forward contract version passes', () => {
  assert.deepEqual(compareRecords(record(), record({ contractVersion: '2.4.0' })), []);
});

test('a backwards contract version fails', () => {
  const problems = compareRecords(record(), record({ contractVersion: '2.1.0' }));
  assert.equal(problems.length, 1);
  assert.match(problems[0], /contractVersion went backwards/);
});

test('a backwards extension version fails', () => {
  const problems = compareRecords(record(), record({ extensionVersion: '0' }));
  assert.equal(problems.length, 1);
  assert.match(problems[0], /extensionVersion went backwards/);
});

test('adopted to in_progress fails', () => {
  const problems = compareRecords(
    record(),
    withChange('CHG-0001', { status: 'in_progress', progress: 0.5 })
  );
  assert.ok(problems.some((line) => /CHG-0001 went backwards: adopted -> in_progress/.test(line)));
});

test('adopted to not_started fails', () => {
  const problems = compareRecords(record(), withChange('CHG-0001', { status: 'not_started' }));
  assert.ok(problems.some((line) => /CHG-0001 went backwards: adopted -> not_started/.test(line)));
});

test('a removed adopted change fails', () => {
  const next = record();
  delete next.coreChanges['CHG-0001'];
  const problems = compareRecords(record(), next);
  assert.ok(problems.some((line) => /CHG-0001 was adopted and is now missing/.test(line)));
});

test('in_progress to not_started fails', () => {
  const problems = compareRecords(record(), withChange('CHG-0002', { status: 'not_started' }));
  assert.ok(
    problems.some((line) => /CHG-0002 went backwards: in_progress -> not_started/.test(line))
  );
});

test('a finished checklist task that flips back fails', () => {
  const problems = compareRecords(
    record(),
    withChange('CHG-0001', {
      status: 'adopted',
      progress: 1,
      checklist: [
        { task: 'first', done: false },
        { task: 'second', done: false },
      ],
    })
  );
  assert.ok(problems.some((line) => /checklist task went backwards: first/.test(line)));
});

test('a finished checklist task that disappears fails', () => {
  const problems = compareRecords(
    record(),
    withChange('CHG-0001', {
      status: 'adopted',
      progress: 1,
      checklist: [{ task: 'second', done: false }],
    })
  );
  assert.ok(problems.some((line) => /checklist task disappeared: first/.test(line)));
});

test('progress going down fails', () => {
  const problems = compareRecords(
    record(),
    withChange('CHG-0001', {
      status: 'adopted',
      progress: 0.5,
      checklist: [
        { task: 'first', done: true },
        { task: 'second', done: false },
      ],
    })
  );
  assert.ok(problems.some((line) => /progress went backwards: 1 -> 0.5/.test(line)));
});

test('a not_started change can be removed', () => {
  const before = record();
  before.coreChanges['CHG-0003'] = { status: 'not_started' };
  const after = record();
  delete after.coreChanges['CHG-0003'];
  assert.deepEqual(compareRecords(before, after), []);
});
