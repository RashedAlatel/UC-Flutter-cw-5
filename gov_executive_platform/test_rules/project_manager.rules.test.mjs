// قيادة المشروع صفةٌ على المشروع لا دورٌ على الشخص.
//
// ــــ ما الذي لا تكشفه القراءة؟ ــــ
//
// أن `isMyProject` كانت تشترط `role() == 'projectOfficer'`. فنتج خطآن
// متقابلان لا يظهران في أي تحليل:
//
//   • موظفٌ يقود مشروعاً فعلاً (اسمه في `managerUids`) **لا يستطيع** فتح
//     مهامه ولا تحرير تقدّمه — والمنصة تُريه المشروع ولا تدعه يعمل فيه.
//   • وصاحبُ الدور يحمل صفة «مدير مشروع» في مشاريع لا علاقة له بها.
//
// وأخطر منهما: صاحب صلاحية «الانضمام لمشاريع الإدارة» كان **يسجّل نفسه
// مديراً** بضغطة، بلا اعتماد أحد. فقيادةُ المشروع تُؤخذ لا تُعطى.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, setDoc, updateDoc } from 'firebase/firestore';

const DEPT = 'd-justice';
const EMP = 'u-emp';       // موظف — ومديرُ المشروع p1
const OTHER = 'u-other';   // موظف آخر في الإدارة نفسها
const HEAD = 'u-head';     // مدير الإدارة

let env;

function claims(uid, { role = 'employee', dept = DEPT, depts = [], perms = {} } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: depts, perms };
}

/** الموظف الذي يقود المشروع — دورُه الأساسي «موظف» لا «مدير مشروع». */
function empDb(extra = {}) {
  return env.authenticatedContext(EMP, claims(EMP, extra)).firestore();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-pm',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [id, role] of [[EMP, 'employee'], [OTHER, 'employee'], [HEAD, 'departmentManager']]) {
      await setDoc(doc(db, `users/${id}`), {
        name: id, role, departmentId: DEPT, departmentIds: [DEPT], status: 'approved',
      });
    }
    // مشروعٌ يقوده **موظف**.
    await setDoc(doc(db, 'projects/p1'), {
      name: 'الأرشفة الإلكترونية',
      departmentId: DEPT,
      managerUids: [EMP],
      executorUids: [],
      managerUid: EMP,
      progressPercent: 10,
      dueDate: new Date('2026-12-31'),
      createdByUid: HEAD,
    });
    // ومهمّةٌ فيه، بالحقول المنسوخة كما يكتبها التطبيق.
    await setDoc(doc(db, 'tasks/t1'), {
      projectId: 'p1', departmentId: DEPT, managerUid: EMP, managerUids: [EMP],
      title: 'مهمة', assigneeUid: OTHER, assigneeName: 'زميل',
      status: 'todo', progressPercent: 0,
      lastUpdated: new Date('2026-08-01'), dueDate: new Date('2026-12-31'), priority: 'medium',
    });
    // وخطرٌ عليه.
    await setDoc(doc(db, 'risks/r1'), {
      projectId: 'p1', departmentId: DEPT, managerUid: EMP, managerUids: [EMP],
      title: 'خطر', description: '', level: 'medium', status: 'open',
      createdDate: new Date('2026-08-01'),
    });
    // ومشروعٌ لا علاقة للموظف به.
    await setDoc(doc(db, 'projects/p2'), {
      name: 'مشروع غيره', departmentId: DEPT,
      managerUids: [OTHER], executorUids: [], managerUid: OTHER,
      progressPercent: 10, dueDate: new Date('2026-12-31'), createdByUid: HEAD,
    });
  });
});

after(async () => { await env?.cleanup(); });

