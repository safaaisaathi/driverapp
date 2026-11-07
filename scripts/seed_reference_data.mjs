// Seed the contract 2.0.0 reference data (B-25).
//
// Two targets, both idempotent (`set(..., { merge: true })`):
//   1. The local Emulator Suite: `--emulator` (defaults the host to
//      127.0.0.1:8080).
//   2. An explicit live project: `--project <id>` or `FIREBASE_PROJECT`.
//
// There is NO project default. A bare run exits before touching Firebase, so
// a stray command can never write to `safaaisaathi-63a87`. A project id that
// contains `prod` is refused outright.
//
//   npm --prefix scripts install
//   npm --prefix scripts run seed:emulator
//   FIREBASE_PROJECT=<project> npm --prefix scripts run seed
//
// `--dry-run` loads and validates the data without importing firebase-admin.
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const seedFile = join(here, '..', 'emulator', 'seed-data.json');
const allowedCollections = new Set([
  'wards',
  'routes',
  'vans',
  'drivers',
  'staff',
  'notices',
]);

const args = process.argv.slice(2);

function flag(name) {
  return args.includes(name);
}

function option(name) {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

const projectId = option('--project') || process.env.FIREBASE_PROJECT;
if (!projectId) {
  console.error(
    'Refusing to seed: set FIREBASE_PROJECT or pass --project <id>.\n' +
      'There is no project default, so a bare run cannot reach production.',
  );
  process.exit(1);
}
if (/prod/i.test(projectId)) {
  console.error(`Refusing to seed project "${projectId}": the id contains "prod".`);
  process.exit(1);
}

const emulator = flag('--emulator');
if (emulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
}

const dryRun = flag('--dry-run');
const raw = JSON.parse(await readFile(seedFile, 'utf8'));
const collections = raw.collections;
if (!collections || typeof collections !== 'object') {
  console.error(`Invalid seed file ${seedFile}: missing "collections".`);
  process.exit(1);
}

const unknown = Object.keys(collections).filter(
  (name) => !allowedCollections.has(name),
);
if (unknown.length > 0) {
  console.error(`Invalid seed file ${seedFile}: unknown collections ${unknown}`);
  process.exit(1);
}

/** `{ "$date": "<iso>" }` becomes a Firestore Timestamp via the admin SDK. */
function revive(value) {
  if (Array.isArray(value)) return value.map(revive);
  if (value && typeof value === 'object') {
    if (typeof value.$date === 'string') return new Date(value.$date);
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, revive(child)]),
    );
  }
  return value;
}

const docs = [];
for (const [collection, entries] of Object.entries(collections)) {
  if (!entries || typeof entries !== 'object') {
    console.error(`Invalid seed file ${seedFile}: "${collection}" is not an object.`);
    process.exit(1);
  }
  for (const [id, data] of Object.entries(entries)) {
    docs.push({ collection, id, data: revive(data) });
  }
}

const counts = Object.fromEntries(
  Object.keys(collections).map((name) => [name, Object.keys(collections[name]).length]),
);

if (dryRun) {
  console.log(`dry run: ${docs.length} docs in ${Object.keys(counts).length} collections`);
  for (const [name, count] of Object.entries(counts)) {
    console.log(`  ${name}: ${count}`);
  }
  process.exit(0);
}

if (!emulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Refusing a live seed without GOOGLE_APPLICATION_CREDENTIALS.\n' +
      'Use --emulator for the local suite, or point the variable at an ADC file.',
  );
  process.exit(1);
}

const adminModule = await import('firebase-admin');
const admin = adminModule.default ?? adminModule;
admin.initializeApp({
  projectId,
  ...(emulator ? {} : { credential: admin.credential.applicationDefault() }),
});

const db = admin.firestore();
const batch = db.batch();
for (const { collection, id, data } of docs) {
  batch.set(db.collection(collection).doc(id), data, { merge: true });
}
await batch.commit();

const target = emulator
  ? `emulator ${process.env.FIRESTORE_EMULATOR_HOST}`
  : `project ${projectId}`;
console.log(`seeded ${docs.length} docs into ${target}`);
for (const [name, count] of Object.entries(counts)) {
  console.log(`  ${name}: ${count}`);
}
