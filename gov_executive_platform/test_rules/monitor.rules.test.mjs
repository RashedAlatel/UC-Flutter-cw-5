// دورُ «مراقب»: يرى من يُسمَّون له، **ولا يكتب شيئاً**.
//
// ــــ وما يُقاس هنا، ولماذا كلٌّ منه ــــ
//
// (١) **ما يراه يُقاس، وما لا يراه يُقاس معه.** «المراقبُ يرى مشروعَ من
//     يراقبه» وحدَها تمرّ على دورٍ يرى **كلَّ** المشاريع. فالذي يُثبت أنّ
//     الدورَ مقيَّدٌ هو أنّه **لا يرى** مشروعاً ليس فيه أحدٌ من قائمته.
//
// (٢) **ولا يكتب.** وأخطرُ طريقٍ إلى الكتابة ليس دورَه بل **عضويّتَه**:
//     `isMemberOfRealProject` تفتح المهامَّ والمخاطرَ والبلاغاتِ والتحديثاتِ
//     اليومية لكلّ عضوٍ في مشروع. وقد نُسي هذا في أربعةِ مواضعَ للمستخدم
//     التنفيذيّ حتى كُشف. فالمراقبُ يُقاس **وهو عضوٌ في المشروع** — وإلا
//     قِيس الحالُ السهلة وتُرك البابُ الذي يُفتح فعلاً.
//
// (٣) **والقائمةُ من البطاقة لا من السجلّ.** `watchedUids` على مستند
//     المستخدم لا تُكتب من العميل، لأنّ كتابتَها لا تختم بطاقةً — وهو عينُ
//     العطل الذي كلّف المنصةَ `mtd` و`bla`. فيُقاس أنّ الكتابةَ تُردّ.
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
const WEEK = '2026-W38';

/** من يُراقَب، ومن لا يُراقَب — والثاني هو المقياس الحقيقي. */
const SEEN = 'u-seen';
const UNSEEN = 'u-unseen';
const MON = 'u-monitor';

let env;

const claims = ({ role = 'employee', approved = true, perms = {}, w = null, dept = DEPT } = {}) => {
  const c = {
    approved,
    role,
    departmentId: dept,
    departmentIds: role === 'departmentManager' ? [dept] : [],
    perms,
    scopes: {},
    hs: [],
  };
  if (w !== null) c.w = w;
  return c;
};

