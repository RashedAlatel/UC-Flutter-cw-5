// سجلُّ الأنظمة والأصول: مَن يقرؤه ومَن يكتبه.
//
// ــــ ما يُقاس ــــ
//
// **أنّ مفتاح السجلّ مفتاحُ سجلٍّ لا مفتاحُ اعتماد**: حاملُه يمسك الأصولَ
// والمورّدين والعقود، ولا يقترب من البوّابات الثلاث.
//
// وأنّه **لا يُجمع مع `htk`**: مكتبُ الخدمة يعالج البلاغات، وأمينُ الأصول
// يمسك السجلَّ بما فيه قيمُ العقود — وقد يكونان شخصين.
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const KEEPER = 'u-keeper';
const DESK = 'u-desk';
const EMP = 'u-emp';
const ASSET = 'as-1';

let env;

const claims = ({ role = 'employee', ita = false, htk = false, approved = true } = {}) => ({
  approved,
  role,
  departmentId: 'd-it',
  departmentIds: [],
  perms: { ...(ita ? { ita: true } : {}), ...(htk ? { htk: true } : {}) },
  scopes: {},
  hs: [],
});

const asset = (over = {}) => ({
  kind: 'server',
  name: 'خادم البريد',
  description: '',
  technology: 'Windows Server 2022',
  location: 'غرفة الخوادم',
  status: 'live',
  criticality: 'tier1',
  ownerUid: KEEPER,
  ownerName: 'أمين',
  departmentServed: 'd-it',
  vendorId: '',
  vendorName: '',
  contractId: '',
  capacityUsedPercent: null,
  capacityThreshold: 85,
  createdByUid: KEEPER,
  createdAt: new Date('2026-05-10T08:00:00Z'),
  deletedAt: null,
  deletedBy: null,
  deletedReason: null,
  ...over,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test-it-registry',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    // و`ctx.firestore()` مرّةً واحدة — راجع `itsm_change.rules.test.mjs`.
    const raw = ctx.firestore();
    await raw.collection('assets').doc(ASSET).set(asset());
    await raw.collection('vendors').doc('v-1').set({
      name: 'مورّد', createdByUid: KEEPER, createdAt: new Date('2026-05-10T08:00:00Z'),
      deletedAt: null,
    });
    await raw.collection('contracts').doc('c-1').set({
      title: 'عقدُ دعم', kind: 'support', value: 25000,
      createdByUid: KEEPER, createdAt: new Date('2026-05-10T08:00:00Z'), deletedAt: null,
    });
  });
});

const db = (uid, c) => env.authenticatedContext(uid, c).firestore();

describe('من يقرأ السجلّ', () => {
  test('أمينُ الأصول يقرأ الثلاث', async () => {
    const d = db(KEEPER, claims({ ita: true }));
    await assertSucceeds(d.collection('assets').doc(ASSET).get());
    await assertSucceeds(d.collection('vendors').doc('v-1').get());
    await assertSucceeds(d.collection('contracts').doc('c-1').get());
  });

  test('والموظّفُ لا يقرأ شيئاً منها', async () => {
    const d = db(EMP, claims());
    await assertFails(d.collection('assets').doc(ASSET).get());
    await assertFails(d.collection('vendors').doc('v-1').get());
    await assertFails(d.collection('contracts').doc('c-1').get());
  });

  // ــ ومكتبُ الخدمة ليس أمينَ الأصول ــ
  //
  // وهذا هو الفصلُ الذي بُني عليه المفتاح: العقدُ يحمل قيمةً، والمورّدُ
  // يحمل بيانات اتّصال. وفنّيُّ الدعم لا يحتاجهما ليُغلق بلاغاً.
  test('وحاملُ htk وحدَه لا يقرأ السجلّ', async () => {
    const d = db(DESK, claims({ htk: true }));
    await assertFails(d.collection('assets').doc(ASSET).get());
    await assertFails(d.collection('contracts').doc('c-1').get());
  });

  test('ومسؤولُ النظام يقرأ', async () => {
    await assertSucceeds(
      db('adm', claims({ role: 'systemAdmin' })).collection('assets').doc(ASSET).get());
  });
});

describe('من يكتب في السجلّ', () => {
  const fresh = (uid, c, over = {}) =>
    db(uid, c).collection('assets').doc('as-new').set(
      asset({ createdByUid: uid, createdAt: serverTimestamp(), ...over }),
    );

  test('أمينُ الأصول يضيف', async () => {
    await assertSucceeds(fresh(KEEPER, claims({ ita: true })));
  });

  test('والموظّفُ لا يضيف', async () => {
    await assertFails(fresh(EMP, claims()));
  });

  test('ولا يضيف مكتبُ الخدمة', async () => {
    await assertFails(fresh(DESK, claims({ htk: true })));
  });

  test('ووقتُ الإنشاء وقتُ الخادم', async () => {
    await assertFails(db(KEEPER, claims({ ita: true })).collection('assets').doc('as-t')
      .set(asset({ createdByUid: KEEPER, createdAt: new Date('2020-01-01T00:00:00Z') })));
  });

  test('ولا يُبدَّل منشئُ السجلّ بعد إنشائه', async () => {
    await assertFails(db(KEEPER, claims({ ita: true })).collection('assets').doc(ASSET)
      .update({ createdByUid: EMP }));
  });

  // والضابط: ما ليس أصلاً يُعدَّل.
  test('والضابط: السعةُ تُحدَّث', async () => {
    await assertSucceeds(db(KEEPER, claims({ ita: true })).collection('assets').doc(ASSET)
      .update({ capacityUsedPercent: 91 }));
  });

  test('والمحوُ لمسؤول النظام وحدَه', async () => {
    await assertFails(db(KEEPER, claims({ ita: true })).collection('assets').doc(ASSET).delete());
    await assertSucceeds(
      db('adm', claims({ role: 'systemAdmin' })).collection('assets').doc(ASSET).delete());
  });
});

// ــــ والمفتاحُ مفتاحُ سجلٍّ لا مفتاحُ اعتماد ــــ
describe('حاملُ ita لا يتعدّى السجلّ', () => {
  test('لا يعتمد تسجيلَ عضوٍ جديد', async () => {
    await assertFails(db(KEEPER, claims({ ita: true }))
      .collection('users').doc('someone').update({ status: 'approved' }));
  });

  test('ولا يعدّل موعداً نهائيّاً لمشروع', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('projects').doc('p1').set({
        name: 'مشروع', departmentId: 'd-other', managerUid: 'someone',
        deadline: new Date('2026-12-01T00:00:00Z'),
      });
    });
    await assertFails(db(KEEPER, claims({ ita: true })).collection('projects').doc('p1')
      .update({ deadline: new Date('2027-12-01T00:00:00Z') }));
  });

  test('ولا يضيف مشروعاً', async () => {
    await assertFails(db(KEEPER, claims({ ita: true })).collection('projects').doc('p2')
      .set({ name: 'جديد', departmentId: 'd-other', managerUid: KEEPER }));
  });

  test('ولا يقرأ بلاغات الموظّفين', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('tickets').doc('tk-1').set({
        reporterUid: EMP, assigneeUid: '', title: 'عطل', status: 'open',
        createdAt: new Date('2026-05-10T08:00:00Z'),
      });
    });
    await assertFails(db(KEEPER, claims({ ita: true })).collection('tickets').doc('tk-1').get());
  });
});
