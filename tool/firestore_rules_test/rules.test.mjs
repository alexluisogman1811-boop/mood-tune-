// Runs firestore.rules in the local emulator (no real data is touched).
//   cd tool/firestore_rules_test && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const ADMIN = 'alexluisogman1811@gmail.com';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-moodscape',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const user = (uid, email, verified = true) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
const alice = () => user('alice', 'alice@example.com');
const bob = () => user('bob', 'bob@example.com');
const admin = () => user('owner', ADMIN);

const freshFree = (email) => ({
  email,
  plan: 'free',
  premiumUntil: null,
  usageDate: null,
  usageCount: 0,
  createdAt: serverTimestamp(),
});

async function seed(uid, data) {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users', uid), data),
  );
}

const freeAlice = {
  email: 'alice@example.com',
  plan: 'free',
  premiumUntil: null,
  usageDate: '2026-10-22',
  usageCount: 1,
  createdAt: Timestamp.now(),
};

test('sign-up may create only a Free record for yourself', async () => {
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice'), freshFree('alice@example.com')),
  );
});

test('nobody can sign up as Premium', async () => {
  await assertFails(
    setDoc(doc(alice(), 'users/alice'), {
      ...freshFree('alice@example.com'),
      plan: 'lifetime',
    }),
  );
});

test('you cannot create a record for someone else', async () => {
  await assertFails(
    setDoc(doc(alice(), 'users/bob'), freshFree('bob@example.com')),
  );
});

test('the email must be your own', async () => {
  await assertFails(
    setDoc(doc(alice(), 'users/alice'), freshFree('other@example.com')),
  );
});

test('signed-out visitors can read nothing', async () => {
  await seed('alice', freeAlice);
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
});

test('users read only their own record', async () => {
  await seed('alice', freeAlice);
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
  await assertFails(getDoc(doc(bob(), 'users/alice')));
});

test('users cannot list everyone', async () => {
  await seed('alice', freeAlice);
  await assertFails(getDocs(collection(alice(), 'users')));
});

test('users can count exactly one more playlist today', async () => {
  await seed('alice', freeAlice);
  await assertSucceeds(
    updateDoc(doc(alice(), 'users/alice'), { usageDate: '2026-10-22', usageCount: 2 }),
  );
});

test('users cannot reset or jump their count', async () => {
  await seed('alice', freeAlice);
  await assertFails(
    updateDoc(doc(alice(), 'users/alice'), { usageDate: '2026-10-22', usageCount: 0 }),
  );
  await assertFails(
    updateDoc(doc(alice(), 'users/alice'), { usageDate: '2026-10-22', usageCount: 5 }),
  );
});

test('a new day starts again at one', async () => {
  await seed('alice', freeAlice);
  await assertSucceeds(
    updateDoc(doc(alice(), 'users/alice'), { usageDate: '2026-10-23', usageCount: 1 }),
  );
});

test('users can never give themselves Premium', async () => {
  await seed('alice', freeAlice);
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { plan: 'lifetime' }));
  await assertFails(
    updateDoc(doc(alice(), 'users/alice'), {
      premiumUntil: Timestamp.fromDate(new Date('2099-01-01')),
    }),
  );
});

test('the admin can list users and change plans', async () => {
  await seed('alice', freeAlice);
  await assertSucceeds(getDocs(collection(admin(), 'users')));
  await assertSucceeds(
    updateDoc(doc(admin(), 'users/alice'), {
      plan: 'yearly',
      premiumUntil: Timestamp.fromDate(new Date('2027-10-22')),
    }),
  );
});

test('an unverified admin email gets no admin powers', async () => {
  await seed('alice', freeAlice);
  const fake = user('impostor', ADMIN, false);
  await assertFails(getDocs(collection(fake, 'users')));
  await assertFails(updateDoc(doc(fake, 'users/alice'), { plan: 'lifetime' }));
});

test('users can delete their own account, not others', async () => {
  await seed('alice', freeAlice);
  await seed('bob', { ...freeAlice, email: 'bob@example.com' });
  await assertFails(deleteDoc(doc(alice(), 'users/bob')));
  await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
});

test('users can save the day they opened the app, nothing else with it', async () => {
  await seed('alice', freeAlice);
  await assertSucceeds(
    updateDoc(doc(alice(), 'users/alice'), { lastOpened: '2026-10-23' }),
  );
  await assertFails(
    updateDoc(doc(alice(), 'users/alice'), {
      lastOpened: '2026-10-24',
      plan: 'lifetime',
    }),
  );
  await assertFails(
    updateDoc(doc(alice(), 'users/alice'), { lastOpened: 'yesterday at 9pm' }),
  );
});

test('only the admin can read and write payments and marketing', async () => {
  const sale = { uid: 'alice', email: 'alice@example.com', plan: 'yearly',
    usd: 39.99, thb: 1390, at: serverTimestamp() };
  await assertFails(setDoc(doc(alice(), 'payments/p1'), sale));
  await assertFails(getDocs(collection(alice(), 'payments')));
  await assertFails(setDoc(doc(alice(), 'marketing/2026-10-19'), { leads: 5 }));
  await assertSucceeds(setDoc(doc(admin(), 'payments/p1'), sale));
  await assertSucceeds(getDocs(collection(admin(), 'payments')));
  await assertSucceeds(setDoc(doc(admin(), 'marketing/2026-10-19'), { leads: 5 }));
  await assertSucceeds(getDocs(collection(admin(), 'marketing')));
  const fake = user('impostor', ADMIN, false);
  await assertFails(getDocs(collection(fake, 'payments')));
});

test('other collections are closed', async () => {
  await assertFails(setDoc(doc(alice(), 'secrets/x'), { amount: 1 }));
  await assertFails(getDocs(collection(admin(), 'secrets')));
});
