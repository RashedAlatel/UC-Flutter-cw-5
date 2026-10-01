// دورة الإغلاق على مرحلتين — على الخادم لا في الواجهة.
//
// ــــ ما الذي لا تكشفه القراءة؟ ــــ
//
// أن إخفاء «منجزة» من قائمة الحالة ليس منعاً. من فتح أدوات المطوّر كتب
// `status: 'done'` على العمل فأغلقه، ولا شيء بين يده وبين المستند. وهذه
// الملفّات وحدها تُثبت أن الإغلاق صار قرار طالب العمل فعلاً.
//
// وثلاث حالاتٍ يجب أن تبقى مقبولة وإلا تعطّلت المنصة على بيانات قائمة:
// الإفادة بالإتمام، وكتابةُ التقدّم اليومي، وعملٌ بلا معتمِد أصلاً.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

const DEPT = 'd-justice';
const ADMIN = 'u-admin';
const REQUESTER = 'u-requester';
const WORKER = 'u-worker';
const HEAD = 'u-head';

let env;

function claims(uid, { role = 'employee', dept = DEPT, depts = [], perms = {} } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: depts, perms };
}

/** المنفّذ: مُسنَدٌ إليه العمل، ويملك إدارة الأعمال في إدارته. */
function workerDb() {
  return env
    .authenticatedContext(WORKER, claims(WORKER, { role: 'projectOfficer', perms: { mw: true } }))
    .firestore();
}

function requesterDb() {
  return env
    .authenticatedContext(REQUESTER, claims(REQUESTER, { role: 'departmentManager', depts: [DEPT], perms: { mw: true } }))
    .firestore();
}

function work(extra = {}) {
  return {
    title: 'جرد المستودع',
    departmentId: DEPT,
    assigneeUid: WORKER,
    assigneeName: 'المنفّذ',
    status: 'inProgress',
    priority: 'medium',
    progressPercent: 60,
    dueDate: new Date('2026-12-31'),
    createdByUid: REQUESTER,
    createdAt: new Date('2026-01-01'),
    ...extra,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-closure',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const person = (id, role) => setDoc(doc(db, `users/${id}`), {
      name: `صاحب ${role}`, role, departmentId: DEPT, departmentIds: [DEPT], status: 'approved',
    });
    await person(ADMIN, 'systemAdmin');
    await person(REQUESTER, 'departmentManager');
    await person(WORKER, 'projectOfficer');
    await person(HEAD, 'departmentManager');

    // عملٌ له معتمِد — وهو موضوع كل ما يلي.
    await setDoc(doc(db, 'works/gated'), work({
      closure: { approverUid: REQUESTER, approverName: 'الطالب' },
    }));
    // وثالثٌ للتقدّم اليومي وحده — مستقلٌّ عن الأول عمداً: اختبارٌ يعتمد على
    // ترتيب سابقيه يصير هشّاً، ويكذب حين يُنقل.
    await setDoc(doc(db, 'works/progress'), work({
      closure: { approverUid: REQUESTER, approverName: 'الطالب' },
    }));
    // وعملٌ بلا معتمِد: حالُ كل ما كُتب قبل هذه الدورة.
    await setDoc(doc(db, 'works/legacy'), work());
    // ومهمّة مشروع لها معتمِد.
    await setDoc(doc(db, 'projects/p1'), {
      name: 'الأرشفة', departmentId: DEPT, managerUids: [REQUESTER], managerUid: REQUESTER,
      dueDate: new Date('2026-12-31'), createdByUid: REQUESTER,
    });
    await setDoc(doc(db, 'tasks/gated'), {
      projectId: 'p1', departmentId: DEPT, managerUid: REQUESTER,
      title: 'مهمة', assigneeUid: WORKER, assigneeName: 'المنفّذ',
      status: 'inProgress', progressPercent: 40,
      lastUpdated: new Date('2026-08-01'), dueDate: new Date('2026-12-31'), priority: 'medium',
      createdByUid: REQUESTER,
      closure: { approverUid: REQUESTER, approverName: 'الطالب' },
    });
  });
});

after(async () => { await env?.cleanup(); });

describe('الأعمال: من يُغلق', () => {
  test('المنفّذ يُفيد بالإتمام (awaitingApproval) — يُقبل', async () => {
    await assertSucceeds(updateDoc(doc(workerDb(), 'works/gated'), {
      status: 'awaitingApproval',
      progressPercent: 100,
      closure: { approverUid: REQUESTER, approverName: 'الطالب', claimedByUid: WORKER },
    }));
  });

  test('والمنفّذ يكتب done بنفسه — يُرفض', async () => {
    await assertFails(updateDoc(doc(workerDb(), 'works/gated'), { status: 'done' }));
  });

  test('ومدير الإدارة الذي ليس المعتمِد — يُرفض كذلك', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT], perms: { mw: true } }))
      .firestore();
    await assertFails(updateDoc(doc(db, 'works/gated'), { status: 'done' }));
  });

  test('والمعتمِد يكتب done — يُقبل', async () => {
    await assertSucceeds(updateDoc(doc(requesterDb(), 'works/gated'), { status: 'done' }));
  });

  test('ومسؤول النظام يُغلق دائماً', async () => {
    const db = env.authenticatedContext(ADMIN, claims(ADMIN, { role: 'systemAdmin' })).firestore();
    await assertSucceeds(updateDoc(doc(db, 'works/gated'), { status: 'done' }));
  });

  test('وكتابة التقدّم بلا إغلاق — تبقى مقبولة', async () => {
    await assertSucceeds(updateDoc(doc(workerDb(), 'works/progress'), { progressPercent: 80 }));
  });

  // وبعد الإغلاق لا يعبث به المنفّذ: الحالة تبقى `done` في أي تعديل لاحق،
  // فتُفحص القاعدة من جديد وتردّه. وهذا **أثرٌ مقصود** لا عرَض: عملٌ اعتُمد
  // إغلاقه لا يُحرّكه طرفٌ واحد بعد اعتماده.
  test('وبعد الإغلاق لا يعدّله المنفّذ', async () => {
    await assertFails(updateDoc(doc(workerDb(), 'works/gated'), { progressPercent: 95 }));
  });
});

describe('العودة إلى الخلف: عملٌ بلا معتمِد', () => {
  test('يُغلقه من يملك تعديله كما كانت المنصة', async () => {
    await assertSucceeds(updateDoc(doc(workerDb(), 'works/legacy'), { status: 'done' }));
  });
});

describe('مهام المشروع', () => {
  test('المُسنَد إليه يُفيد بالإتمام — يُقبل (لم يكن يستطيع تحريكها أصلاً)', async () => {
    await assertSucceeds(updateDoc(doc(workerDb(), 'tasks/gated'), {
      status: 'awaitingApproval',
      progressPercent: 100,
      closure: { approverUid: REQUESTER, approverName: 'الطالب', claimedByUid: WORKER },
      lastUpdated: new Date(),
    }));
  });

  test('ويكتب done بنفسه — يُرفض', async () => {
    await assertFails(updateDoc(doc(workerDb(), 'tasks/gated'), {
      status: 'done',
      lastUpdated: new Date(),
    }));
  });

  test('ولا يُعيد إسناد مهمته إلى غيره — التوسيع أضيق من ذلك', async () => {
    await assertFails(updateDoc(doc(workerDb(), 'tasks/gated'), { assigneeUid: HEAD }));
  });

  test('والمعتمِد يُغلقها', async () => {
    await assertSucceeds(updateDoc(doc(requesterDb(), 'tasks/gated'), {
      status: 'done',
      lastUpdated: new Date(),
    }));
  });
});
