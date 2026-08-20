// كتابة التحديثات اليومية والمهام والمخاطر والعوائق — من يملكها فعلاً.
//
// حارس عطلٍ حقيقي: منذ أن صار للمشروع أكثر من مدير، كانت الكتابة تُفحص
// بحقل managerUid المفرد — وهو أوّل اسم في القائمة وحده. فالمدير الثاني
// والمنفّذ المُسنَد ممنوعان من كتابة تحديث على مشروعهما، والقراءة تعرف
// عضويتهما. وهذا يُبطل ميزة «التقرير اليومي» من أساسها لمن ليس أوّل مدير.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, setDoc } from 'firebase/firestore';

const DEPT = 'd-justice';
const OTHER = 'd-other';
const FIRST = 'u-first';
const SECOND = 'u-second';
const EXECUTOR = 'u-exec';
const STRANGER = 'u-stranger';
const HEAD = 'u-head';

let env;

function claims(uid, { role = 'projectOfficer', dept = DEPT, depts = [] } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: depts, perms: { sfb: true } };
}

/** تحديث يومي كما يكتبه التطبيق: يحمل نسخة من إدارة المشروع ومديره الأول. */
function update(extra = {}) {
  return {
    projectId: 'p1',
    departmentId: DEPT,
    managerUid: FIRST,
    authorUid: SECOND,
    authorName: 'المدير الثاني',
    date: new Date('2026-08-20'),
    achievements: 'أُنجز كذا',
    completedTasks: [],
    newRisks: [],
    blockers: ['عائق اليوم'],
    decisionsRequired: [],
    notes: 'ملاحظة',
    attachments: [],
    progressPercent: 40,
    ...extra,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-daily',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'projects/p1'), {
      departmentId: DEPT,
      name: 'مشروع',
      dueDate: new Date('2026-12-31'),
      createdByUid: 'admin',
      managerUids: [FIRST, SECOND],
      executorUids: [EXECUTOR],
      managerUid: FIRST,
    });
  });
});

after(async () => { await env?.cleanup(); });

describe('من يكتب التحديث اليومي', () => {
  test('المدير الأول — يُقبل (وكان يعمل أصلاً)', async () => {
    const db = env.authenticatedContext(FIRST, claims(FIRST)).firestore();
    await assertSucceeds(addDoc(collection(db, 'dailyUpdates'), update({ authorUid: FIRST })));
  });

  // جوهر العطل: عضوٌ في القائمة وليس أوّلها.
  test('المدير الثاني — يُقبل', async () => {
    const db = env.authenticatedContext(SECOND, claims(SECOND)).firestore();
    await assertSucceeds(addDoc(collection(db, 'dailyUpdates'), update()));
  });

  test('والمنفّذ المُسنَد — يُقبل', async () => {
    const db = env.authenticatedContext(EXECUTOR, claims(EXECUTOR, { role: 'employee' })).firestore();
    await assertSucceeds(addDoc(collection(db, 'dailyUpdates'), update({ authorUid: EXECUTOR })));
  });

  test('ومدير الإدارة — يُقبل', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT] }))
      .firestore();
    await assertSucceeds(addDoc(collection(db, 'dailyUpdates'), update({ authorUid: HEAD })));
  });

  test('وموظف في الإدارة ليس عضواً — يُرفض', async () => {
    const db = env.authenticatedContext(STRANGER, claims(STRANGER, { role: 'employee' })).firestore();
    await assertFails(addDoc(collection(db, 'dailyUpdates'), update({ authorUid: STRANGER })));
  });

  test('ومن خارج الإدارة — يُرفض', async () => {
    const db = env
      .authenticatedContext(STRANGER, claims(STRANGER, { role: 'employee', dept: OTHER }))
      .firestore();
    await assertFails(addDoc(collection(db, 'dailyUpdates'), update({ authorUid: STRANGER })));
  });

  // الحقول المنسوخة تبقى مفحوصة: لا ينتحل أحد مشروعاً ليس فيه.
  test('وعضوٌ ينسخ إدارةً غير إدارة المشروع — يُرفض', async () => {
    const db = env.authenticatedContext(SECOND, claims(SECOND)).firestore();
    await assertFails(addDoc(collection(db, 'dailyUpdates'), update({ departmentId: OTHER })));
  });
});

describe('والعوائق والمخاطر والمهام كذلك', () => {
  const child = (extra = {}) => ({
    projectId: 'p1',
    departmentId: DEPT,
    managerUid: FIRST,
    title: 'عائق',
    description: '',
    createdAt: new Date('2026-08-20'),
    ...extra,
  });

  test('المدير الثاني يسجّل عائقاً', async () => {
    const db = env.authenticatedContext(SECOND, claims(SECOND)).firestore();
    await assertSucceeds(addDoc(collection(db, 'blockers'), child()));
  });

  test('ويسجّل خطراً', async () => {
    const db = env.authenticatedContext(SECOND, claims(SECOND)).firestore();
    await assertSucceeds(addDoc(collection(db, 'risks'), child({ severity: 'medium' })));
  });

  test('ومن ليس عضواً لا يسجّل', async () => {
    const db = env.authenticatedContext(STRANGER, claims(STRANGER, { role: 'employee' })).firestore();
    await assertFails(addDoc(collection(db, 'blockers'), child()));
  });
});
