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

  // ولو كان على المشروع مديرٌ قائم. وهذه الحالة تحديداً هي ما يمرّ على
  // `managersUnchanged()` بقائمتين **غير فارغتين**: لو كانت المقارنة تُخفق
  // على قائمةٍ فيها اسم، لَحُرم كلُّ موظفٍ من التسجيل في مشروعٍ له مدير —
  // وهو أغلب مشاريع المنصة — والاختبار الذي فوقه لا يكشفه لأن قائمتيه فارغتان.
  test('ويضيف نفسه منفّذاً إلى مشروعٍ له مدير — يُقبل', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [ME], managerUids: [COLLEAGUE], managerUid: COLLEAGUE,
    }));
  });

  test('وينسحب من التنفيذ — يُقبل', async () => {
    await env.clearFirestore();
    await seed({ executorUids: [COLLEAGUE, ME], managerUids: [COLLEAGUE], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      executorUids: [COLLEAGUE], managerUids: [COLLEAGUE], managerUid: COLLEAGUE,
    }));
  });
});

// ــــ قيادة المشروع تُعطى ولا تُؤخذ ــــ
//
// كان الاختباران التاليان يشترطان **القبول**: أن يضيف الموظف نفسه مديراً،
// وأن ينسحب من القيادة بنفسه. وقد انعكسا بقرارٍ صريح في جولة فصل الدور عن
// قيادة المشروع، لا بعطلٍ طرأ:
//
// - **الإضافة**: من يقود المشروع يرى تفاصيله كاملة ويُسنِد مهامه ويعتمد ما
//   يُنجَز فيه. فلا تُنال بضغطةٍ من صاحبها، بل بطلبٍ يعتمده مدير إدارة
//   المشروع أو مسؤول النظام.
// - **الانسحاب**: أهون في الأثر، وأخطرُ في السجل. طُلب صراحةً أن يُكتب «من
//   ألغى التعيين ومتى»، والكتابةُ المباشرة من العميل لا تمرّ بمن يكتب ذلك.
//   فيمرّ الانسحاب بـ`setProjectTeam` التي تحسب الفروق وتسمّيها في سجل
//   التدقيق. وقد يبقى المشروع بلا مدير لو تُرك الأمر للعميل.
describe('ولا يسجّل أحدٌ نفسه **مديراً**', () => {
  test('يضيف نفسه مديراً مع وجود مدير آخر — يُرفض', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [COLLEAGUE, ME], managerUid: COLLEAGUE, executorUids: [],
    }));
  });

  test('ويضيف نفسه مديراً وحيداً لمشروعٍ بلا مدير — يُرفض', async () => {
    await env.clearFirestore();
    await seed({});
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
      managerUids: [ME], managerUid: ME, executorUids: [],
    }));
  });

  test('وينسحب من قيادة مشروعه — يُرفض، فالإلغاء يُسجَّل باسم من ألغاه', async () => {
    await env.clearFirestore();
    await seed({ managerUids: [COLLEAGUE, ME], managerUid: COLLEAGUE });
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p1'), {
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
