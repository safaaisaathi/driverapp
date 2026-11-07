#!/usr/bin/env node
// Fails when a change moves the adoption record backwards.
//
// The base is the commit this work lands on:
//   - pull_request: github.event.pull_request.base.sha
//   - push:         github.event.before
// A missing or all-zero base (first push, workflow_dispatch) has nothing to
// compare against, so the check passes.
//
// Two regressions fail the run:
//   - contractVersion goes backwards
//   - a change that was adopted becomes not_started or disappears
//
// Read only. It writes nothing.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const FILE = '.contract/adopted.json';
const GROUPS = ['coreChanges', 'extensionChanges'];

function fail(lines) {
  for (const line of lines) console.error(`adoption record: ${line}`);
  process.exit(1);
}

function gitShow(ref) {
  try {
    return execFileSync('git', ['show', `${ref}:${FILE}`], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return undefined;
  }
}

function parse(text, label) {
  try {
    return JSON.parse(text);
  } catch {
    return fail([`${label} is not valid JSON`]);
  }
}

function parts(version) {
  return String(version ?? '0').split('.').map((part) => {
    const value = Number.parseInt(part, 10);
    return Number.isNaN(value) ? 0 : value;
  });
}

function compareVersions(left, right) {
  const a = parts(left);
  const b = parts(right);
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    const one = a[index] ?? 0;
    const two = b[index] ?? 0;
    if (one !== two) return one < two ? -1 : 1;
  }
  return 0;
}

const base = process.env.BASE_SHA;
if (base === undefined || base.length === 0 || /^0+$/.test(base)) {
  console.log('adoption record: no base commit, nothing to compare');
  process.exit(0);
}

const baseText = gitShow(base);
if (baseText === undefined) {
  console.log(`adoption record: base ${base.slice(0, 7)} has no ${FILE}, skipping`);
  process.exit(0);
}

const before = parse(baseText, `base ${base.slice(0, 7)} ${FILE}`);
let after;
try {
  after = parse(readFileSync(FILE, 'utf8'), FILE);
} catch (cause) {
  fail([cause instanceof Error ? cause.message : String(cause)]);
}

if (typeof before !== 'object' || before === null || typeof after !== 'object' || after === null) {
  fail([`${FILE} must be a JSON object`]);
}

const problems = [];

if (compareVersions(after.contractVersion, before.contractVersion) < 0) {
  problems.push(
    `contractVersion went backwards: ${before.contractVersion ?? 'none'} -> ${after.contractVersion ?? 'none'}`
  );
}

for (const group of GROUPS) {
  const oldGroup = before[group] ?? {};
  const newGroup = after[group] ?? {};
  for (const [id, entry] of Object.entries(oldGroup)) {
    if (entry?.status !== 'adopted') continue;
    const next = newGroup[id];
    if (next === undefined) {
      problems.push(`${id} was adopted and is now missing`);
    } else if (next.status === 'not_started') {
      problems.push(`${id} went backwards: adopted -> not_started`);
    }
  }
}

if (problems.length > 0) fail(problems);

const adopted = GROUPS.flatMap((group) =>
  Object.values(after[group] ?? {}).filter((entry) => entry?.status === 'adopted')
).length;
console.log(
  `adoption record: ${after.contractVersion ?? 'none'}, ${adopted} adopted change(s), no regression`
);