/** بطاقةُ المراقب — ودائماً بإدارةٍ **أخرى**. */
//
// ولماذا إدارةٌ أخرى؟ لأنّ `isMyDeptAny` تفتح للموظّف مشاريعَ إدارته. فلو
// جُعل المراقبُ في إدارة المشروع لَرآه بحكم إدارته، ولَنجحت الاختباراتُ
// كلُّها على قواعدَ لم تتغيّر — ولَما قاست قائمةُ المراقَبة شيئاً.
const monitor = (w) => claims({ role: 'monitor', w, dept: OTHER });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-monitor',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    // `ctx.firestore()` **مرّةً واحدة** في هذه الدالّة — ونداؤها مرّتين
    // يرمي «Firestore has already been started» فتحمرّ الملفّةُ كلُّها.
    const db = ctx.firestore();

    // مشروعٌ يديره المراقَب، وآخرُ ينفّذه، وثالثٌ لا شأن له به.
    await db.collection('projects').doc('p-managed').set({
      name: 'مشروعٌ يديره المراقَب', departmentId: DEPT,
      managerUid: SEEN, managerUids: [SEEN], executorUids: [],
    });
    await db.collection('projects').doc('p-executing').set({
      name: 'مشروعٌ ينفّذه المراقَب', departmentId: DEPT,
      managerUid: UNSEEN, managerUids: [UNSEEN], executorUids: [SEEN],
    });
    await db.collection('projects').doc('p-foreign').set({
      name: 'مشروعٌ لا شأن للمراقَب به', departmentId: DEPT,
      managerUid: UNSEEN, managerUids: [UNSEEN], executorUids: [UNSEEN],
    });

    // ومهمّةٌ ومخاطرُ وبلاغٌ وتحديثٌ على المشروع الذي يديره المراقَب.
    for (const [path, extra] of [
      ['tasks/t-seen', { title: 'مهمّة' }],
      ['risks/r-seen', { title: 'خطر' }],
      ['blockers/b-seen', { title: 'معوّق' }],
      ['dailyUpdates/u-seen', { text: 'تحديث' }],
    ]) {
      await db.doc(path).set({
        projectId: 'p-managed', departmentId: DEPT,
        managerUid: SEEN, managerUids: [SEEN], executorUids: [],
        ...extra,
      });
    }
    // ونظائرُها على المشروع الأجنبيّ — فالغيابُ يُقاس كما يُقاس الحضور.
    await db.doc('tasks/t-foreign').set({
      projectId: 'p-foreign', departmentId: DEPT,
      managerUid: UNSEEN, managerUids: [UNSEEN], executorUids: [UNSEEN], title: 'مهمّة',
    });

    // أعمالٌ: واحدٌ على المراقَب، وواحدٌ على غيره.
    await db.doc('works/w-seen').set({
      departmentId: DEPT, assigneeUid: SEEN, title: 'عمل',
    });
    await db.doc('works/w-unseen').set({
      departmentId: DEPT, assigneeUid: UNSEEN, title: 'عمل',
    });

    // وتحديثاتُ العمل: نظيرُها، فقاعدتُها صورةٌ من قاعدة `works`.
    await db.doc('workUpdates/wu-seen').set({
      departmentId: DEPT, assigneeUid: SEEN, workId: 'w-seen', text: 'تحديثُ عمل',
    });
    await db.doc('workUpdates/wu-unseen').set({
      departmentId: DEPT, assigneeUid: UNSEEN, workId: 'w-unseen', text: 'تحديثُ عمل',
    });
    // حالاتٌ يومية وخططٌ أسبوعية للاثنين.
    for (const uid of [SEEN, UNSEEN]) {
      await db.doc(`dailyStatuses/${uid}_${TODAY}`).set({
        uid, userName: 'موظّف', departmentId: DEPT, sectionId: SECTION,
        dayKey: TODAY, kind: 'day', typeId: 't-present', typeName: 'حضور',
        toneKey: 'success', correctedByUid: '',
      });
      await db.doc(`weeklyPlans/${uid}_${WEEK}`).set({
        uid, departmentId: DEPT, sectionId: SECTION, weekKey: WEEK, items: [],
      });
    }

    await db.doc(`users/${MON}`).set({
      name: 'مراقب', role: 'monitor', departmentId: OTHER, status: 'approved',
      watchedUids: [SEEN],
    });
  });
});

const asMon = (w = [SEEN]) => env.authenticatedContext(MON, monitor(w)).firestore();
const get = (path, w) => asMon(w).doc(path).get();

