// المشاكلُ والتغييرات على الخادم — **وأهمُّ ما يُقاس هنا سطرٌ واحد**:
//
//   **لا يكتب عميلٌ «مُعتمَد» على تغييرٍ أبداً.**
//
// فلو كُتبت `status` من المتصفّح لاعتمد رافعُ التغيير تغييرَ نفسِه بضغطة،
// ولصارت لجنةُ CAB اسماً في شاشةٍ لا حكماً على الخادم. والبتُّ يقع في
// `approveRequest`/`rejectRequest` وحدَهما، وهما تكتبان بصلاحية المدير
// فتتجاوزان هذه القاعدة.
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const DESK = 'u-desk';
// ــ ولكلّ مجموعةِ صلاحيّاتٍ حسابُها ــ
//
// `rules-unit-testing` تُنشئ تطبيقاً لكلّ (مشروع، حساب). فحسابٌ واحدٌ
// ببطاقتين مختلفتين يُعيد تهيئةَ التطبيق نفسِه، فترمي المكتبةُ
// «Firestore has already been started» وتسقط اختباراتٌ سليمةٌ بلا سببٍ
// يُرى. وقد وقع عند أوّل تشغيلٍ لهذا الملفّ.
const CAB_ONLY = 'u-cab';
const CAB_DESK = 'u-cab-desk';
const EMP = 'u-emp';
const CHANGE = 'ch-1';
const PROBLEM = 'pr-1';

let env;

const claims = ({ role = 'employee', htk = false, cab = false, approved = true } = {}) => ({
  approved,
  role,
  departmentId: 'd-it',
  departmentIds: [],
  perms: { ...(htk ? { htk: true } : {}), ...(cab ? { cab: true } : {}) },
  scopes: {},
  hs: [],
});

const change = (over = {}) => ({
  title: 'ترقية خادم البريد',
  description: '',
  kind: 'normal',
  risk: 'medium',
  status: 'draft',
  plannedStart: null,
  plannedEnd: null,
  backoutPlan: 'إرجاع النسخة السابقة',
  implementerUid: DESK,
  implementerName: 'فنّيّ',
  relatedProblemId: '',
  createdByUid: DESK,
  createdByName: 'فنّيّ',
  createdAt: new Date('2026-05-10T08:00:00Z'),
  approvedByUid: '',
  approvedByName: '',
  approvedAt: null,
  decisionNote: '',
  implementedAt: null,
  awaitingReview: false,
  deletedAt: null,
  deletedBy: null,
  deletedReason: null,
  ...over,
});

const problem = (over = {}) => ({
  title: 'طابعاتُ الطابق الثاني تتعطّل أسبوعيّاً',
  statement: '',
  priority: 'high',
  status: 'investigating',
  ownerUid: DESK,
  ownerName: 'فنّيّ',
  rootCause: '',
  workaround: '',
  createdByUid: DESK,
  createdAt: new Date('2026-05-10T08:00:00Z'),
  resolvedAt: null,
  deletedAt: null,
  deletedBy: null,
  deletedReason: null,
  ...over,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-itsm-change',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

// ــ و`ctx.firestore()` تُنادى **مرّةً واحدة** في الاستدعاء ــ
//
// نداؤها مرّتين يُعيد تهيئةَ العميل، فترمي المكتبةُ «Firestore has already
// been started» — ويسقط الخطأُ في `beforeEach` لا في الاختبار، فتبدو
// الاختباراتُ كلُّها فاشلةً وفيها ما يجب أن ينجح. وقد وقع عند أوّل تشغيل،
// وضلّلني مرّتين قبل أن أقرأ `failureType: 'hookFailed'`.
const seed = async (over = {}) => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const raw = ctx.firestore();
    await raw.collection('changes').doc(CHANGE).set(change(over));
    await raw.collection('problems').doc(PROBLEM).set(problem());
  });
};

beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});

const db = (uid, c) => env.authenticatedContext(uid, c).firestore();
const chDoc = (uid, c) => db(uid, c).collection('changes').doc(CHANGE);

