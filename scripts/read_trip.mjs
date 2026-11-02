// Read-back verification (T9): dump today's trips with the 0.16 driver
// identity fields — driverId + wardIds. Read-only, no writes.
//   GOOGLE_APPLICATION_CREDENTIALS=<adc.json> node scripts/read_trip.mjs <driverCode?>
import { createRequire } from 'node:module';

const require = createRequire(
  new URL('../functions/package.json', import.meta.url),
);
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: process.env.FIREBASE_PROJECT || 'safaaisaathi-63a87',
});
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
