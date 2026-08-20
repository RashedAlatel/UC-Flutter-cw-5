// اختبارات **نطاق الاستعلام** لا المستند المفرد.
//
// وهذا هو موضع العطل الذي أفرغ شاشة الموظف: قواعد Firestore **ترفض ولا
// تُصفّي**. فالمجموعة تُطلب بنطاق يضمن أن كل ما تعيده مسموح، وإلا رُفض
// الطلب كله — لا أن تعود المستندات المسموحة وحدها. واختبارُ مستندٍ مفرد
// ينجح بينما الاستعلام الذي يبنيه البرنامج يُرفض، فلا يكشف شيئاً.
//
// التشغيل: node --test scope.rules.test.mjs (ويلزم محاكي Firestore)
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

const DEPT = 'd-systems';
const OTHER_DEPT = 'd-other';
const ME = 'u-me';

let env;

/** موظف معتمد في إدارته — **بلا أي صلاحية ممنوحة**، وهو الحال الافتراضي. */
function employee({ dept = DEPT, perms = {} } = {}) {
  return { role: 'employee', approved: true, departmentId: dept, departmentIds: [], perms };
}

function manager({ depts = [DEPT] } = {}) {
  return {
    role: 'departmentManager', approved: true,
    departmentId: depts[0], departmentIds: depts, perms: { mw: true },
  };
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

async function seedAll() {
  await env.clearFirestore();
  await seed('projects/p-mine', {
    departmentId: DEPT, name: 'مشروع إدارتي', dueDate: new Date('2030-01-01'),
    createdByUid: 'admin', managerUids: [], executorUids: [], managerUid: null,
  });
  await seed('projects/p-other', {
    departmentId: OTHER_DEPT, name: 'مشروع إدارة أخرى', dueDate: new Date('2030-01-01'),
    createdByUid: 'admin', managerUids: [], executorUids: [], managerUid: null,
  });
  await seed('tasks/t-mine', { departmentId: DEPT, projectId: 'p-mine', managerUid: null, title: 'مهمة' });
  await seed('works/w-mine', { departmentId: DEPT, assigneeUid: ME, title: 'عملي' });
  await seed('works/w-other', { departmentId: OTHER_DEPT, assigneeUid: 'someone', title: 'عمل غيري' });
  await seed('approvalRequests/r-mine', {
    type: 'registration', status: 'pending', requestedByUid: ME, departmentId: DEPT, title: 'طلبي',
  });
  await seed('approvalRequests/r-other', {
    type: 'registration', status: 'pending', requestedByUid: 'someone', departmentId: OTHER_DEPT, title: 'طلب غيري',
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-scope',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});

after(async () => { await env?.cleanup(); });

describe('مشاريع الإدارة حقٌّ لا صلاحية', () => {
  // العطل بعينه: موظف معتمد في إدارة فيها مشاريع لم يرَ منها شيئاً، لأن
  // القراءة كانت معلَّقة على بصمة صلاحية في بطاقة دخوله.
  test('موظف بلا أي صلاحية يستعلم عن مشاريع إدارته — يُقبل', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'projects'), where('departmentId', '==', DEPT))));
  });

  test('والاستعلام نفسه عن إدارة أخرى — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'projects'), where('departmentId', '==', DEPT))));
    await assertFails(getDocs(query(collection(db, 'projects'), where('departmentId', '==', OTHER_DEPT))));
  });

  // توثيق المبدأ نفسه: الطلب المفتوح يُرفض كله ولو كان بعضه مسموحاً.
  test('طلب المشاريع كاملةً بلا نطاق — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertFails(getDocs(collection(db, 'projects')));
  });

  test('ومهام المشروع تتبع المشروع في القراءة', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'tasks'), where('departmentId', '==', DEPT))));
  });

  // الحدّ الذي لم يتحرّك: الاطّلاع صار حقاً، أما **تسجيل الموظف نفسه** على
  // المشروع فيبقى بصلاحية يمنحها مسؤول النظام ويسحبها متى شاء.
  test('لكن الانضمام بلا صلاحية — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p-mine'), {
      executorUids: [ME], managerUids: [], managerUid: null,
    }));
  });

  test('وبالصلاحية — يُقبل', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee({ perms: { sap: true } })).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p-mine'), {
      executorUids: [ME], managerUids: [], managerUid: null,
    }));
  });
});

describe('الأعمال تُطلب بنطاقها', () => {
  // العطل الثاني: البرنامج كان يطلب مجموعة الأعمال كاملةً، فتُرفض لكل من
  // لا يرى كل الإدارات — بمن فيهم مدراء الإدارات — فتظهر الصفحة فارغة.
  test('الطلب المفتوح — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertFails(getDocs(collection(db, 'works')));
  });

  test('المُسنَدة إليّ — يُقبل', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'works'), where('assigneeUid', '==', ME))));
  });

  test('ومدير الإدارة يستعلم عن أعمال إدارته — يُقبل', async () => {
    await seedAll();
    const db = env.authenticatedContext('u-mgr', manager()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'works'), where('departmentId', 'in', [DEPT]))));
  });

  test('ولا يستعلم عن أعمال إدارة لا يملكها — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext('u-mgr', manager()).firestore();
    await assertFails(getDocs(query(collection(db, 'works'), where('departmentId', 'in', [OTHER_DEPT]))));
  });
});

describe('طلبات الاعتماد تُطلب بنطاقها', () => {
  test('الطلب المفتوح لموظف — يُرفض', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertFails(getDocs(collection(db, 'approvalRequests')));
  });

  test('طلباتي أنا — يُقبل', async () => {
    await seedAll();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'approvalRequests'), where('requestedByUid', '==', ME))));
  });

  test('ومسؤول النظام يقرأها كاملةً', async () => {
    await seedAll();
    const db = env.authenticatedContext('u-admin', { role: 'systemAdmin', approved: true }).firestore();
    await assertSucceeds(getDocs(collection(db, 'approvalRequests')));
  });
});
