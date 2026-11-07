// Read-back verification (T9): dump today's trips with the driver identity
// fields (driverId + wardIds). Read-only, no writes.
//
//   FIREBASE_PROJECT=<project> node scripts/read_trip.mjs [driverCode]
//
// There is no project default. Pass the emulator host to read the local suite:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//     FIREBASE_PROJECT=safaaisaathi-63a87 node scripts/read_trip.mjs
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT;
if (!projectId) {
  console.error(
    'Refusing to read: set FIREBASE_PROJECT. There is no project default.',
  );
  process.exit(1);
}

admin.initializeApp({ projectId });
const db = admin.firestore();

const code = process.argv[2];
const snap = await db
  .collection('trips')
  .orderBy('startedAt', 'desc')
  .limit(8)
  .get();

for (const doc of snap.docs) {
  const t = doc.data();
  if (code && t.driverId !== code) continue;
  console.log(
    JSON.stringify({
      id: doc.id,
      driverId: t.driverId ?? null,
      wardIds: t.wardIds ?? null,
      vanId: t.vanId,
      routeId: t.routeId,
      date: t.date?.toDate?.().toISOString?.() ?? String(t.date),
      startedAt: t.startedAt?.toDate?.().toISOString?.() ?? String(t.startedAt),
      endedAt: t.endedAt ? 'set' : null,
      wardsDone: Object.keys(t.wardsDone ?? {}),
    }),
  );
}
