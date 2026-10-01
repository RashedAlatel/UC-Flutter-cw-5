// خططُ الأسبوع على الخادم: من يضعها، ومن يقرؤها، وما لا يُمحى.
//
// ــــ القرارُ الذي تحرسه ــــ
//
// **الخطّةُ يضعها المسؤولُ لا الموظّف**: هي قرارُ توجيه — «هذا ما أريد أن
// تقضي فيه أسبوعك» — ومن يضعها لنفسه لم يُوجَّه. وهذا يقلب القاعدةَ
// المعتادة في المنصة: في الحالة اليوميّة **الموظّفُ يكتب والمسؤولُ يصحّح**،
// وهنا العكسُ تماماً.
//
// ــــ وما يُقاس ــــ
//
// (١) الموظّفُ يقرأ خطّتَه **ولا يكتبها**.
// (٢) ولا يقرأ خطّةَ زميله — هي بيانٌ عمّا يُتوقَّع منه.
// (٣) و**الحدُّ ثلاثةٌ يُفرض على الخادم**: حدٌّ في الشاشة وحدَها ليس حدّاً.
// (٤) و**خطّةُ أسبوعٍ مضى لا تُمحى**: التاريخُ يُحفظ، وبلا ذلك تستحيل
//     المراجعةُ التي وُضعت الخطّةُ لأجلها.
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
const WEEK = '2026-09-20';

let env;

const claims = (
  { role = 'employee', approved = true, hs = [], depts = null } = {},
) => ({
  approved,
  role,
  departmentId: DEPT,
  departmentIds: depts ?? (role === 'departmentManager' ? [DEPT] : []),
  perms: {},
  scopes: {},
  hs,
});

const plan = (uid = 'emp', items = 1) => ({
  uid,
  userName: 'موظّف',
  departmentId: DEPT,
  sectionId: SECTION,
  weekKey: WEEK,
  items: Array.from({ length: items }, (_, i) => ({
    title: `أولويّة ${i + 1}`,
    expectedOutcome: 'نتيجةٌ متوقَّعة',
    status: 'planned',
  })),
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
    projectId: 'rules-test-weekly-plan',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('weeklyPlans').doc(`emp_${WEEK}`).set(plan());
  });
});

const db = (uid, c) => env.authenticatedContext(uid, c).firestore();
const read = (uid, c) => db(uid, c).collection('weeklyPlans').doc(`emp_${WEEK}`).get();

describe('من يقرأ خطّةَ موظّف', () => {
  test('صاحبُها يقرؤها', async () => {
    await assertSucceeds(read('emp', claims()));
  });

  // ــ ولا يقرؤها زميلُه ــ
  test('وزميلُه في القسم نفسِه لا يقرؤها', async () => {
    await assertFails(read('peer', claims()));
  });

  test('ورئيسُ قسمه يقرؤها', async () => {
    await assertSucceeds(read('head', claims({ hs: [SECTION] })));
  });

  test('ومديرُ إدارته يقرؤها', async () => {
    await assertSucceeds(read('mgr', claims({ role: 'departmentManager' })));
  });

  test('ومديرُ إدارةٍ أخرى لا يقرؤها', async () => {
    await assertFails(read('mgr2', claims({ role: 'departmentManager', depts: [OTHER] })));
  });

  test('ومسؤولُ النظام يقرؤها', async () => {
    await assertSucceeds(read('adm', claims({ role: 'systemAdmin' })));
  });
});

