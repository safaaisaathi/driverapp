// Seed demo driver docs (PRD-2 0.16): drivers/{AB-0000}, admin-only data.
// Run from the repo root:
//   GOOGLE_APPLICATION_CREDENTIALS=~/.config/firebase/<your-adc>.json \
//     node scripts/seed_drivers.mjs
// Idempotent (merge set). Uses the firebase-admin package already installed
// for Cloud Functions, resolved from functions/node_modules.
import { createRequire } from 'node:module';

const require = createRequire(
  new URL('../functions/package.json', import.meta.url),
);
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: process.env.FIREBASE_PROJECT || 'safaaisaathi-63a87',
});
const db = admin.firestore();

const drivers = [
  {
    id: 'AB-1001',
    name: 'Ramesh Patel',
    phone: '+919812345678',
    vanId: 'van-01',
    routeId: 'route-01',
    wardIds: ['ward-1'],
    active: true,
  },
  {
    id: 'AB-1002',
    name: 'Suresh Bhai',
    phone: '+919898765432',
    vanId: 'van-01',
    routeId: 'route-01',
    wardIds: ['ward-1', 'ward-2', 'ward-3'],
    active: true,
  },
  {
    id: 'AB-1003',
    name: 'Kiran Shah',
    phone: '+919811223344',
    vanId: 'van-02',
    routeId: 'route-01',
    wardIds: ['ward-2'],
    active: true,
  },
  {
    id: 'AB-1004',
    name: 'Old Driver',
    phone: '+919800000000',
    vanId: 'van-01',
    routeId: 'route-01',
    wardIds: ['ward-3'],
    active: false,
  },
];

for (const { id, ...data } of drivers) {
  await db.collection('drivers').doc(id).set(data, { merge: true });
  console.log('seeded $id'.replace('$id', id), JSON.stringify(data));
}
console.log('done:', drivers.length, 'driver docs');
