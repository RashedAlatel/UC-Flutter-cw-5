// الصلاحيات المقيَّدة بنطاق — وهي التي تفتح بوابةً كانت مغلقة.
//
// قرّر مسؤول النظام فتح «إضافة المشاريع» عبر مفتاح بيده: `mpr` للإنشاء
// المباشر و`apr` للاعتماد، تُمنحان لفرد بعينه ضمن نطاق إدارات. وكل حالة
// رفض هنا تمثّل تجاوزاً حقيقياً — إنشاء خارج النطاق، أو علَمٌ بلا نطاق
// يُقرأ على أنه «الكل»، أو تسلّل إلى البوابتين اللتين لم تُفتحا.
import { readFileSync } from 'node:fs';
import { test, before, after, describe } from 'node:test';
import assert from 'node:assert';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { addDoc, collection, doc, setDoc, updateDoc } from 'firebase/firestore';

const MINE = 'd-mine';
const OTHER = 'd-other';
const ME = 'u-me';

let env;

/** بطاقة دخول موظف عادي، مع منحة نطاق اختيارية. */
function claims({ dept = MINE, scopes = null } = {}) {
  return {
    role: 'employee',
    approved: true,
    departmentId: dept,
    departmentIds: [],
    perms: {
      sfb: true,
      mpr: scopes?.mpr !== undefined,
      apr: scopes?.apr !== undefined,
    },
    ...(scopes ? { scopes } : {}),
  };
}

function newProject(departmentId) {
  return {
    departmentId,
    name: 'مشروع جديد',
    description: '',
    startDate: new Date('2026-01-01'),
    dueDate: new Date('2026-12-31'),
    status: 'onTrack',
    priority: 'medium',
    progressPercent: 0,
    delayDays: 0,
    createdByUid: ME,
    managerUids: [],
    executorUids: [],
    managerUid: null,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-grants',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `projects/p-mine`), newProject(MINE));
  });
});

after(async () => { await env?.cleanup(); });

describe('إنشاء المشاريع بنطاق', () => {
  test('بلا منحة إطلاقاً — يُرفض (وهذا هو الوضع الافتراضي للجميع)', async () => {
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(addDoc(collection(db, 'projects'), newProject(MINE)));
  });

  test('بمنحة داخل نطاقها — يُقبل', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { mpr: [MINE] } })).firestore();
    await assertSucceeds(addDoc(collection(db, 'projects'), newProject(MINE)));
  });

  test('وخارج نطاقها — يُرفض', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { mpr: [MINE] } })).firestore();
    await assertFails(addDoc(collection(db, 'projects'), newProject(OTHER)));
  });

  test('وبنطاق «كل الإدارات» — يُقبل في أي إدارة', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { mpr: '*' } })).firestore();
    await assertSucceeds(addDoc(collection(db, 'projects'), newProject(OTHER)));
  });

  // أخطر خطأ ممكن في هذا التصميم: أن يُقرأ غياب النطاق على أنه «الكل».
  test('علَمٌ بلا نطاق إطلاقاً — يُرفض ولا يُفهم أنه الكل', async () => {
    const db = env
      .authenticatedContext(ME, {
        role: 'employee', approved: true, departmentId: MINE, departmentIds: [],
        perms: { mpr: true },
      })
      .firestore();
    await assertFails(addDoc(collection(db, 'projects'), newProject(MINE)));
  });

  // الحالة الواقعية لا المصطنعة: مُنِح `apr` وحدها، فخريطة النطاقات موجودة
  // ومفتاح `mpr` غائب عنها. ولو قُرئ الغياب على أنه «الكل» لصار كلُّ منحٍ
  // جزئيٍّ منحاً شاملاً — وهذا أخطر ما يمكن أن يقع في هذا التصميم.
  test('نطاقات موجودة والمفتاح غائب عنها — يُرفض', async () => {
    const db = env
      .authenticatedContext(ME, {
        role: 'employee', approved: true, departmentId: MINE, departmentIds: [],
        perms: { mpr: true, apr: true },
        scopes: { apr: '*' },
      })
      .firestore();
    await assertFails(addDoc(collection(db, 'projects'), newProject(MINE)));
  });

  test('ونطاق فارغ — يُرفض كذلك', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { mpr: [] } })).firestore();
    await assertFails(addDoc(collection(db, 'projects'), newProject(MINE)));
  });
});

describe('إسناد المستخدمين بنطاق', () => {
  test('صاحب المنحة يُسنِد غيره داخل نطاقه', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { mpr: [MINE] } })).firestore();
    await assertSucceeds(updateDoc(doc(db, 'projects/p-mine'), {
      executorUids: ['u-someone-else'], managerUids: [], managerUid: null,
    }));
  });

  test('ومن لا منحة له لا يُسنِد غيره', async () => {
    const db = env.authenticatedContext(ME, claims({ scopes: { sap: [MINE] } })).firestore();
    await assertFails(updateDoc(doc(db, 'projects/p-mine'), {
      executorUids: ['u-someone-else'], managerUids: [], managerUid: null,
    }));
  });
});

describe('البوابتان اللتان لم تُفتحا', () => {
  // حارس صريح: فتحُ إضافة المشاريع لا يجوز أن يجرّ معه غيرها.
  test('صاحب mpr وapr لا يعدّل موعداً نهائياً', async () => {
    const db = env
      .authenticatedContext(ME, claims({ scopes: { mpr: '*', apr: '*' } }))
      .firestore();
    await assertFails(updateDoc(doc(db, 'projects/p-mine'), { dueDate: new Date('2027-01-01') }));
  });

  test('ولا ينقل مشروعاً إلى إدارة أخرى', async () => {
    const db = env
      .authenticatedContext(ME, claims({ scopes: { mpr: '*' } }))
      .firestore();
    await assertFails(updateDoc(doc(db, 'projects/p-mine'), { departmentId: OTHER }));
  });

  test('ولا يعتمد تسجيل عضو بكتابة سجل مستخدم', async () => {
    const db = env
      .authenticatedContext(ME, claims({ scopes: { mpr: '*', apr: '*' } }))
      .firestore();
    await assertFails(setDoc(doc(db, 'users/u-victim'), {
      name: 'ضحية', email: 'v@moj.gov.kw', phone: '', role: 'systemAdmin',
      status: 'approved', departmentId: MINE, departmentIds: [], createdAt: new Date(),
    }));
  });
});