describe('والمسؤولُ يكتبها لا الموظّف', () => {
  const create = (uid, c, data) =>
    db(uid, c).collection('weeklyPlans').doc(`newbie_${WEEK}`).set(data);

  // ــ وهذا هو القرارُ الذي يقلب القاعدةَ المعتادة ــ
  test('الموظّفُ لا يضع خطّةَ نفسِه', async () => {
    await assertFails(create('newbie', claims(), plan('newbie')));
  });

  test('ومديرُ الإدارة يضعها', async () => {
    await assertSucceeds(
      create('mgr', claims({ role: 'departmentManager' }), plan('newbie')),
    );
  });

  test('ورئيسُ القسم يضعها', async () => {
    await assertSucceeds(create('head', claims({ hs: [SECTION] }), plan('newbie')));
  });

  test('ومديرُ إدارةٍ أخرى لا يضعها', async () => {
    await assertFails(
      create('mgr2', claims({ role: 'departmentManager', depts: [OTHER] }), plan('newbie')),
    );
  });

  // ــ وهذه الحالةُ كُتبت لأنّ طفرةً نجت ــ
  //
  // كان الاختبارُ يعطي التنفيذيَّ نطاقاً فارغاً، فيُردّ لأنّه لا يدير شيئاً
  // **لا لأنّه تنفيذيّ**. فنُزع شرطُ `!isExecutive()` ومرّ صامتاً.
  //
  // والحالُ الحقيقيّة: تنفيذيٌّ **يرأس قسماً** — وهي واقعةٌ ممكنةٌ في
  // الوزارة. فيُردّ بحكم دوره وحدَه: «يرى كلَّ شيءٍ ولا يغيّر شيئاً»،
  // قاعدةٌ قائمةٌ في المنصة كلِّها.
  test('والتنفيذيُّ لا يوجّه ولو رأس قسماً', async () => {
    await assertFails(
      create('exec', claims({ role: 'executiveViewer', hs: [SECTION] }), plan('newbie')),
    );
  });

  test('بينما يقرأ الخططَ كما يقرأ كلَّ شيء', async () => {
    await assertSucceeds(read('exec', claims({ role: 'executiveViewer' })));
  });

  test('وخطّةٌ بلا أسبوعٍ تُردّ', async () => {
    const bad = { ...plan('newbie'), weekKey: '' };
    await assertFails(create('mgr', claims({ role: 'departmentManager' }), bad));
  });
});

describe('والحدُّ ثلاثةٌ يُفرض على الخادم', () => {
  const create = (uid, c, items) =>
    db(uid, c).collection('weeklyPlans').doc(`newbie_${WEEK}`).set(plan('newbie', items));

  test('ثلاثةُ بنودٍ تُقبل', async () => {
    await assertSucceeds(create('mgr', claims({ role: 'departmentManager' }), 3));
  });

  // ــ والحدُّ هو الأداة ــ
  //
  // خطّةٌ بعشرة بنودٍ ليست خطّة: هي قائمةُ أعمالٍ أخرى. والحدُّ يُجبر
  // المديرَ على أن يقرّر ما الذي يهمّ فعلاً هذا الأسبوع.
  test('والرابعُ يُردّ', async () => {
    await assertFails(create('mgr', claims({ role: 'departmentManager' }), 4));
  });

  test('ولا يُتجاوز بالتعديل بعد الإنشاء', async () => {
    await assertFails(
      db('mgr', claims({ role: 'departmentManager' }))
        .collection('weeklyPlans').doc(`emp_${WEEK}`)
        .update({ items: plan('emp', 5).items }),
    );
  });
});

describe('وصاحبُ الخطّة وأسبوعُها لا يُبدَّلان', () => {
  const update = (patch) =>
    db('mgr', claims({ role: 'departmentManager' }))
      .collection('weeklyPlans').doc(`emp_${WEEK}`).update(patch);

  test('تبديلُ صاحبها مردود', async () => {
    await assertFails(update({ uid: 'someone-else' }));
  });

  test('وتبديلُ أسبوعها مردود', async () => {
    await assertFails(update({ weekKey: '2026-09-27' }));
  });

  test('بينما تعديلُ بنودها يُقبل', async () => {
    await assertSucceeds(update({ items: plan('emp', 2).items }));
  });
});

describe('وخطّةُ أسبوعٍ مضى لا تُمحى', () => {
  const remove = (uid, c) =>
    db(uid, c).collection('weeklyPlans').doc(`emp_${WEEK}`).delete();

  test('صاحبُها لا يمحوها', async () => {
    await assertFails(remove('emp', claims()));
  });

  test('ومديرُ إدارته لا يمحوها', async () => {
    await assertFails(remove('mgr', claims({ role: 'departmentManager' })));
  });

  test('ورئيسُ قسمه كذلك', async () => {
    await assertFails(remove('head', claims({ hs: [SECTION] })));
  });

  test('ومسؤولُ النظام وحدَه يمحو ما كُتب بالخطأ', async () => {
    await assertSucceeds(remove('adm', claims({ role: 'systemAdmin' })));
  });
});