describe('من يقرأ التغييرات والمشاكل', () => {
  test('مكتبُ الخدمة يقرأ الاثنين', async () => {
    const d = db(DESK, claims({ htk: true }));
    await assertSucceeds(d.collection('changes').doc(CHANGE).get());
    await assertSucceeds(d.collection('problems').doc(PROBLEM).get());
  });

  // ــ والموظّفُ العاديُّ لا يقرأ ــ
  //
  // المشكلةُ تسمّي سبباً جذريّاً، والتغييرُ يحمل تفاصيلَ بنيةٍ تقنيّة
  // وخطّةَ تراجع. وليس فيهما ما يخصّ موظّفاً بعينه حتّى يُفتح له.
  test('والموظّفُ لا يقرأ شيئاً منهما', async () => {
    const d = db(EMP, claims());
    await assertFails(d.collection('changes').doc(CHANGE).get());
    await assertFails(d.collection('problems').doc(PROBLEM).get());
  });

  // ــ وحاملُ `cab` وحدَه ليس قارئاً ــ
  //
  // وهذا مقصود: البتُّ يقع من مركز القرارات، ومستندُ الطلب يحمل ما يلزم.
  // ومن أراد أن يقرأ الطابور يُمنح `htk` معها بقرارٍ صريح.
  test('وحاملُ cab وحدَه لا يقرأ الطابور — يبتّ من مركز القرارات', async () => {
    await assertFails(chDoc(CAB_ONLY, claims({ cab: true })).get());
  });
});

describe('لا يكتب عميلٌ قراراً — وهذا هو جوهرُ اللجنة', () => {
  test('رافعُ التغيير لا يعتمد تغييرَ نفسِه', async () => {
    await assertFails(chDoc(DESK, claims({ htk: true })).update({ status: 'approved' }));
  });

  test('ولا يرفضه', async () => {
    await assertFails(chDoc(DESK, claims({ htk: true })).update({ status: 'rejected' }));
  });

  // ــ ولا يعتمده حاملُ `cab` من المتصفّح ــ
  //
  // فحتّى صاحبُ الحقّ يبتّ عبر الدالّة الخلفيّة: هي التي تفحص المرحلةَ
  // وتكتب السجلّ وتُخطر الطالب. وكتابةٌ مباشرةٌ تتخطّى الثلاثة.
  test('ولا يعتمده حاملُ cab مباشرةً — البتُّ عبر الدالّة', async () => {
    await assertFails(chDoc(CAB_DESK, claims({ htk: true, cab: true }))
      .update({ status: 'approved' }));
  });

  test('ولا يكتب اسمَ المعتمِد ولا وقتَه', async () => {
    const d = chDoc(DESK, claims({ htk: true }));
    await assertFails(d.update({ approvedByUid: DESK }));
    await assertFails(d.update({ approvedAt: new Date() }));
  });

  // ــ ولا يرفع عن نفسِه وسمَ «ينتظر مراجعة» ــ
  //
  // وهذا هو ما يمنع أن يصير الطارئُ باباً خلفيّاً: من نفّذ تغييراً طارئاً
  // لا يُعلن بنفسه أنّه روجِع. ويُبذَر `true` صراحةً — فكتابةُ `false` على
  // مستندٍ قيمتُه `false` **ليست تغييراً**، و`affectedKeys` لا تراها، فمرّت
  // في أوّل تشغيل. والاختبارُ كان يقيس لا شيء.
  test('ولا يرفع عن نفسِه وسمَ «ينتظر مراجعة»', async () => {
    await seed({ kind: 'emergency', status: 'implemented', awaitingReview: true });
    await assertFails(chDoc(DESK, claims({ htk: true })).update({ awaitingReview: false }));
  });

  // ــ والضابط: ما ليس قراراً يُعدَّل ــ
  //
  // فلولاه لَمرّت الاختباراتُ أعلاه حتّى لو رُدّت الكتابةُ كلُّها لسببٍ آخر.
  test('والضابط: مكتبُ الخدمة يعدّل ما ليس قراراً', async () => {
    await assertSucceeds(chDoc(DESK, claims({ htk: true })).update({
      status: 'awaitingApproval',
      backoutPlan: 'خطّةٌ أدقّ',
    }));
  });
});

