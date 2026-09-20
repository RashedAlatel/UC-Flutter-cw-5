// حالاتُ الموظفين اليومية على الخادم: من يقرأ، ومن يكتب، ومن لا يصحّح.
//
// ــــ ولماذا هذه الكتلةُ أضيقُ من كلّ ما قبلها ــــ
//
// كلُّ ما سبق في هذه المنصة بياناتُ **عمل**: مشاريعُ الوزارة ومهامُّها
// ومخاطرُها. وقاعدتُها العامّة أنّ الموظّف المعتمَد يرى ما في إدارته.
//
// وهذه بياناتُ **أشخاص**: متى استأذن فلان، وكم مرّةً مرض، ومتى تغيّب.
// فالقاعدةُ تنقلب: **الموظّفُ لا يرى إلا حالتَه هو** ولو كان زميلَه في
// القسم نفسِه والإدارة نفسِها. وهو ما طلبه مسؤول النظام صراحةً.
//
// ــــ وما يُقاس هنا ــــ
//
// (١) القراءةُ لصاحبها ولمن فوقه، **ولا لزميله**.
// (٢) والكتابةُ باسم صاحبها وحدَه، **ولا باسم غيره**.
// (٣) والتصحيحُ **لا يمرّ من العميل أصلاً** — فالأثرُ يُكتب في `auditLog`،
//     ولو فُتح التعديلُ هنا لَصار التصحيحُ يقع بلا أثرٍ يُسأل عنه.
// (٤) و`vds` **بنطاقها**: علَمٌ بلا نطاقٍ لا يمنح شيئاً.
// (٥) ورئاسةُ القسم **من البطاقة لا من مستند القسم**: `headUid` لا يُكتب
//     من العميل، لأنّ كتابتَه لا تختم بطاقةً — وهو عينُ العطل الذي كلّف
//     المنصةَ `mtd` و`bla`.
import assert from 'node:assert/strict';
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';

const DEPT = 'd-justice';
const OTHER = 'd-finance';
const SECTION = 's-contracts';
const TODAY = '2026-09-20';

let env;

const claims = (
  { role = 'employee', approved = true, perms = {}, scopes = {}, hs = [], depts = null } = {},
) => ({
  approved,
  role,
  departmentId: DEPT,
  departmentIds: depts ?? (role === 'departmentManager' ? [DEPT] : []),
  perms,
  scopes,
  hs,
});

/** سجلُّ يومٍ لموظّفٍ في قسم العقود. */
const statusDoc = (uid = 'emp') => ({
  uid,
  userName: 'موظّف',
  departmentId: DEPT,
  sectionId: SECTION,
  dayKey: TODAY,
  kind: 'day',
  typeId: 't-present',
  typeName: 'حضور',
  toneKey: 'success',
  correctedByUid: '',
});

before(async () => {
  env = await initializeTestEnvironment({
    // ــ ومعرّفُ مشروعٍ خاصٌّ بهذا الملفّ ــ
    //
    // `node --test` يشغّل الملفّات **في عمليّاتٍ متوازية**، و
    // `clearFirestore()` يمحو قاعدةَ المشروع كلَّها. فملفّان يتقاسمان
    // معرّفاً واحداً يمحو أحدُهما بذورَ الآخر في منتصف تشغيله، فتسقط
    // اختباراتٌ سليمةٌ بلا سببٍ يُرى — ويُتَّهم ما لا عيبَ فيه.
    //
    // وقد وقع: خمسةُ ملفّاتٍ بقيت على `rules-test`، فلمّا أُضيف سادسٌ
    // سقطت ثلاثةٌ منها. وأربعةٌ وعشرون ملفّاً كانت تفعل هذا أصلاً.
    projectId: 'rules-test-daily-status',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('dailyStatuses').doc(`emp_${TODAY}`).set(statusDoc());
    await db.collection('sections').doc(SECTION).set({
      departmentId: DEPT,
      name: 'قسم العقود',
      headUid: 'head',
    });
  });
});

const read = (uid, c) =>
  env.authenticatedContext(uid, c).firestore().collection('dailyStatuses').doc(`emp_${TODAY}`).get();

