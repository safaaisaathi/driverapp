#!/usr/bin/env node
// Fails when a change moves the adoption record backwards.
//
// The base is the commit this work lands on:
//   - pull_request: github.event.pull_request.base.sha
//   - push:         github.event.before
// A missing or all-zero base (first push, workflow_dispatch) has nothing to
// compare against, so the check passes.
//
// Regressions that fail the run:
//   - contractVersion or extensionVersion goes backwards
//   - an adopted or in-progress change is removed
//   - a status moves down (adopted > in_progress > not_started)
//   - a finished checklist task disappears or flips back to not done
//   - progress goes down
//
// Read only. It writes nothing.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const FILE = '.contract/adopted.json';
const GROUPS = ['coreChanges', 'extensionChanges'];
const STATUS_RANK = { not_started: 1, in_progress: 2, adopted: 3 };

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

export function compareVersions(left, right) {
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

function rank(status) {
  return STATUS_RANK[status] ?? 0;
}

function checklistProblems(id, before, after) {
  const problems = [];
  const oldItems = Array.isArray(before.checklist) ? before.checklist : [];
  const newItems = Array.isArray(after.checklist) ? after.checklist : [];
  for (const item of oldItems) {
    if (item?.done !== true) continue;
    const found = newItems.find((candidate) => candidate?.task === item.task);
    if (found === undefined) {
      problems.push(`${id} checklist task disappeared: ${item.task}`);
    } else if (found.done !== true) {
      problems.push(`${id} checklist task went backwards: ${item.task}`);
    }
  }
  return problems;
}

// Compares the base record with the head record. Pure, so the unit tests can
// drive every regression without git.
export function compareRecords(before, after) {
  if (typeof before !== 'object' || before === null || typeof after !== 'object' || after === null) {
    return [`${FILE} must be a JSON object`];
  }

  const problems = [];

  if (compareVersions(after.contractVersion, before.contractVersion) < 0) {
    problems.push(
      `contractVersion went backwards: ${before.contractVersion ?? 'none'} -> ${after.contractVersion ?? 'none'}`
    );
  }

  if (compareVersions(after.extensionVersion, before.extensionVersion) < 0) {
    problems.push(
      `extensionVersion went backwards: ${before.extensionVersion ?? 'none'} -> ${after.extensionVersion ?? 'none'}`
    );
  }

  for (const group of GROUPS) {
    const oldGroup = before[group] ?? {};
    const newGroup = after[group] ?? {};
    for (const [id, entry] of Object.entries(oldGroup)) {
      const oldRank = rank(entry?.status);
      if (oldRank <= 1) continue;

      const next = newGroup[id];
      if (next === undefined) {
        problems.push(`${id} was ${entry.status} and is now missing`);
        continue;
      }

      const newRank = rank(next?.status);
      if (newRank < oldRank) {
        problems.push(
          `${id} went backwards: ${entry.status} -> ${next.status ?? 'missing status'}`
        );
      }

      if (oldRank === 3) {
        problems.push(...checklistProblems(id, entry, next));
      }

      if (
        typeof entry?.progress === 'number' &&
        typeof next?.progress === 'number' &&
        next.progress < entry.progress
      ) {
        problems.push(`${id} progress went backwards: ${entry.progress} -> ${next.progress}`);
      }
    }
  }

  return problems;
}

function main() {
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

  const problems = compareRecords(before, after);
  if (problems.length > 0) fail(problems);

  const adopted = GROUPS.flatMap((group) =>
    Object.values(after[group] ?? {}).filter((entry) => entry?.status === 'adopted')
  ).length;
  console.log(
    `adoption record: ${after.contractVersion ?? 'none'}, ${adopted} adopted change(s), no regression`
  );
}

if (
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main();
}