describe('الموظف الذي يقود مشروعاً', () => {
  test('يحرّك تقدّم مشروعه — ودورُه «موظف»', async () => {
    await assertSucceeds(updateDoc(doc(empDb(), 'projects/p1'), { progressPercent: 40 }));
  });

  test('ويحرّر مهام مشروعه', async () => {
    await assertSucceeds(updateDoc(doc(empDb(), 'tasks/t1'), { status: 'inProgress' }));
  });

  test('وينشئ مهمّة فيه', async () => {
    await assertSucceeds(addDoc(collection(empDb(), 'tasks'), {
      projectId: 'p1', departmentId: DEPT, managerUid: EMP,
      title: 'مهمة جديدة', assigneeName: 'زميل', status: 'todo', progressPercent: 0,
      lastUpdated: new Date(), dueDate: new Date('2026-12-31'), priority: 'medium',
    }));
  });

  test('ويحرّر مخاطره', async () => {
    await assertSucceeds(updateDoc(doc(empDb(), 'risks/r1'), { status: 'mitigated' }));
  });

  test('ولا يحرّك تقدّم مشروعٍ ليس مسجَّلاً عليه', async () => {
    // موظفٌ من الإدارة نفسها، ومع ذلك يُرفض: قيادةُ المشروع على المشروع.
    await assertFails(updateDoc(doc(empDb(), 'projects/p2'), { progressPercent: 40 }));
  });
});

describe('لا يُسجّل أحدٌ نفسه مديراً', () => {
  test('صاحب «الانضمام لمشاريع الإدارة» يضيف نفسه **منفّذاً** — يُقبل', async () => {
    const db = empDb({ perms: { sap: true } });
    await assertSucceeds(updateDoc(doc(db, 'projects/p2'), {
      managerUids: [OTHER], executorUids: [EMP], managerUid: OTHER,
    }));
  });

  test('ويضيف نفسه **مديراً** — يُرفض', async () => {
    const db = empDb({ perms: { sap: true } });
    await assertFails(updateDoc(doc(db, 'projects/p2'), {
      managerUids: [OTHER, EMP], executorUids: [], managerUid: OTHER,
    }));
  });

  test('ولا يُزيح مديراً قائماً ليضع نفسه مكانه', async () => {
    const db = empDb({ perms: { sap: true } });
    await assertFails(updateDoc(doc(db, 'projects/p2'), {
      managerUids: [EMP], executorUids: [], managerUid: EMP,
    }));
  });

  test('ومديرُ المشروع نفسه لا يُضيف مديراً ثانياً — التعيين يمرّ بالاعتماد', async () => {
    await assertFails(updateDoc(doc(empDb({ perms: { sap: true } }), 'projects/p1'), {
      managerUids: [EMP, OTHER], executorUids: [], managerUid: EMP,
    }));
  });

  test('ومدير الإدارة يعيّن مباشرةً — الطريق دالّة setProjectTeam لا العميل', async () => {
    // القاعدة تمنع الكتابة المباشرة على كلٍّ (جولة قاعدة الإسناد الموحّدة)،
    // فالتعيين يقع بالدالّة السحابية بصلاحيات المسؤول.
    const db = env
      .authenticatedContext(HEAD, claims(HEAD, { role: 'departmentManager', depts: [DEPT] }))
      .firestore();
    await assertFails(updateDoc(doc(db, 'projects/p2'), {
      managerUids: [OTHER, EMP], executorUids: [], managerUid: OTHER,
    }));
  });
});

describe('التسجيل الذاتي يُكتب بأدنى الأدوار', () => {
  test('حسابٌ جديد بدور «موظف» — يُقبل', async () => {
    const db = env.authenticatedContext('u-new').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/u-new'), {
      name: 'مسجّل جديد', email: 'x@moj.gov.kw', phone: '',
      role: 'employee', status: 'pending', departmentId: DEPT,
    }));
  });

  test('وبدور «مدير مشروع» — يُرفض', async () => {
    const db = env.authenticatedContext('u-new2').firestore();
    await assertFails(setDoc(doc(db, 'users/u-new2'), {
      name: 'مسجّل', email: 'y@moj.gov.kw', phone: '',
      role: 'projectOfficer', status: 'pending', departmentId: DEPT,
    }));
  });

  test('وبدور «مدير إدارة» — يُرفض كذلك (الدور المطلوب يمرّ بالطلب)', async () => {
    const db = env.authenticatedContext('u-new3').firestore();
    await assertFails(setDoc(doc(db, 'users/u-new3'), {
      name: 'مسجّل', email: 'z@moj.gov.kw', phone: '',
      role: 'departmentManager', status: 'pending', departmentId: DEPT,
    }));
  });
});