describe('من يقرأ حالةَ موظّف', () => {
  test('صاحبُها يقرؤها', async () => {
    await assertSucceeds(read('emp', claims()));
  });

  // ــ وهذا هو الحدُّ الذي يميّز هذه الكتلةَ عمّا قبلها ــ
  test('وزميلُه في القسم نفسِه لا يقرؤها', async () => {
    await assertFails(read('peer', claims()));
  });

  test('ورئيسُ قسمه يقرؤها', async () => {
    await assertSucceeds(read('head', claims({ hs: [SECTION] })));
  });

  test('ورئيسُ قسمٍ آخر لا يقرؤها', async () => {
    await assertFails(read('head2', claims({ hs: ['s-other'] })));
  });

  test('ومديرُ إدارته يقرؤها', async () => {
    await assertSucceeds(read('mgr', claims({ role: 'departmentManager' })));
  });

  test('ومديرُ إدارةٍ أخرى لا يقرؤها', async () => {
    await assertFails(read('mgr2', claims({ role: 'departmentManager', depts: [OTHER] })));
  });

  test('والمستخدمُ التنفيذيُّ يقرؤها', async () => {
    await assertSucceeds(read('exec', claims({ role: 'executiveViewer' })));
  });

  test('ومسؤولُ النظام يقرؤها', async () => {
    await assertSucceeds(read('adm', claims({ role: 'systemAdmin' })));
  });

  test('وحسابٌ غيرُ معتمَدٍ لا يقرأ ولو كان صاحبَها', async () => {
    await assertFails(read('emp', claims({ approved: false })));
  });
});

describe('والمراقبُ بمنحته ونطاقها', () => {
  test('من مُنح vds في إدارتها يقرؤها', async () => {
    await assertSucceeds(read('obs', claims({ perms: { vds: true }, scopes: { vds: [DEPT] } })));
  });

  // ــ وعلَمٌ بلا نطاقٍ لا يمنح شيئاً ــ
  //
  // وهو الفرقُ الذي لو انعكس لصار كلُّ منحٍ منقوصٍ منحاً شاملاً.
  test('وعلَمٌ بلا نطاقٍ لا يقرأ', async () => {
    await assertFails(read('obs', claims({ perms: { vds: true } })));
  });

  test('ونطاقٌ في إدارةٍ أخرى لا يقرأ', async () => {
    await assertFails(read('obs', claims({ perms: { vds: true }, scopes: { vds: [OTHER] } })));
  });

  test('ونطاقُ الكلّ يقرأ', async () => {
    await assertSucceeds(read('obs', claims({ perms: { vds: true }, scopes: { vds: '*' } })));
  });
});

describe('والكتابةُ باسم صاحبها وليومها', () => {
  const create = (uid, c, data) =>
    env.authenticatedContext(uid, c).firestore()
      .collection('dailyStatuses').doc(`${uid}_${TODAY}`).set(data);

  test('الموظّفُ يسجّل حالتَه', async () => {
    await assertSucceeds(create('newbie', claims(), { ...statusDoc('newbie') }));
  });

  // ــ ولولا هذا لَكتب موظّفٌ حضوراً لزميلٍ لم يحضر ــ
  test('ولا يكتب باسم غيره', async () => {
    await assertFails(create('faker', claims(), { ...statusDoc('emp') }));
  });

  test('وسجلٌّ بلا يومٍ يُردّ', async () => {
    const doc = { ...statusDoc('newbie'), dayKey: '' };
    await assertFails(create('newbie', claims(), doc));
  });

  // ــ ولا يُختلق سجلٌّ يبدو مُصحَّحاً ــ
  //
  // فلو قُبل `correctedByUid` من العميل لَكتب الموظّفُ سجلّاً يقول إنّ
  // مديرَه صحّحه — وهو توقيعٌ باسم غيره.
  test('ولا يَدّعي أنّ مسؤولاً صحّحه', async () => {
    const doc = { ...statusDoc('newbie'), correctedByUid: 'mgr' };
    await assertFails(create('newbie', claims(), doc));
  });

  test('والمستخدمُ التنفيذيُّ لا يسجّل — يرى ولا يغيّر', async () => {
    await assertFails(create('exec', claims({ role: 'executiveViewer' }), statusDoc('exec')));
  });
});

