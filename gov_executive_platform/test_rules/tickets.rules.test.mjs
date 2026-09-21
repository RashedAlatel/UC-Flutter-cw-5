// البلاغاتُ وطلباتُ الخدمة على الخادم: من يقرأ، ومن يفتح، ومن يعالج.
//
// ــــ القرارُ الذي تحرسه ــــ
//
// **كلُّ موظّفٍ معتمدٍ يفتح بلاغَه بنفسه** — لا فنّيُّ الدعم نيابةً عنه.
// فالقاعدةُ تفصل بين طرفين لا دورَ ثالثَ بينهما: **مُبلِّغٌ** يملك بلاغَه،
// و**معالِجٌ** يحمل `htk` فيرى الطابور كلَّه.
//
// ــــ وأخطرُ ما يُقاس هنا ــــ
//
// **أنّ زميلَ المُبلِّغ لا يقرأ بلاغَه.** وهذا خروجٌ مقصودٌ عن `isMyDeptAny`
// — الاصطلاح الغالب في المنصّة — وقد وقع بعينه في `dailyStatuses`: كُتبت
// القاعدةُ بالاصطلاح الغالب فصار كلُّ موظّفٍ يقرأ سجلّاتِ زملائه، ولم
// يمسكها إلا اختبارٌ كهذا.
import assert from 'node:assert/strict';
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const DEPT = 'd-justice';
const OTHER = 'd-finance';
const TICKET = 'tk-1';

let env;

const claims = ({ role = 'employee', approved = true, htk = false, dept = DEPT } = {}) => ({
  approved,
  role,
  departmentId: dept,
  departmentIds: role === 'departmentManager' ? [dept] : [],
  perms: htk ? { htk: true } : {},
  scopes: {},
  hs: [],
});

const stored = (over = {}) => ({
  kind: 'incident',
  title: 'الطابعة لا تعمل',
  description: '',
  category: 'طابعات',
  priority: 'high',
  status: 'open',
  reporterUid: 'rep',
  reporterName: 'مبلِّغ',
  reporterDepartmentId: DEPT,
  assigneeUid: '',
  assigneeName: '',
  createdAt: new Date('2026-05-10T08:00:00Z'),
  firstResponseAt: null,
  resolvedAt: null,
  closedAt: null,
  resolutionNote: '',
  reporterReply: '',
  waitingMs: 0,
  waitingSince: null,
  deletedAt: null,
  deletedBy: null,
  deletedReason: null,
  ...over,
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
    projectId: 'rules-test-tickets',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => { await env.cleanup(); });

const seed = async (over = {}) => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('tickets').doc(TICKET).set(stored(over));
  });
};

beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});

const db = (uid, c) => env.authenticatedContext(uid, c).firestore();
const doc = (uid, c) => db(uid, c).collection('tickets').doc(TICKET);
const read = (uid, c) => doc(uid, c).get();

describe('من يقرأ بلاغاً', () => {
  test('صاحبُه يقرؤه', async () => {
    await assertSucceeds(read('rep', claims()));
  });

  // ــ وهذا هو الاختبارُ الذي وُضع الملفُّ لأجله ــ
  test('وزميلُه في الإدارة نفسِها لا يقرؤه', async () => {
    await assertFails(read('peer', claims()));
  });

  // ــ ولا مديرُ إدارته ــ
  //
  // وهو خروجٌ عن الاصطلاح الغالب بقصد: البلاغُ فيه ما لا يقال للرئيس
  // («كلمةُ مروري ضاعت»)، وليس عملاً أُسنِد من مكتبه حتّى يتابعه.
  test('ولا مديرُ إدارته — البلاغُ ليس عملاً أسنَده', async () => {
    await assertFails(read('mgr', claims({ role: 'departmentManager' })));
  });

  test('ومن أُسنِد إليه يقرؤه', async () => {
    await seed({ assigneeUid: 'tech' });
    await assertSucceeds(read('tech', claims()));
  });

  test('ومكتبُ الخدمة يقرأ الطابورَ كلَّه', async () => {
    await assertSucceeds(read('desk', claims({ htk: true, dept: OTHER })));
  });

  test('ومسؤولُ النظام يقرؤه', async () => {
    await assertSucceeds(read('adm', claims({ role: 'systemAdmin' })));
  });

  test('وغيرُ المعتمد لا يقرأ شيئاً ولو كان هو المُبلِّغ', async () => {
    await assertFails(read('rep', claims({ approved: false })));
  });
});

