// Shape + cross-reference checks for emulator/seed-data.json (B-25).
// Run with `npm --prefix scripts run test:seed`.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const seed = JSON.parse(
  await readFile(join(here, '..', 'emulator', 'seed-data.json'), 'utf8'),
);
const { wards, routes, vans, drivers, staff, notices } = seed.collections;

const ids = (collection) => new Set(Object.keys(collection));

test('route order points at real wards in the same route', () => {
  for (const wardId of routes['route-01'].wardIds) {
    assert.ok(wards[wardId], `route-01 lists missing ward ${wardId}`);
    assert.equal(wards[wardId].routeId, 'route-01');
  }
});

test('every ward names a real route and real staff', () => {
  const staffIds = ids(staff);
  for (const [wardId, ward] of Object.entries(wards)) {
    assert.ok(routes[ward.routeId], `${wardId} has an unknown routeId`);
    assert.ok(staffIds.has(ward.inspectorId), `${wardId} has an unknown inspectorId`);
    assert.ok(staffIds.has(ward.escalationTo), `${wardId} has an unknown escalationTo`);
  }
});

test('every driver and van references real data', () => {
  const wardIds = ids(wards);
  for (const [vanId, van] of Object.entries(vans)) {
    assert.ok(routes[van.routeId], `${vanId} has an unknown routeId`);
    assert.equal(van.currentTripId, null, `${vanId} must seed idle`);
    assert.equal(van.status, 'idle', `${vanId} must seed idle`);
  }
  for (const [code, driver] of Object.entries(drivers)) {
    assert.ok(vans[driver.vanId], `${code} has an unknown vanId`);
    assert.ok(routes[driver.routeId], `${code} has an unknown routeId`);
    for (const wardId of driver.wardIds) {
      assert.ok(wardIds.has(wardId), `${code} has an unknown wardId ${wardId}`);
    }
    assert.match(driver.phoneMasked, /^[0-9]{2}X{6}[0-9]{2}$/);
  }
});

test('every notice targets a real doc', () => {
  for (const [noticeId, notice] of Object.entries(notices)) {
    assert.ok(staff[notice.createdBy], `${noticeId} has an unknown createdBy`);
    if (notice.targetType === 'van') {
      assert.ok(vans[notice.targetId], `${noticeId} targets an unknown van`);
    }
    if (notice.targetType === 'ward') {
      assert.ok(wards[notice.targetId], `${noticeId} targets an unknown ward`);
    }
    if (notice.targetType === 'all') {
      assert.equal(notice.targetId, null);
    }
  }
});

test('no raw phone leaks into a readable seed doc', () => {
  for (const [code, driver] of Object.entries(drivers)) {
    assert.equal('phone' in driver, false, `${code} carries a raw phone`);
  }
  for (const [staffId, member] of Object.entries(staff)) {
    assert.equal('phone' in member, false, `${staffId} carries a raw phone`);
  }
});