describe('والتصحيحُ لا يمرّ من العميل', () => {
  const update = (uid, c) =>
    env.authenticatedContext(uid, c).firestore()
      .collection('dailyStatuses').doc(`emp_${TODAY}`).update({ typeName: 'إجازة دورية' });

  test('صاحبُ السجلّ لا يصحّحه', async () => {
    await assertFails(update('emp', claims()));
  });

  test('ورئيسُ القسم لا يصحّحه من هنا — بل من الدالّة', async () => {
    await assertFails(update('head', claims({ hs: [SECTION] })));
  });

  test('ومديرُ الإدارة كذلك', async () => {
    await assertFails(update('mgr', claims({ role: 'departmentManager' })));
  });

  // ــ ومسؤولُ النظام كذلك، وهو المقصود ــ
  //
  // كلُّ تصحيحٍ يجب أن يكتب أثرَه في `auditLog` في المعاملة نفسِها، وذلك لا
  // يقع إلا في `correctStatus`. ولو فُتحت هنا لمسؤول النظام لَصار أيسرُ
  // الطريقين هو الذي لا يترك أثراً.
  test('ومسؤولُ النظام لا يصحّح من العميل', async () => {
    await assertFails(update('adm', claims({ role: 'systemAdmin' })));
  });
});

describe('والسجلُّ يُصحَّح ولا يُمحى', () => {
  const remove = (uid, c) =>
    env.authenticatedContext(uid, c).firestore()
      .collection('dailyStatuses').doc(`emp_${TODAY}`).delete();

  test('صاحبُه لا يمحوه', async () => {
    await assertFails(remove('emp', claims()));
  });

  test('ومديرُ إدارته لا يمحوه', async () => {
    await assertFails(remove('mgr', claims({ role: 'departmentManager' })));
  });

  test('ومسؤولُ النظام وحدَه يمحوه', async () => {
    await assertSucceeds(remove('adm', claims({ role: 'systemAdmin' })));
  });
});

describe('ورئاسةُ القسم لا تُكتب من العميل', () => {
  const setHead = (uid, c, value) =>
    env.authenticatedContext(uid, c).firestore()
      .collection('sections').doc(SECTION).update({ headUid: value });

  // ــ وهذا هو الدرسُ المدفوعُ ثمنُه في `mtd` و`bla` ــ
  //
  // كتابةُ `headUid` من الشاشة لا تختم بطاقةً، فتبقى بطاقةُ الرئيس الجديد
  // بلا المفتاح `hs` حتى ينتهي أجلُ رمزه — يرى شاشةً فارغةً ولا شيء يفسّر
  // له. فالبابُ `setSectionHead` وحدها: تكتب ثمّ تختم.
  test('مديرُ الإدارة لا يعيّن رئيسَ قسمه من هنا', async () => {
    await assertFails(setHead('mgr', claims({ role: 'departmentManager' }), 'someone'));
  });

  test('ومسؤولُ النظام كذلك', async () => {
    await assertFails(setHead('adm', claims({ role: 'systemAdmin' }), 'someone'));
  });

  test('وعزلُ الرئيس من هنا مردودٌ كتعيينه', async () => {
    await assertFails(setHead('adm', claims({ role: 'systemAdmin' }), ''));
  });

  // ولا يمرّ ما سبق لأنّ تعديلَ القسم كلَّه مردود: ما عدا الرئاسةَ يُقبل.
  test('بينما اسمُ القسم يُعدَّل كما كان', async () => {
    await assertSucceeds(
      env.authenticatedContext('mgr', claims({ role: 'departmentManager' })).firestore()
        .collection('sections').doc(SECTION).update({ name: 'قسم العقود والتوثيق' }),
    );
  });

  test('وقسمٌ يُنشأ برئيسٍ مردود', async () => {
    await assertFails(
      env.authenticatedContext('mgr', claims({ role: 'departmentManager' })).firestore()
        .collection('sections').doc('s-new')
        .set({ departmentId: DEPT, name: 'قسمٌ جديد', headUid: 'mgr' }),
    );
  });

  test('وقسمٌ يُنشأ بلا رئيسٍ يُقبل', async () => {
    await assertSucceeds(
      env.authenticatedContext('mgr', claims({ role: 'departmentManager' })).firestore()
        .collection('sections').doc('s-new2')
        .set({ departmentId: DEPT, name: 'قسمٌ جديد' }),
    );
  });
});