describe('ما يراه المراقب', () => {
  test('يرى مشروعاً يديره من يراقبه', async () => {
    await assertSucceeds(get('projects/p-managed'));
  });

  test('ويرى مشروعاً **ينفّذه** من يراقبه — لا المُدارَ وحدَه', async () => {
    await assertSucceeds(get('projects/p-executing'));
  });

  // ــ وهذا هو المقياس: لولاه لمرّ دورٌ يرى كلَّ شيء ــ
  test('ولا يرى مشروعاً ليس فيه أحدٌ من قائمته', async () => {
    await assertFails(get('projects/p-foreign'));
  });

  test('ومن أُفرغت قائمتُه لا يرى شيئاً', async () => {
    await assertFails(get('projects/p-managed', []));
  });

  test('ومن قائمتُه لغيرِ صاحب المشروع لا يراه', async () => {
    await assertFails(get('projects/p-managed', ['u-third']));
  });

  test('ويرى مهامَّ مشروعِ المراقَب ومخاطرَه ومعوّقاتِه وتحديثاتِه', async () => {
    await assertSucceeds(get('tasks/t-seen'));
    await assertSucceeds(get('risks/r-seen'));
    await assertSucceeds(get('blockers/b-seen'));
    await assertSucceeds(get('dailyUpdates/u-seen'));
  });

  test('ولا يرى مهامَّ مشروعٍ أجنبيّ', async () => {
    await assertFails(get('tasks/t-foreign'));
  });

  test('ويرى عملاً مُسنَداً إلى من يراقبه، ولا يرى المُسنَد إلى غيره', async () => {
    await assertSucceeds(get('works/w-seen'));
    await assertFails(get('works/w-unseen'));
  });

  test('ويرى تحديثاتِ عملِ من يراقبه، ولا يرى تحديثاتِ غيره', async () => {
    await assertSucceeds(get('workUpdates/wu-seen'));
    await assertFails(get('workUpdates/wu-unseen'));
  });

  // ــ وهذا ما اختاره صاحبُ المنصّة صراحةً: الحالاتُ بحكم الدور ــ
  //
  // و`vds` لا تُورَّث بدور — قاعدةٌ قائمة. وهذه ليست نقضاً لها: قائمةُ
  // المراقَبة **هي** المنحةُ الفرديّة بعينها، يكتبها مسؤولُ النظام بالاسم
  // ويسحبها، لا نافذةٌ على «كلّ من في إدارة».
  test('ويرى الحالةَ اليومية لمن يراقبه، ولا يرى حالةَ غيره', async () => {
    await assertSucceeds(get(`dailyStatuses/${SEEN}_${TODAY}`));
    await assertFails(get(`dailyStatuses/${UNSEEN}_${TODAY}`));
  });

  test('ويرى خطّتَه الأسبوعية، ولا يرى خطّةَ غيره', async () => {
    await assertSucceeds(get(`weeklyPlans/${SEEN}_${WEEK}`));
    await assertFails(get(`weeklyPlans/${UNSEEN}_${WEEK}`));
  });

  // ــ وبطاقةٌ تحمل `w` لغير مراقبٍ لا تفتح شيئاً ــ
  //
  // و`restampClaims` تختم `w` من `watchedUids` **لكلّ مستخدم** لا للمراقب
  // وحدَه — فحقلٌ بقي على سجلّ من كان مراقباً ثم غُيّر دورُه يصل بطاقتَه.
  // ولولا `isMonitor()` في `isWatching` و`watchesAnyOf` لَفتح ذلك الحقلُ
  // البائدُ نافذةً على من لم يعد يحقّ له. وهو الفرعُ الذي نجا بطفرةٍ أوّلاً
  // لأنّه لم يكن مقيساً.
  test('وبطاقةُ غيرِ المراقب لا تفتح شيئاً وإن حملت `w`', async () => {
    // و`.firestore()` **مرّةً واحدة**: نداؤها مرّتين على السياق نفسِه يرمي
    // «Firestore has already been started» فيحمرّ الاختبارُ بلا أن يقيس.
    const stray = env.authenticatedContext('u-stray', {
      ...claims({ role: 'departmentManager', dept: OTHER }),
      w: [SEEN],
    }).firestore();
    await assertFails(stray.doc('projects/p-managed').get());
    await assertFails(stray.doc(`dailyStatuses/${SEEN}_${TODAY}`).get());
  });

  // ــ ومعرّفٌ فارغٌ في القائمة لا يطابق مستنداً بلا معرّف ــ
  //
  // و`sanitizeWatched` تطرح الفراغَ قبل أن يصل البطاقةَ — فهذا حارسٌ ثانٍ
  // لا أوّل. ولزومُه أنّ البطاقةَ قد تكون خُتمت قبل وجود ذلك التنقيح، أو
  // بطريقٍ إداريٍّ آخر. ولولاه لَفتح معرّفٌ فارغٌ واحدٌ **كلَّ** مستندٍ
  // ناقصِ الحقل دفعةً — وهو عينُ ما نوقش في `isSectionHeadOf`.
  test('ومعرّفٌ فارغٌ في القائمة لا يفتح مستنداً بلا صاحب', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`dailyStatuses/orphan_${TODAY}`).set({
        userName: 'بلا معرّف', departmentId: DEPT, sectionId: SECTION,
        dayKey: TODAY, kind: 'day', typeId: 't-present', typeName: 'حضور',
        toneKey: 'success', correctedByUid: '',
      });
    });
    await assertFails(get(`dailyStatuses/orphan_${TODAY}`, ['']));
  });
});

