// Run: cd tests/rules && npm install && npm test   (needs Java for the emulator)
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, addDoc, collection, serverTimestamp,
} = require('firebase/firestore');

const PATIENT = 'patientUid1';
const DOCTOR = 'doctorUid1';
const OTHER = 'strangerUid1';
const CHAT = [PATIENT, DOCTOR].sort().join('_');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-medbridge',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', PATIENT), { role: 'patient' });
    await setDoc(doc(db, 'users', DOCTOR), { role: 'doctor' });
    await setDoc(doc(db, 'users', OTHER), { role: 'patient' });
  });
});

const dbOf = (uid) => env.authenticatedContext(uid).firestore();
const [P0, P1] = [PATIENT, DOCTOR].sort();
const newChat = () => ({
  participants: [P0, P1], patientId: PATIENT, doctorId: DOCTOR,
  participantNames: { [PATIENT]: 'P', [DOCTOR]: 'D' },
  lastMessage: '', lastSenderId: '', lastTimestamp: serverTimestamp(),
  unreadCounts: { [PATIENT]: 0, [DOCTOR]: 0 },
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const msg = (sender, recipient, extra = {}) => ({
  senderId: sender, senderName: 'n', recipientId: recipient, text: 'hello',
  timestamp: serverTimestamp(), isRead: false, ...extra,
});
async function seedChat() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chats', CHAT), {
      participants: [P0, P1], patientId: PATIENT, doctorId: DOCTOR,
      lastMessage: 'x', unreadCounts: {},
    });
  });
}

test('patient can initialize a new chat', async () => {
  await assertSucceeds(setDoc(doc(dbOf(PATIENT), 'chats', CHAT), newChat()));
});
test('doctor can initialize a new chat', async () => {
  await assertSucceeds(setDoc(doc(dbOf(DOCTOR), 'chats', CHAT), newChat()));
});
test('stranger cannot create a chat for others', async () => {
  await assertFails(setDoc(doc(dbOf(OTHER), 'chats', CHAT), newChat()));
});
test('mismatched chat id is denied', async () => {
  await assertFails(setDoc(doc(dbOf(PATIENT), 'chats', 'bogus'), newChat()));
});
test('two patients cannot start a chat', async () => {
  const ids = [PATIENT, OTHER].sort();
  await assertFails(setDoc(doc(dbOf(PATIENT), 'chats', ids.join('_')), {
    ...newChat(), participants: ids, patientId: PATIENT, doctorId: OTHER,
  }));
});
test('both participants read; stranger cannot', async () => {
  await seedChat();
  await assertSucceeds(getDoc(doc(dbOf(PATIENT), 'chats', CHAT)));
  await assertSucceeds(getDoc(doc(dbOf(DOCTOR), 'chats', CHAT)));
  await assertFails(getDoc(doc(dbOf(OTHER), 'chats', CHAT)));
});
test('patient sends, doctor replies', async () => {
  await seedChat();
  await assertSucceeds(addDoc(collection(dbOf(PATIENT), 'chats', CHAT, 'messages'), msg(PATIENT, DOCTOR)));
  await assertSucceeds(addDoc(collection(dbOf(DOCTOR), 'chats', CHAT, 'messages'), msg(DOCTOR, PATIENT)));
});
test('forged sender is denied', async () => {
  await seedChat();
  await assertFails(addDoc(collection(dbOf(PATIENT), 'chats', CHAT, 'messages'), msg(DOCTOR, PATIENT)));
});
test('stranger cannot read or send messages', async () => {
  await seedChat();
  await assertFails(addDoc(collection(dbOf(OTHER), 'chats', CHAT, 'messages'), msg(OTHER, DOCTOR)));
  await assertFails(getDoc(doc(dbOf(OTHER), 'chats', CHAT, 'messages', 'x')));
});
test('message before chat exists is denied', async () => {
  await assertFails(addDoc(collection(dbOf(PATIENT), 'chats', CHAT, 'messages'), msg(PATIENT, DOCTOR)));
});
test('participants cannot be changed by an update', async () => {
  await seedChat();
  await assertFails(updateDoc(doc(dbOf(PATIENT), 'chats', CHAT), { participants: [PATIENT, OTHER] }));
  await assertFails(updateDoc(doc(dbOf(OTHER), 'chats', CHAT), { lastMessage: 'hi' }));
  await assertSucceeds(updateDoc(doc(dbOf(PATIENT), 'chats', CHAT), { lastMessage: 'hi' }));
});
test('only recipient can mark read', async () => {
  await seedChat();
  const ref = doc(dbOf(PATIENT), 'chats', CHAT, 'messages', 'm1');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chats', CHAT, 'messages', 'm1'), msg(PATIENT, DOCTOR, { timestamp: new Date() }));
  });
  await assertFails(updateDoc(ref, { isRead: true }));
  await assertSucceeds(updateDoc(doc(dbOf(DOCTOR), 'chats', CHAT, 'messages', 'm1'), { isRead: true }));
});
