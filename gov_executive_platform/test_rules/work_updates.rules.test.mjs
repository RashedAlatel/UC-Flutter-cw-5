// تحديثات الأعمال اليومية — من يكتبها ومن يقرأها.
//
// مجموعةٌ جديدة، وقاعدةٌ جديدة. وأخطر ما فيها **شرط المطابقة**: بغيره يكتب
// الموظف مستنداً يزعم فيه أنه المُسنَد إليه عملاً ليس له، ثم يقرأه بقاعدة
// القراءة نفسها — فيصير سجل عملٍ في إدارةٍ أخرى مفتوحاً له. وهو التفافٌ
// كامل على النطاق، ولا يكشفه إلا اختبارٌ يحاول فعله.
//
// وقاعدة `dailyUpdates` لا تُمسّ: هذه المجموعة قائمة بذاتها على نسق `works`.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const DEPT = 'd-justice';
const OTHER = 'd-other';
const ASSIGNEE = 'u-assignee';
const HEAD = 'u-head';
const STRANGER = 'u-stranger';
const OUTSIDER = 'u-outsider';

let env;

function claims(uid, { role = 'employee', dept = DEPT, depts = [], perms = {} } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: depts, perms };
}

/** تحديث عمل كما يكتبه التطبيق: ينسخ إدارة العمل والمُسنَد إليه. */
function update(extra = {}) {
  return {
    workId: 'w1',
    departmentId: DEPT,
    assigneeUid: ASSIGNEE,
    authorUid: ASSIGNEE,
    authorName: 'المسؤول',
    date: new Date('2026-08-20'),
    summary: 'أُنجز كذا',
    notes: '',
    progressPercent: 40,
    attachments: [],
    ...extra,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-work-updates',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    // `ctx.firestore()` مرةً واحدة: نداؤها ثانيةً يعيد ضبط الإعدادات على
    // كائنٍ بدأ العمل، فيسقط الخطّاف كلّه ويُلغى كل اختبار في الملف.
    const db = ctx.firestore();
    await setDoc(doc(db, 'works/w1'), {
      title: 'جرد المستودع',
      departmentId: DEPT,
      assigneeUid: ASSIGNEE,
      assigneeName: 'المسؤول',
      status: 'inProgress',
      progressPercent: 20,
      dueDate: new Date('2026-12-31'),
      createdByUid: HEAD,
    });
    // تحديثٌ قائم لاختبار القراءة والتعديل.
    await setDoc(doc(db, 'workUpdates/existing'), update());
  });
});

after(async () => { await env?.cleanup(); });

describe('من يكتب تحديث العمل', () => {
  test('المُسنَد إليه — يُقبل', async () => {
    const db = env.authenticatedContext(ASSIGNEE, claims(ASSIGNEE)).firestore();
    await assertSucceeds(addDoc(collection(db, 'workUpdates'), update()));
  });

  test('ومدير الإدارة صاحب صلاحية إدارة الأعمال — يُقبل', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, {
        role: 'departmentManager',
        depts: [DEPT],
        perms: { mw: true },
      }))
      .firestore();
    await assertSucceeds(addDoc(collection(db, 'workUpdates'), update({ authorUid: HEAD })));
  });

  test('وموظفٌ في الإدارة ليس مسؤولاً عن العمل — يُرفض', async () => {
    const db = env.authenticatedContext(STRANGER, claims(STRANGER)).firestore();
    await assertFails(
      addDoc(collection(db, 'workUpdates'), update({ authorUid: STRANGER, assigneeUid: STRANGER })),
    );
  });

  test('ومن خارج الإدارة — يُرفض', async () => {
    const db = env.authenticatedContext(OUTSIDER, claims(OUTSIDER, { dept: OTHER })).firestore();
    await assertFails(addDoc(collection(db, 'workUpdates'), update({ authorUid: OUTSIDER })));
  });

  // ــ جوهر الأمان هنا ــ
  // الحقول منسوخة على المستند، فلو لم تُطابَق بالعمل الحقيقي لكتب أي موظف
  // مستنداً يجعل نفسه «المُسنَد إليه» ثم قرأه.
  test('ومن ينتحل إسناداً ليس له — يُرفض', async () => {
    const db = env.authenticatedContext(STRANGER, claims(STRANGER)).firestore();
    await assertFails(
      addDoc(collection(db, 'workUpdates'), update({ authorUid: STRANGER, assigneeUid: STRANGER })),
    );
  });

  test('ومن ينسخ إدارةً غير إدارة العمل — يُرفض', async () => {
    const db = env.authenticatedContext(ASSIGNEE, claims(ASSIGNEE)).firestore();
    await assertFails(addDoc(collection(db, 'workUpdates'), update({ departmentId: OTHER })));
  });

  test('وتحديثٌ لعملٍ لا وجود له — يُرفض', async () => {
    const db = env.authenticatedContext(ASSIGNEE, claims(ASSIGNEE)).firestore();
    await assertFails(addDoc(collection(db, 'workUpdates'), update({ workId: 'ghost' })));
  });
});

describe('من يقرأ تحديث العمل', () => {
  test('المُسنَد إليه — يُقبل', async () => {
    const db = env.authenticatedContext(ASSIGNEE, claims(ASSIGNEE)).firestore();
    await assertSucceeds(getDoc(doc(db, 'workUpdates/existing')));
  });

  test('ومدير الإدارة — يُقبل', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT] }))
      .firestore();
    await assertSucceeds(getDoc(doc(db, 'workUpdates/existing')));
  });

  test('وموظفٌ من إدارة أخرى — يُرفض', async () => {
    const db = env.authenticatedContext(OUTSIDER, claims(OUTSIDER, { dept: OTHER })).firestore();
    await assertFails(getDoc(doc(db, 'workUpdates/existing')));
  });
});

describe('السجل لا يُعدَّل', () => {
  test('حتى كاتبُه لا يعدّله', async () => {
    // كما في `dailyUpdates`: ما كُتب في السجل يبقى كما كُتب. ومن أخطأ يكتب
    // تحديثاً جديداً يصحّحه — فيبقى الأثر مقروءاً.
    const db = env.authenticatedContext(ASSIGNEE, claims(ASSIGNEE)).firestore();
    await assertFails(updateDoc(doc(db, 'workUpdates/existing'), { summary: 'تبديل' }));
  });
});
