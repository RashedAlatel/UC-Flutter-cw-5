// رتبة الإسناد على الخادم — لا في الواجهة وحدها.
//
// ــــ ما الذي لا تكشفه القراءة هنا؟ ــــ
//
// أن التصفية كانت **في المتصفح فقط**. فمن فتح أدوات المطوّر كتب مستنداً
// يُسنِد عملاً إلى المسؤول التنفيذي ولا شيء يمنعه على الخادم. وهذه الملفّات
// وحدها تُثبت أن المنع صار حقيقياً.
//
// وقائمتا فريق المشروع لا تُفحصان هنا عمداً: لغة القواعد بلا حلقات، فالفحص
// في دالّة `setProjectTeam`. والذي يُفحص هنا أن القاعدة **لا تسمح** بكتابة
// العضوية مباشرةً لغير مسؤول النظام ولا لغير صاحبها على نفسه.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, setDoc, updateDoc } from 'firebase/firestore';

const DEPT = 'd-justice';
const ADMIN = 'u-admin';
const EXEC = 'u-exec';
const HEAD = 'u-head';
const OFFICER = 'u-officer';
const EMPLOYEE = 'u-employee';
const PEER = 'u-peer';

let env;

function claims(uid, { role = 'employee', dept = DEPT, depts = [], perms = {}, scopes = {} } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: depts, perms, scopes };
}

function work(extra = {}) {
  return {
    title: 'جرد المستودع',
    description: '',
    departmentId: DEPT,
    assigneeUid: EMPLOYEE,
    assigneeName: 'موظف',
    status: 'todo',
    priority: 'medium',
    progressPercent: 0,
    dueDate: new Date('2026-12-31'),
    completedDate: null,
    createdByUid: OFFICER,
    createdAt: new Date('2026-08-01'),
    ...extra,
  };
}

/** مدير مشروع يملك «إدارة الأعمال» في إدارته — أدنى من يستطيع الإنشاء. */
function officerDb() {
  return env
    .authenticatedContext(OFFICER, claims(OFFICER, { role: 'projectOfficer', perms: { mw: true } }))
    .firestore();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-assignment',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const person = (id, role) => setDoc(doc(db, `users/${id}`), {
      name: `صاحب ${role}`,
      email: `${id}@moj.gov.kw`,
      role,
      departmentId: DEPT,
      departmentIds: [DEPT],
      status: 'approved',
    });
    await person(ADMIN, 'systemAdmin');
    await person(EXEC, 'executiveViewer');
    await person(HEAD, 'departmentManager');
    await person(OFFICER, 'projectOfficer');
    await person(PEER, 'projectOfficer');
    await person(EMPLOYEE, 'employee');

    // عملٌ قائم لاختبار التعديل وإعادة الإسناد.
    await setDoc(doc(db, 'works/w1'), work());
    // مشروعٌ قائم لاختبار كتابة العضوية.
    await setDoc(doc(db, 'projects/p1'), {
      name: 'الأرشفة',
      departmentId: DEPT,
      managerUids: [OFFICER],
      executorUids: [],
      managerUid: OFFICER,
      dueDate: new Date('2026-12-31'),
      createdByUid: HEAD,
    });
  });
});

after(async () => { await env?.cleanup(); });

describe('إنشاء عمل: رتبة المُسنَد إليه', () => {
  test('مدير مشروع يُسنِد إلى موظف — يُقبل', async () => {
    await assertSucceeds(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: EMPLOYEE })));
  });

  test('ويُسنِد إلى نظيره مدير مشروع — يُقبل (المساواة مسموحة)', async () => {
    await assertSucceeds(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: PEER })));
  });

  test('ويُسنِد إلى نفسه — يُقبل', async () => {
    await assertSucceeds(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: OFFICER })));
  });

  test('ويُسنِد إلى مدير الإدارة — يُرفض', async () => {
    await assertFails(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: HEAD })));
  });

  test('ويُسنِد إلى المسؤول التنفيذي — يُرفض', async () => {
    await assertFails(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: EXEC })));
  });

  test('وعملٌ بلا مسؤول — يُقبل: تأجيل الإسناد حالةٌ مشروعة', async () => {
    await assertSucceeds(addDoc(collection(officerDb(), 'works'), work({ assigneeUid: '' })));
  });

  test('ومسؤول النظام يُسنِد إلى المسؤول التنفيذي — يُقبل', async () => {
    const db = env.authenticatedContext(ADMIN, claims(ADMIN, { role: 'systemAdmin' })).firestore();
    await assertSucceeds(addDoc(collection(db, 'works'), work({ assigneeUid: EXEC })));
  });
});

describe('تعديل عمل', () => {
  test('تغيير نسبة الإنجاز بلا تغيير المسؤول — يُقبل بلا فحص رتبة', async () => {
    await assertSucceeds(updateDoc(doc(officerDb(), 'works/w1'), { progressPercent: 60 }));
  });

  test('وإعادة الإسناد إلى مدير الإدارة — يُرفض', async () => {
    await assertFails(updateDoc(doc(officerDb(), 'works/w1'), { assigneeUid: HEAD }));
  });

  test('وإعادة الإسناد إلى موظف — يُقبل', async () => {
    await assertSucceeds(updateDoc(doc(officerDb(), 'works/w1'), { assigneeUid: EMPLOYEE }));
  });
});

describe('عضوية المشروع لم تعد تُكتب من العميل', () => {
  test('مدير الإدارة يكتب الفريق مباشرةً — يُرفض (الطريق دالّة setProjectTeam)', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT] }))
      .firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [OFFICER],
      executorUids: [EXEC],
      managerUid: OFFICER,
    }));
  });

  test('وصاحب mpr يُنشئ مشروعاً بفريقٍ فيه غيره — يُرفض', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, {
        role: 'departmentManager',
        depts: [DEPT],
        perms: { mpr: true },
        scopes: { mpr: [DEPT] },
      }))
      .firestore();
    await assertFails(addDoc(collection(db, 'projects'), {
      name: 'مشروع جديد',
      departmentId: DEPT,
      managerUids: [OFFICER],
      executorUids: [],
      managerUid: OFFICER,
      dueDate: new Date('2026-12-31'),
      createdByUid: HEAD,
    }));
  });

  test('ويُنشئه بعضويةٍ ذاتية — يُقبل', async () => {
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, {
        role: 'departmentManager',
        depts: [DEPT],
        perms: { mpr: true },
        scopes: { mpr: [DEPT] },
      }))
      .firestore();
    await assertSucceeds(addDoc(collection(db, 'projects'), {
      name: 'مشروع جديد',
      departmentId: DEPT,
      managerUids: [HEAD],
      executorUids: [HEAD],
      managerUid: HEAD,
      dueDate: new Date('2026-12-31'),
      createdByUid: HEAD,
    }));
  });

  test('ومسؤول النظام يكتب الفريق مباشرةً — يُقبل', async () => {
    const db = env.authenticatedContext(ADMIN, claims(ADMIN, { role: 'systemAdmin' })).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [OFFICER, EXEC],
      executorUids: [],
      managerUid: OFFICER,
    }));
  });
});
