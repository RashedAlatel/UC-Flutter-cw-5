// دليلُ الإجراءات على الخادم: من يقرأ، ومن **لا** يكتب.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **القراءةُ صلاحيةٌ تُمنح، لا حقٌّ لكل معتمَد.** الدليلُ يصف كيف تسير
//     أعمالُ الوزارة، فليس كلُّ ما فيه لكل من دخل المنصة. ومغلقٌ حتى يمنح
//     مسؤولُ النظام — فلا يظهر لأحد يوم النشر.
//
// (٢) **ومن يحرّر يقرأ.** ولو افترق الشرطان لَرأى من مُنح التحريرَ وحدَه
//     شاشةً فارغةً يظنّها عطلاً، أو رأى القائمةَ وردَّه الخادمُ عند الفتح —
//     وهو العطلُ الذي تكرّر في هذه المنصة مرّتين.
//
// (٣) **والكتابةُ مغلقةٌ للجميع، ولمسؤول النظام كذلك.** فكلُّ حفظٍ يجب أن
//     يحفظ صورةَ ما كان قبله في المعاملة نفسِها، وذلك لا يقع إلا في
//     `saveProcedure`. ولو فُتحت الكتابةُ هنا لأمكن أن تُكتب نسخةٌ جديدة
//     بلا صورةٍ لسابقتها، فيضيع ما وُعد بحفظه ولا سبيل إلى استرجاعه.
import assert from 'node:assert/strict';
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';

const DEPT = 'd-justice';

let env;

const claims = (uid, { role = 'employee', approved = true, perms = {} } = {}) => ({
  approved,
  role,
  departmentId: DEPT,
  departmentIds: role === 'departmentManager' ? [DEPT] : [],
  perms,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('procedures').doc('pr1').set({
      title: 'توثيق عقد',
      summary: 'من الطلب إلى التوقيع',
      departmentId: DEPT,
      isActive: true,
      version: 2,
      steps: [{ title: 'استلام الطلب', ownerTitle: 'مدير إدارة العقود' }],
    });
    await db.collection('procedureVersions').doc('v1').set({
      procedureId: 'pr1',
      versionNumber: 1,
      savedByName: 'مدير',
      note: 'أول تحديث',
      snapshot: { title: 'توثيق عقد', version: 1, steps: [] },
    });
  });
});

const asUser = (uid, opts) =>
  env.authenticatedContext(uid, claims(uid, opts)).firestore();

const readProcedure = (db) => db.collection('procedures').doc('pr1').get();
const readVersion = (db) => db.collection('procedureVersions').doc('v1').get();

describe('من يقرأ دليل الإجراءات', () => {
  test('من مُنح vpc', async () => {
    await assertSucceeds(readProcedure(asUser('u-1', { perms: { vpc: true } })));
  });

  // ــ ومن يحرّر يقرأ ــ
  //
  // فمن مُنح التحريرَ وحدَه لا يُترك أمام شاشةٍ فارغةٍ يظنّها عطلاً.
  test('ومن مُنح epc وحدَها', async () => {
    await assertSucceeds(readProcedure(asUser('u-2', { perms: { epc: true } })));
  });

  test('ومسؤولُ النظام بلا مفتاح', async () => {
    await assertSucceeds(readProcedure(asUser('u-admin', { role: 'systemAdmin' })));
  });

  // ــ ومغلقٌ حتى يُمنح ــ
  //
  // وهذا هو ما قرّرتَه: لا يراه أحدٌ يوم النشر حتى تفتحه.
  test('ولا يقرؤه معتمَدٌ بلا مفتاح', async () => {
    await assertFails(readProcedure(asUser('u-3')));
  });

  // والتنفيذيُّ يطّلع على كل شيء في المنصة — إلا ما بابُه صلاحيةٌ تُمنح.
  // ولو استُثني هنا لَصار الدليلُ مفتوحاً لدورٍ بحكم دورِه، وهو خلافُ ما
  // طُلب: «صلاحيةٌ يمنحها مسؤول النظام».
  test('ولا المستخدمُ التنفيذي بحكم دورِه', async () => {
    await assertFails(readProcedure(asUser('u-v', { role: 'executiveViewer' })));
  });

  test('ولا مديرُ الإدارة بحكم دورِه', async () => {
    await assertFails(readProcedure(asUser('u-head', { role: 'departmentManager' })));
  });

  // حسابٌ لم يُعتمد تسجيلُه ليس مستخدماً بعد، ولو حمل مفتاحاً بالخطأ.
  test('ولا من لم يُعتمد ولو حمل المفتاح', async () => {
    await assertFails(
      readProcedure(asUser('u-p', { approved: false, perms: { vpc: true } })),
    );
  });

  // ــ ولا مسؤولُ نظامٍ لم يُعتمد حسابُه ــ
  //
  // وهذا الحدُّ **لا يحرسه `isApproved()` في `canReadProcedures`**: قِستُ
  // فظننتُه هو، ثم نجت الطفرةُ بعد أن أضفتُ هذا الاختبار — فتبيّن أنّ
  // الفروعَ الثلاثة كلَّها تفحص الاعتمادَ في أجسامها (`isAdmin()` هي
  // `isApproved() && role() == 'systemAdmin'`، و`perm()` تبدأ به). فالشرطُ
  // في رأس الدالّة مضاعفٌ يقول المقصود ولا يزيد حراسة.
  //
  // ويبقى الاختبارُ لأنّه يقيس الحدَّ نفسَه لا سطرَه: من لم يُعتمد لا يقرأ
  // الدليل، أينما فُرض ذلك. ولو نُقل يوماً إلى فرعٍ لا يفحصه لَسقط هنا.
  test('ولا مسؤولُ نظامٍ لم يُعتمد حسابُه', async () => {
    await assertFails(
      readProcedure(asUser('u-a', { role: 'systemAdmin', approved: false })),
    );
    await assertFails(
      readVersion(asUser('u-a', { role: 'systemAdmin', approved: false })),
    );
  });
});