// ــــ ولا يكتب — وهذا أهمُّ ممّا قبله ــــ
describe('ما لا يكتبه المراقب', () => {
  // والبذرةُ هنا تجعله **عضواً** في المشروع: هو الطريقُ الذي يفتح الكتابةَ
  // بلا صلاحية، وهو الذي نُسي للمستخدم التنفيذيّ في أربعة مواضع.
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('projects').doc('p-managed').set({
        name: 'مشروعٌ يديره المراقَب', departmentId: DEPT,
        managerUid: SEEN, managerUids: [SEEN], executorUids: [MON],
      }, { merge: true });
    });
  });

  const mine = { projectId: 'p-managed', departmentId: DEPT, managerUid: SEEN };

  test('لا يُنشئ مهمّةً في مشروعٍ هو عضوٌ فيه', async () => {
    await assertFails(asMon().collection('tasks').add({ ...mine, title: 'مهمّة' }));
  });

  test('ولا يكتب تحديثاً يومياً فيه', async () => {
    await assertFails(asMon().collection('dailyUpdates').add({ ...mine, text: 'تحديث' }));
  });

  test('ولا يسجّل خطراً', async () => {
    await assertFails(asMon().collection('risks').add({ ...mine, title: 'خطر' }));
  });

  test('ولا يسجّل معوّقاً', async () => {
    await assertFails(asMon().collection('blockers').add({ ...mine, title: 'معوّق' }));
  });

  test('ولا يعدّل مشروعاً يراه', async () => {
    await assertFails(asMon().doc('projects/p-managed').update({ name: 'اسمٌ جديد' }));
  });

  test('ولا يعدّل عملاً يراه', async () => {
    await assertFails(asMon().doc('works/w-seen').update({ title: 'عنوانٌ جديد' }));
  });

  test('ولا يكتب حالةً يوميةً باسم من يراقبه ولا باسم نفسه', async () => {
    const statusOf = (uid) => ({
      uid, userName: 'ـ', departmentId: DEPT, sectionId: SECTION,
      dayKey: TODAY, kind: 'day', typeId: 't-present', typeName: 'حضور',
      toneKey: 'success', correctedByUid: '',
    });
    await assertFails(asMon().doc(`dailyStatuses/${SEEN}_x`).set(statusOf(SEEN)));
    await assertFails(asMon().doc(`dailyStatuses/${MON}_x`).set(statusOf(MON)));
  });
});

// ــــ والقائمةُ لا تُكتب من العميل ــــ
describe('قائمةُ المراقَبة', () => {
  test('لا يوسّع المراقبُ قائمتَه بنفسه', async () => {
    await assertFails(
      asMon().doc(`users/${MON}`).update({ watchedUids: [SEEN, UNSEEN] }),
    );
  });

  // ــ والضابط: الرفضُ عن **مَن** لا عن المستند ــ
  //
  // وكان الضابطُ الأوّل هنا «ولكنّه يعدّل اسمَه» — بُني على ظنٍّ أنّ المرء
  // يعدّل سجلَّه من العميل. وليس كذلك: `allow update: if isAdmin()` تُغلق
  // المستندَ على الجميع، والملفُّ الشخصيُّ يمرّ بدالّةٍ خلفيّةٍ لها قائمةُ
  // حقولٍ مسموحة (`PROFILE_FIELDS = ["name", "sectionId"]`) لا `watchedUids`
  // فيها. فالضابطُ الصحيح أنّ القاعدةَ ليست ميتةً: مسؤولُ النظام يمرّ.
  test('ومسؤولُ النظام يمرّ — فالقاعدةُ ترفض عن شخصٍ لا عن مستند', async () => {
    const admin = env.authenticatedContext('u-admin', claims({ role: 'systemAdmin' }));
    await assertSucceeds(
      admin.firestore().doc(`users/${MON}`).update({ watchedUids: [SEEN, UNSEEN] }),
    );
  });
});
