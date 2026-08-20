// اختبارات قواعد الأمان لعضوية المشروع.
//
// كل حالة رفض هنا تمثّل تجاوزاً حقيقياً: موظف يضيف غيره، أو يزيح زميله، أو
// يتسلّل إلى مشروع إدارة أخرى، أو يُمرّر تعديلاً آخر تحت غطاء الانضمام.
// والواجهة لا تُغني عن هذه القواعد: من يستطيع فتح طرفية المتصفح يستطيع
// تجاوز أي فحص فيها، فالخادم وحده هو الحَكَم.
//
// التشغيل: node --test membership.rules.test.mjs (ويلزم محاكي Firestore)
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import assert from 'node:assert';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const DEPT = 'd-systems';
const OTHER_DEPT = 'd-other';
const ME = 'u-me';
const COLLEAGUE = 'u-colleague';

let env;

function claims({ dept = DEPT, sap = true, role = 'employee' } = {}) {
  return { role, approved: true, departmentId: dept, departmentIds: [], perms: { sap } };
}

async function seed(project) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'projects/p1'), {
      departmentId: DEPT,
      name: 'مشروع تجريبي',
      dueDate: new Date('2026-12-31'),
      createdByUid: 'admin',
      managerUids: [],
      executorUids: [],
      managerUid: null,
      ...project,
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-membership',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => { await env?.cleanup(); });

describe('انضمام الموظف بنفسه', () => {
  test('يضيف نفسه منفّذاً داخل إدارته — يُقبل', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [ME], managerUids: [], managerUid: null,
    }));
  });

  test('يضيف نفسه مديراً مع وجود مدير آخر — يُقبل (تعدّد المديرين)', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [COLLEAGUE, ME], managerUid: COLLEAGUE, executorUids: [],
    }));
  });

  test('ينسحب من مشروعه — يُقبل', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE, ME], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [COLLEAGUE], managerUid: COLLEAGUE, executorUids: [],
    }));
  });
});

describe('ما يجب أن يُرفض', () => {
  test('يضيف غيره — يُرفض', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [COLLEAGUE], managerUids: [], managerUid: null,
    }));
  });

  test('يزيح مديراً قائماً — يُرفض', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [ME], managerUid: ME, executorUids: [],
    }));
  });

  test('ينضم لمشروع خارج إدارته — يُرفض', async () => {
    await env.clearFirestore();
    await seed({ departmentId: OTHER_DEPT });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [ME], managerUids: [], managerUid: null,
    }));
  });

  test('بلا الصلاحية — يُرفض', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims({ sap: false })).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [ME], managerUids: [], managerUid: null,
    }));
  });

  // الثغرة التي سُدّت في القاعدة: الحقل المفرد الموروث ضمن المفاتيح المسموح
  // تعديلها، فلولا اشتراط اتساقه لأسند الموظف المشروع لمن ليس عضواً فيه.
  test('يضبط الحقل المفرد على غير عضو — يُرفض', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [ME], managerUid: COLLEAGUE, executorUids: [],
    }));
  });

  test('يُمرّر تعديل الموعد النهائي تحت غطاء الانضمام — يُرفض', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [ME], managerUid: ME, executorUids: [],
      dueDate: new Date('2030-01-01'),
    }));
  });
});

describe('القراءة', () => {
  test('صاحب الصلاحية يقرأ مشاريع إدارته', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(getDoc(doc(db, 'projects/p1')));
  });

  test('بلا صلاحية وبلا عضوية ومن إدارة أخرى — لا يقرأ', async () => {
    await env.clearFirestore();
    await seed({ departmentId: OTHER_DEPT });
    const db = env.authenticatedContext(ME, claims({ sap: false })).firestore();
    await assertFails(getDoc(doc(db, 'projects/p1')));
  });

  test('العضو يقرأ مشروعه ولو كان خارج إدارته', async () => {
    await env.clearFirestore();
    await seed({ departmentId: OTHER_DEPT, executorUids: [ME] });
    const db = env.authenticatedContext(ME, claims({ sap: false })).firestore();
    await assertSucceeds(getDoc(doc(db, 'projects/p1')));
  });
});

test('نتيجة', () => assert.ok(true));
