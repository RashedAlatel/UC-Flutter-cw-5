// اختبارات قواعد الشكاوى والاقتراحات، والاستثناءات الفردية للصلاحيات.
//
// الصلاحيتان منفصلتان عمداً: `sfb` ترفع، و`mfb` تطّلع على كل الوارد وتبتّ.
// وكل رفض هنا يمثّل تجاوزاً حقيقياً: من يرفع باسم غيره، أو يقرأ شكاوى
// زملائه، أو يبتّ في شكواه هو، أو يعدّل نصّها بعد رفعها.
//
// التشغيل: node --test feedback.rules.test.mjs (ويلزم محاكي Firestore)
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

const DEPT = 'd-systems';
const ME = 'u-me';
const COLLEAGUE = 'u-colleague';

let env;

function employee({ perms = {}, dept = DEPT } = {}) {
  return { role: 'employee', approved: true, departmentId: dept, departmentIds: [], perms };
}

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'feedback/f-mine'), {
      kind: 'complaint', title: 'شكواي', body: 'تفاصيل',
      submittedByUid: ME, submittedByName: 'أنا', departmentId: DEPT,
      status: 'submitted', responseNote: null, createdAt: new Date(),
    });
    await setDoc(doc(db, 'feedback/f-colleague'), {
      kind: 'suggestion', title: 'اقتراح زميلي', body: 'تفاصيل',
      submittedByUid: COLLEAGUE, submittedByName: 'زميلي', departmentId: DEPT,
      status: 'submitted', responseNote: null, createdAt: new Date(),
    });
  });
}

function newItem(overrides = {}) {
  return {
    kind: 'suggestion', title: 'اقتراح', body: 'تفاصيل',
    submittedByUid: ME, submittedByName: 'أنا', departmentId: DEPT,
    status: 'submitted', responseNote: null, createdAt: new Date(),
    ...overrides,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-feedback',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});

after(async () => { await env?.cleanup(); });

describe('الرفع', () => {
  test('بلا صلاحية الرفع — يُرفض', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertFails(setDoc(doc(db, 'feedback/new'), newItem()));
  });

  test('بصلاحية الرفع — يُقبل', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertSucceeds(setDoc(doc(db, 'feedback/new'), newItem()));
  });

  // لا يُنسب أحدٌ شكوى إلى غيره: المعرّف على المستند يجب أن يكون معرّف المتصل.
  test('باسم غيره — يُرفض', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertFails(setDoc(doc(db, 'feedback/new'), newItem({ submittedByUid: COLLEAGUE })));
  });

  // ولا يرفع شكوى مبتوتاً فيها سلفاً فتبدو وكأن الإدارة عالجتها.
  test('مبتوتاً فيها سلفاً — يُرفض', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertFails(setDoc(doc(db, 'feedback/a'), newItem({ status: 'resolved' })));
    await assertFails(setDoc(doc(db, 'feedback/b'), newItem({ responseNote: 'تمّت المعالجة' })));
  });
});

describe('القراءة', () => {
  test('يقرأ ما رفعه هو ولو بلا صلاحية', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDoc(doc(db, 'feedback/f-mine')));
  });

  test('ولا يقرأ شكوى زميله', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertFails(getDoc(doc(db, 'feedback/f-colleague')));
  });

  // النطاق لا المستند: الاستعلام المفتوح يُرفض لمن لا يتابع الوارد.
  test('الاستعلام المفتوح بلا متابعة — يُرفض', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertFails(getDocs(collection(db, 'feedback')));
  });

  test('واستعلام ما رفعتُه — يُقبل', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee()).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'feedback'), where('submittedByUid', '==', ME))));
  });

  test('ومن يتابع الوارد يقرأ الكل', async () => {
    await seed();
    const db = env.authenticatedContext('u-handler', employee({ perms: { mfb: true } })).firestore();
    await assertSucceeds(getDocs(collection(db, 'feedback')));
  });
});

describe('البتّ', () => {
  test('صاحبها لا يبتّ في شكواه', async () => {
    await seed();
    const db = env.authenticatedContext(ME, employee({ perms: { sfb: true } })).firestore();
    await assertFails(updateDoc(doc(db, 'feedback/f-mine'), { status: 'resolved', responseNote: 'حسناً' }));
  });

  test('ومن يتابعها يبتّ', async () => {
    await seed();
    const db = env.authenticatedContext('u-handler', employee({ perms: { mfb: true } })).firestore();
    await assertSucceeds(updateDoc(doc(db, 'feedback/f-mine'), {
      status: 'resolved', responseNote: 'عولجت', handledByName: 'المتابع', handledAt: new Date(),
    }));
  });

  // الشكوى سجلٌّ لا مسوَّدة: نصّها لا يُعدَّل بعد رفعها ولو ممن يبتّ فيها.
  test('ولا يعدّل نصّها', async () => {
    await seed();
    const db = env.authenticatedContext('u-handler', employee({ perms: { mfb: true } })).firestore();
    await assertFails(updateDoc(doc(db, 'feedback/f-mine'), { status: 'resolved', body: 'نصّ آخر' }));
  });
});

// الاستثناء الفردي يُختم في البطاقة على الخادم، فما يصل القواعد هو `perms`
// نفسها. والخطر أن يزرعه المسجِّل على سجله لحظة التسجيل فيُختم له لاحقاً.
describe('التسجيل الذاتي لا يمنح نفسه شيئاً', () => {
  test('سجل تسجيل نظيف — يُقبل', async () => {
    await env.clearFirestore();
    const db = env.authenticatedContext('u-new', { }).firestore();
    await assertSucceeds(setDoc(doc(db, 'users/u-new'), {
      name: 'جديد', email: 'a@moj.gov.kw', phone: '', role: 'employee',
      status: 'pending', createdAt: new Date(),
    }));
  });

  test('ومعه استثناءات صلاحيات — يُرفض', async () => {
    await env.clearFirestore();
    const db = env.authenticatedContext('u-new', { }).firestore();
    await assertFails(setDoc(doc(db, 'users/u-new'), {
      name: 'جديد', email: 'a@moj.gov.kw', phone: '', role: 'employee',
      status: 'pending', createdAt: new Date(),
      permissionOverrides: { vad: true },
    }));
  });

  test('ومعه استثناء من تأكيد البريد — يُرفض', async () => {
    await env.clearFirestore();
    const db = env.authenticatedContext('u-new', { }).firestore();
    await assertFails(setDoc(doc(db, 'users/u-new'), {
      name: 'جديد', email: 'a@gmail.com', phone: '', role: 'employee',
      status: 'pending', createdAt: new Date(),
      emailVerificationExempt: true,
    }));
  });

  // كان الحاجز `projectOfficer`، وقد سقط ذلك الدور من الأدوار المُتاحة، فصار
  // الحاجز أدناها. والحقلان أعلاه يُكتبان الآن بدور مقبول عمداً: لولا ذلك
  // لرُفضا **بسبب الدور** فبدا الحارسان يعملان وهما لا يُبلَغان أصلاً.
  test('ودورٌ أعلى من «موظف» لحظة التسجيل — يُرفض', async () => {
    await env.clearFirestore();
    const db = env.authenticatedContext('u-new', { }).firestore();
    for (const role of ['departmentManager', 'executiveViewer', 'projectOfficer', 'systemAdmin']) {
      await assertFails(setDoc(doc(db, 'users/u-new'), {
        name: 'جديد', email: 'a@moj.gov.kw', phone: '', role,
        status: 'pending', createdAt: new Date(),
      }));
    }
  });
});