describe('والطارئُ وحدَه يُولد منفَّذاً', () => {
  const fresh = (uid, c, over = {}) =>
    db(uid, c).collection('changes').doc('ch-new').set(
      change({ createdByUid: uid, createdAt: serverTimestamp(), ...over }),
    );

  test('طارئٌ يُنشأ منفَّذاً وينتظر مراجعةً', async () => {
    await assertSucceeds(fresh(DESK, claims({ htk: true }), {
      kind: 'emergency', status: 'implemented', awaitingReview: true,
    }));
  });

  // ــ ولولا هذا الشرطُ لصار الاستثناءُ قاعدةً ــ
  //
  // كلُّ تغييرٍ يُولد `implemented` لا يمرّ باعتمادٍ قطّ.
  test('وعاديٌّ لا يُنشأ منفَّذاً', async () => {
    await assertFails(fresh(DESK, claims({ htk: true }), { status: 'implemented' }));
  });

  test('وعاديٌّ لا يُنشأ منتظِراً مراجعةً', async () => {
    await assertFails(fresh(DESK, claims({ htk: true }), { awaitingReview: true }));
  });

  test('ولا يُنشأ أيُّ تغييرٍ معتمَداً ابتداءً', async () => {
    await assertFails(fresh(DESK, claims({ htk: true }), { status: 'approved' }));
    await assertFails(fresh(DESK, claims({ htk: true }),
      { kind: 'emergency', status: 'implemented', approvedByUid: DESK }));
  });

  test('ووقتُ الإنشاء وقتُ الخادم', async () => {
    await assertFails(db(DESK, claims({ htk: true })).collection('changes').doc('ch-t').set(
      change({ createdByUid: DESK, createdAt: new Date('2020-01-01T00:00:00Z') }),
    ));
  });

  test('وغيرُ مكتب الخدمة لا يرفع تغييراً', async () => {
    await assertFails(fresh(EMP, claims()));
  });

  // والضابط: مكتبُ الخدمة يرفع عاديّاً.
  test('والضابط: مكتبُ الخدمة يرفع تغييراً عاديّاً', async () => {
    await assertSucceeds(fresh(DESK, claims({ htk: true })));
  });
});

describe('المشاكل', () => {
  test('مكتبُ الخدمة يفتح مشكلةً', async () => {
    await assertSucceeds(db(DESK, claims({ htk: true })).collection('problems').doc('pr-new')
      .set(problem({ createdByUid: DESK, createdAt: serverTimestamp() })));
  });

  test('والموظّفُ لا يفتحها', async () => {
    await assertFails(db(EMP, claims()).collection('problems').doc('pr-new')
      .set(problem({ createdByUid: EMP, createdAt: serverTimestamp() })));
  });

  test('ولا يُبدَّل منشئُها بعد الفتح', async () => {
    await assertFails(db(DESK, claims({ htk: true })).collection('problems').doc(PROBLEM)
      .update({ createdByUid: CAB_ONLY }));
  });

  test('والمحوُ لمسؤول النظام وحدَه', async () => {
    await assertFails(db(DESK, claims({ htk: true })).collection('problems').doc(PROBLEM).delete());
    await assertSucceeds(db('adm', claims({ role: 'systemAdmin' }))
      .collection('problems').doc(PROBLEM).delete());
  });
});

// ــــ والمفتاحُ الجديدُ لا يتعدّى التغييرات ــــ
//
// `cab` تفتح بوّابةً لم تكن مفتوحة، فيجب أن يُقاس **حدُّها**. والبوّاباتُ
// الثلاث تبقى حيث هي: محصورةً بمسؤول النظام، لا يفتحها مفتاحٌ مفوَّض.
describe('حاملُ cab لا يتعدّى التغييرات', () => {
  test('لا يعتمد تسجيلَ عضوٍ جديد', async () => {
    await assertFails(db(CAB_ONLY, claims({ cab: true }))
      .collection('users').doc('someone').update({ status: 'approved' }));
  });

  test('ولا يعدّل موعداً نهائيّاً لمشروع', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('projects').doc('p1').set({
        name: 'مشروع', departmentId: 'd-other', managerUid: 'someone',
        deadline: new Date('2026-12-01T00:00:00Z'),
      });
    });
    await assertFails(db(CAB_ONLY, claims({ cab: true })).collection('projects').doc('p1')
      .update({ deadline: new Date('2027-12-01T00:00:00Z') }));
  });

  test('ولا يضيف مشروعاً', async () => {
    await assertFails(db(CAB_ONLY, claims({ cab: true })).collection('projects').doc('p2')
      .set({ name: 'جديد', departmentId: 'd-other', managerUid: CAB_ONLY }));
  });
});