describe('من يفتح بلاغاً', () => {
  // ــ و`serverTimestamp()` لا `new Date()` ــ
  //
  // القاعدةُ تشترط `createdAt == request.time`. وأوّلُ تشغيلٍ لهذا الملفّ
  // سقط عند هذا بالضبط: كُتب وقتُ جهازِ المُختبِر فرُدّ — وهو الرفضُ
  // الصحيح. فما يكتبه التطبيقُ هو ختمُ الخادم، وهذا ما يُقاس.
  const fresh = (uid, c, over = {}) =>
    db(uid, c).collection('tickets').doc('tk-new').set(
      stored({ reporterUid: uid, createdAt: serverTimestamp(), ...over }),
    );

  test('كلُّ موظّفٍ معتمدٍ يفتح بلاغَه', async () => {
    await assertSucceeds(fresh('anyone', claims()));
  });

  // ــ ولا يفتحه باسم غيره ــ
  test('ولا يفتحه باسم زميله', async () => {
    await assertFails(fresh('anyone', claims(), { reporterUid: 'someone-else' }));
  });

  // ــ وساعةُ المدّة تبدأ من وقت الخادم ــ
  //
  // ولولا هذا الشرطُ لكتب الفاتحُ تاريخاً في الماضي فبدا بلاغُه متجاوزاً
  // للمدّة منذ فتحه، أو في المستقبل فلا ينفد وقتُه أبداً.
  test('ووقتُ الفتح وقتُ الخادم لا وقتُ جهازه', async () => {
    await assertFails(
      fresh('anyone', claims(), { createdAt: new Date('2020-01-01T00:00:00Z') }),
    );
  });

  test('ولا يفتحه مُسنَداً إلى فنّيٍّ من عنده', async () => {
    await assertFails(fresh('anyone', claims(), { assigneeUid: 'tech' }));
  });

  // ــ ولا يفتحه وقد رُدَّ عليه ــ
  //
  // بلاغٌ يُولد بـ`firstResponseAt` مكتوبٍ يبدو مردوداً عليه في صفر دقيقة،
  // فيُفسد رقمَ أوّلِ ردٍّ للفريق كلِّه.
  test('ولا يفتحه وقد رُدَّ عليه أصلاً', async () => {
    await assertFails(fresh('anyone', claims(), { firstResponseAt: new Date() }));
  });

  test('ولا يفتحه محلولاً', async () => {
    await assertFails(fresh('anyone', claims(), { status: 'resolved' }));
  });

  test('ولا يفتحه وقد انتظر ساعاتٍ', async () => {
    await assertFails(fresh('anyone', claims(), { waitingMs: 99999 }));
  });

  test('وغيرُ المعتمد لا يفتح شيئاً', async () => {
    await assertFails(fresh('anyone', claims({ approved: false })));
  });
});

describe('من يعالج بلاغاً', () => {
  const patch = (uid, c, data) => doc(uid, c).update(data);

  test('مكتبُ الخدمة يُسنِد ويردّ', async () => {
    await assertSucceeds(patch('desk', claims({ htk: true }), {
      assigneeUid: 'tech', assigneeName: 'فنّيّ',
      status: 'inProgress', firstResponseAt: new Date(),
    }));
  });

  test('والمُبلِّغُ لا يُسنِد بلاغَه لمن يشاء', async () => {
    await assertFails(patch('rep', claims(), { assigneeUid: 'tech' }));
  });

  test('ولا يرفع أولويّتَه', async () => {
    await assertFails(patch('rep', claims(), { priority: 'critical' }));
  });

  test('ولا يُعلنه محلولاً', async () => {
    await assertFails(patch('rep', claims(), { status: 'resolved', resolvedAt: new Date() }));
  });

  test('وزميلٌ لا يمسّه', async () => {
    await assertFails(patch('peer', claims(), { status: 'inProgress' }));
  });
});

describe('جوابُ المستفيد — البابُ الوحيد لغير المعالِج', () => {
  const patch = (uid, c, data) => doc(uid, c).update(data);

  test('يجيب حين يكون الدورُ عليه', async () => {
    await seed({ status: 'waitingOnReporter', waitingSince: new Date('2026-05-10T09:00:00Z') });
    await assertSucceeds(patch('rep', claims(), {
      reporterReply: 'جرّبتُ فلم ينجح',
      status: 'inProgress',
      waitingMs: 3600000,
      waitingSince: null,
    }));
  });

  // ــ ولا يُفتح البابُ إلا حين يكون الدورُ عليه فعلاً ــ
  test('ولا يجيب وبلاغُه قيد المعالجة — الدورُ ليس عليه', async () => {
    await seed({ status: 'inProgress' });
    await assertFails(patch('rep', claims(), {
      reporterReply: 'أيُّ شيء', status: 'inProgress',
    }));
  });

  test('ولا يُهرّب حقلاً خامساً مع جوابه', async () => {
    await seed({ status: 'waitingOnReporter' });
    await assertFails(patch('rep', claims(), {
      reporterReply: 'جواب', status: 'inProgress', priority: 'critical',
    }));
  });

  test('ولا ينقله إلى حالةٍ يختارها', async () => {
    await seed({ status: 'waitingOnReporter' });
    await assertFails(patch('rep', claims(), {
      reporterReply: 'جواب', status: 'closed',
    }));
  });

  // ــ ومدّةُ الانتظار تزيد ولا تنقص ــ
  //
  // إنقاصُها يُظهر بلاغاً متجاوزاً كأنّه ضمن المهلة، وهو الاتجاهُ الوحيد
  // الذي يُخفي تقصيراً. ويُقاس على المعالِج كما يُقاس على المُبلِّغ.
  test('ولا يُنقص المُبلِّغُ مدّةَ الانتظار', async () => {
    await seed({ status: 'waitingOnReporter', waitingMs: 7200000 });
    await assertFails(patch('rep', claims(), {
      reporterReply: 'جواب', status: 'inProgress', waitingMs: 0,
    }));
  });

  test('ولا يُنقصها مكتبُ الخدمة نفسُه', async () => {
    await seed({ waitingMs: 7200000 });
    await assertFails(patch('desk', claims({ htk: true }), { waitingMs: 60000 }));
  });
});

