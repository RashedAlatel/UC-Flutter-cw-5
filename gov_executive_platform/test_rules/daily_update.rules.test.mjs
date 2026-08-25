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
import { addDoc, collection, deleteDoc, doc, setDoc, updateDoc } from 'firebase/firestore';

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

// ــــــــــــــــــــ حذف التحديث اليومي ــــــــــــــــــــ
//
// كان الحذف لمسؤول النظام وحده، فمن كتب تحديثاً بالخطأ لا سبيل له إلى
// محوه — وهذا ما طُلب فتحه. وفُتح لطرفين لا أكثر: **كاتبُه**، و**مالك
// المشروع** (مسؤول النظام، ومدير الإدارة صاحبتِه، ومديرو المشروع).
//
// وما يُقاس هنا هو **حدُّ الفتح** لا الفتح نفسه: أن المنفّذ المُسنَد لا
// يمحو تحديث مديره، وأن الغريب لا يمحو شيئاً، وأن `update` بقيت مردودة
// على الجميع — فلا يُفتح التعديل سهواً في أثناء فتح الحذف.
describe('ومن يحذف التحديث اليومي', () => {
  let seq = 0;

  /// يزرع تحديثاً خارج القواعد ويعيد مرجعه — بمعرّف جديد لكل اختبار.
  async function seedUpdate(extra = {}) {
    const id = `del-${++seq}`;
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `dailyUpdates/${id}`), {
        ...update(extra),
        // المنسوخ كما يكتبه العميل فعلاً: القائمة مع المفرد.
        managerUids: [FIRST, SECOND],
      });
    });
    return id;
  }

  test('كاتبُه يحذف ما كتبه', async () => {
    const id = await seedUpdate({ authorUid: EXECUTOR });
    const db = env.authenticatedContext(EXECUTOR, claims(EXECUTOR, { role: 'employee' })).firestore();
    await assertSucceeds(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  test('والمدير الأول يحذف ولو لم يكتبه', async () => {
    const id = await seedUpdate({ authorUid: SECOND });
    const db = env.authenticatedContext(FIRST, claims(FIRST)).firestore();
    await assertSucceeds(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  // نظير عطل الاشتراك: القائمة لا المفرد. ولولا هذا لَكان المدير الثاني
  // يكتب ولا يحذف على مشروعٍ يقوده.
  test('والمدير الثاني كذلك — القائمة لا المفرد', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const db = env.authenticatedContext(SECOND, claims(SECOND)).firestore();
    await assertSucceeds(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  test('ومدير الإدارة صاحبتِه', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT] }))
      .firestore();
    await assertSucceeds(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  // ــ وهنا حدُّ الفتح ــ
  //
  // المنفّذ **يكتب** التحديث اليومي (مُقاسٌ أعلاه)، ولا يحذف تحديث غيره:
  // العضوية تنفيذاً ليست ملكاً. ولو استُعملت `isProjectMember` في القاعدة
  // لَمرّ هذا.
  test('ولا يحذف المنفّذُ تحديثَ مديره', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const db = env.authenticatedContext(EXECUTOR, claims(EXECUTOR, { role: 'employee' })).firestore();
    await assertFails(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  test('ولا موظفٌ في الإدارة ليس عضواً', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const db = env.authenticatedContext(STRANGER, claims(STRANGER, { role: 'employee' })).firestore();
    await assertFails(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  test('ولا مديرُ إدارةٍ أخرى', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const db = env
      .authenticatedContext(STRANGER, claims(STRANGER, { role: 'departmentManager', dept: OTHER, depts: [OTHER] }))
      .firestore();
    await assertFails(deleteDoc(doc(db, `dailyUpdates/${id}`)));
  });

  // السجل أثرٌ لا يُنقّح بأثر رجعي: التصحيح حذفٌ مُسجَّل ثم إضافةٌ جديدة.
  test('والتعديل يبقى مردوداً — حتى على كاتبه ومالك المشروع', async () => {
    const id = await seedUpdate({ authorUid: FIRST });
    const owner = env.authenticatedContext(FIRST, claims(FIRST)).firestore();
    await assertFails(updateDoc(doc(owner, `dailyUpdates/${id}`), { achievements: 'نصٌّ آخر' }));

    const author = env.authenticatedContext(EXECUTOR, claims(EXECUTOR, { role: 'employee' })).firestore();
    await assertFails(updateDoc(doc(author, `dailyUpdates/${id}`), { achievements: 'نصٌّ آخر' }));
  });
});