describe('والنسخُ السابقة تُقرأ بما يُقرأ به الإجراء', () => {
  test('من مُنح vpc يقرأ النسخة', async () => {
    await assertSucceeds(readVersion(asUser('u-1', { perms: { vpc: true } })));
  });

  test('ومن مُنح epc كذلك', async () => {
    await assertSucceeds(readVersion(asUser('u-2', { perms: { epc: true } })));
  });

  // نسخةٌ محجوبةٌ عمّن يقرأ الإجراء حجبٌ بلا معنى: هي هو، في يومٍ سابق.
  test('ولا يقرؤها من لا يقرأ الإجراء', async () => {
    await assertFails(readVersion(asUser('u-3')));
  });
});

describe('والكتابةُ لا تقع من العميل — البابُ واحد', () => {
  const write = (db) =>
    db.collection('procedures').doc('pr1').update({ title: 'عنوانٌ آخر' });
  const create = (db) =>
    db.collection('procedures').doc('pr2').set({ title: 'إجراءٌ جديد', version: 1 });
  const remove = (db) => db.collection('procedures').doc('pr1').delete();

  // ــ وهذا هو الحدُّ الذي يحفظ النسخ ــ
  //
  // كلُّ حفظٍ يكتب صورةَ ما كان قبله في المعاملة نفسِها، وذلك في
  // `saveProcedure` وحدها. فلو مرّت كتابةٌ من هنا لضاعت صورةٌ وُعد بحفظها.
  test('ولا يكتبها مسؤولُ النظام نفسُه', async () => {
    const db = asUser('u-admin', { role: 'systemAdmin' });
    await assertFails(write(db));
    await assertFails(create(db));
    await assertFails(remove(db));
  });

  test('ولا من مُنح epc', async () => {
    const db = asUser('u-2', { perms: { epc: true, vpc: true } });
    await assertFails(write(db));
    await assertFails(create(db));
  });

  test('ولا يُحذف إجراءٌ من العميل — الأرشفةُ بابُها الدالّة', async () => {
    await assertFails(remove(asUser('u-2', { perms: { epc: true } })));
  });

  test('ولا تُكتب نسخةٌ ولا تُمحى', async () => {
    const db = asUser('u-admin', { role: 'systemAdmin' });
    await assertFails(
      db.collection('procedureVersions').doc('v2').set({ procedureId: 'pr1', versionNumber: 9 }),
    );
    await assertFails(db.collection('procedureVersions').doc('v1').delete());
    await assertFails(
      db.collection('procedureVersions').doc('v1').update({ versionNumber: 99 }),
    );
  });
});

// ــ ومفتاحُ التحرير ليس مفتاحَ بابٍ آخر ــ
//
// فصلاحيةٌ تُمنح لتحرير دليلٍ لا يجوز أن تفتح شيئاً في المشاريع أو
// المستخدمين. وهي قاعدةٌ عامّةٌ في هذه المنصة تُقاس عند كل مفتاحٍ جديد.
describe('و«epc» لا تفتح باباً غير الدليل', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('projects').doc('p1').set({
        departmentId: DEPT,
        name: 'مشروع',
        managerUids: [],
        executorUids: [],
      });
    });
  });

  test('لا تعدّل مشروعاً', async () => {
    const db = asUser('u-2', { perms: { epc: true, vpc: true } });
    await assertFails(db.collection('projects').doc('p1').update({ name: 'اسمٌ آخر' }));
  });

  test('ولا تعدّل مستخدماً', async () => {
    const db = asUser('u-2', { perms: { epc: true, vpc: true } });
    await assertFails(db.collection('users').doc('u-3').update({ role: 'systemAdmin' }));
  });

  test('ولا تكتب في إعدادات الصلاحيات', async () => {
    const db = asUser('u-2', { perms: { epc: true, vpc: true } });
    await assertFails(
      db.collection('settings').doc('rolePermissions').set({ employee: ['epc'] }),
    );
  });
});

// وقاعدةُ الإجراءات لا تُقرأ من مجموعةٍ أخرى بالخطأ: اختبارٌ يُثبت أنّ
// الاسمَ الذي تحرسه القاعدةُ هو الاسمُ الذي يكتبه العميل.
test('واسمُ المجموعتين كما تكتبهما المنصة', () => {
  const rules = readFileSync('../firestore.rules', 'utf8');
  assert.ok(rules.includes('match /procedures/{id}'));
  assert.ok(rules.includes('match /procedureVersions/{id}'));
});