describe('الأصلُ لا يُمسّ بعد الفتح', () => {
  const patch = (uid, c, data) => doc(uid, c).update(data);

  // ــ `reporterUid` مفتاحُ القراءة ــ
  //
  // من بدّله نقل بلاغَ غيره إلى نفسه، أو أخفى بلاغاً عن صاحبه.
  test('ولا يبدّل مكتبُ الخدمة صاحبَ البلاغ', async () => {
    await assertFails(patch('desk', claims({ htk: true }), { reporterUid: 'desk' }));
  });

  // ــ و`createdAt` مبدأُ ساعة المدّة ــ
  test('ولا يؤخّر مكتبُ الخدمة وقتَ الفتح فيُخفي تجاوزاً', async () => {
    await assertFails(patch('desk', claims({ htk: true }), { createdAt: new Date() }));
  });
});

describe('الحذفُ والاستعادة', () => {
  const patch = (uid, c, data) => doc(uid, c).update(data);

  test('مكتبُ الخدمة يحذف حذفاً منطقيّاً باسمه', async () => {
    await assertSucceeds(patch('desk', claims({ htk: true }), {
      deletedAt: new Date(), deletedBy: 'desk', deletedReason: 'مكرّر',
    }));
  });

  test('ولا يحذف باسم غيره', async () => {
    await assertFails(patch('desk', claims({ htk: true }), {
      deletedAt: new Date(), deletedBy: 'someone', deletedReason: 'مكرّر',
    }));
  });

  test('والمُبلِّغُ لا يحذف بلاغَه', async () => {
    await assertFails(patch('rep', claims(), { deletedAt: new Date(), deletedBy: 'rep' }));
  });

  // ــ والمحذوفُ مجمَّد ــ
  //
  // وإلا صار الحذفُ باباً لتعديلٍ لا يراه أحد: المحذوفُ لا يُعرض في شيء.
  test('والمحذوفُ لا يُعدَّل عليه شيء', async () => {
    await seed({ deletedAt: new Date('2026-05-11T08:00:00Z'), deletedBy: 'desk' });
    await assertFails(patch('desk', claims({ htk: true }), { status: 'closed' }));
  });

  test('والاستعادةُ لمسؤول النظام وحدَه', async () => {
    await seed({ deletedAt: new Date('2026-05-11T08:00:00Z'), deletedBy: 'desk' });
    await assertFails(patch('desk', claims({ htk: true }), { deletedAt: null }));
    await assertSucceeds(patch('adm', claims({ role: 'systemAdmin' }), {
      deletedAt: null, deletedBy: null, deletedReason: null,
    }));
  });

  test('والمحوُ النهائيُّ لمسؤول النظام وحدَه', async () => {
    await assertFails(doc('desk', claims({ htk: true })).delete());
    await assertSucceeds(doc('adm', claims({ role: 'systemAdmin' })).delete());
  });
});

// ــــ والمفتاحُ الجديدُ لا يقترب من البوّابات الثلاث ــــ
//
// `htk` صلاحيةٌ واسعةٌ بلا نطاقٍ إداريّ، فيجب أن يُقاس **أنّها لا تتعدّى
// البلاغات**. وتسجيلُ الأعضاء وتعديلُ المواعيد النهائية وإضافةُ المشاريع
// تبقى حيث هي: محصورةً بمسؤول النظام، لا يفتحها مفتاحٌ مفوَّض.
describe('حاملُ htk لا يتعدّى البلاغات', () => {
  test('لا يعتمد تسجيلَ عضوٍ جديد', async () => {
    const d = db('desk', claims({ htk: true }));
    await assertFails(d.collection('users').doc('someone').update({ status: 'approved' }));
  });

  test('ولا يعدّل موعداً نهائيّاً لمشروع', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('projects').doc('p1').set({
        name: 'مشروع', departmentId: OTHER, managerUid: 'someone',
        deadline: new Date('2026-12-01T00:00:00Z'),
      });
    });
    const d = db('desk', claims({ htk: true }));
    await assertFails(d.collection('projects').doc('p1').update({
      deadline: new Date('2027-12-01T00:00:00Z'),
    }));
  });

  test('ولا يضيف مشروعاً', async () => {
    const d = db('desk', claims({ htk: true }));
    await assertFails(d.collection('projects').doc('p2').set({
      name: 'مشروعٌ جديد', departmentId: OTHER, managerUid: 'desk',
    }));
  });
});
