// إعادةُ جدولة المهمة على الخادم — الصلاحيةُ والحدّ.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **الحدُّ مفروضٌ على الخادم لا في الشاشة.** «موعد المهمة لا يتجاوز
//     موعد المشروع» قاعدةُ عملٍ لا ترتيبُ واجهة: من فتح أدوات المتصفح وكتب
//     مباشرةً يجب أن يُردّ. ونظيرُها في العميل `taskDueDateRejection`.
//
// (٢) **وهو على كل فروع الكتابة**، لا على فرع الصلاحية الجديدة وحده: مديرُ
//     الإدارة يمرّ من فرعٍ آخر، ولو تُرك له لَتجاوزت مهمتُه نهايةَ مشروعها.
//
// (٣) **والصلاحيةُ الجديدة أضيقُ ما يمكن**: الموعدُ وحده، وفي إدارته وحدها.
//     `mtd` ليست بوابةَ المواعيد النهائية — تلك موعدُ **المشروع** ولا
//     يفتحها مفتاحٌ مفوَّض.
import assert from 'node:assert/strict';
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';

const DEPT = 'd-justice';
const OTHER = 'd-other';
const PROJECT_DUE = new Date('2026-03-15T00:00:00.000Z');

let env;

const claims = (uid, { role = 'employee', dept = DEPT, perms = {} } = {}) => ({
  approved: true,
  role,
  departmentId: dept,
  departmentIds: role === 'departmentManager' ? [dept] : [],
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
    await db.collection('projects').doc('p1').set({
      departmentId: DEPT,
      name: 'مشروع',
      dueDate: PROJECT_DUE,
      managerUids: ['u-mgr'],
      managerUid: 'u-mgr',
      executorUids: [],
    });
    await db.collection('tasks').doc('t1').set({
      projectId: 'p1',
      departmentId: DEPT,
      title: 'مهمة',
      status: 'inProgress',
      progressPercent: 30,
      assigneeUid: 'u-x',
      assigneeName: 'منفّذ',
      dueDate: new Date('2026-02-20T00:00:00.000Z'),
      managerUid: 'u-mgr',
      createdByUid: 'u-mgr',
    });
  });
});

const asUser = (uid, opts) =>
  env.authenticatedContext(uid, claims(uid, opts)).firestore();

const move = (db, when) =>
  db.collection('tasks').doc('t1').update({ dueDate: when, lastUpdated: new Date() });

describe('الحدُّ: لا تتجاوز المهمةُ موعدَ مشروعها', () => {
  test('مديرُ الإدارة يحرّك الموعد داخل المدّة', async () => {
    const db = asUser('u-head', { role: 'departmentManager' });
    await assertSucceeds(move(db, new Date('2026-03-01T00:00:00.000Z')));
  });

  // ــ وهذا هو الحدُّ الذي طُلب ــ
  test('ولا يتجاوز به نهايةَ المشروع — وهو مديرُ الإدارة', async () => {
    const db = asUser('u-head', { role: 'departmentManager' });
    await assertFails(move(db, new Date('2026-03-16T00:00:00.000Z')));
  });

  test('ولا مديرُ المشروع', async () => {
    const db = asUser('u-mgr');
    await assertFails(move(db, new Date('2026-06-01T00:00:00.000Z')));
  });

  test('واليومُ نفسُه يمرّ', async () => {
    const db = asUser('u-head', { role: 'departmentManager' });
    await assertSucceeds(move(db, PROJECT_DUE));
  });
});

describe('والصلاحيةُ المستقلّة', () => {
  test('صاحبُ mtd في إدارته يحرّك الموعد', async () => {
    const db = asUser('u-plan', { perms: { mtd: true } });
    await assertSucceeds(move(db, new Date('2026-03-02T00:00:00.000Z')));
  });

  test('ولا يتجاوز بها الحدَّ كذلك', async () => {
    const db = asUser('u-plan', { perms: { mtd: true } });
    await assertFails(move(db, new Date('2026-03-20T00:00:00.000Z')));
  });

  test('ولا موظّفٌ بلا الصلاحية', async () => {
    const db = asUser('u-emp');
    await assertFails(move(db, new Date('2026-03-02T00:00:00.000Z')));
  });

  test('ولا صاحبُها في إدارةٍ أخرى', async () => {
    const db = asUser('u-plan', { dept: OTHER, perms: { mtd: true } });
    await assertFails(move(db, new Date('2026-03-02T00:00:00.000Z')));
  });

  // ــ وأضيقُ ما يمكن: الموعدُ وحده ــ
  //
  // ولولا `hasOnly` لَأعاد صاحبُ الصلاحية إسنادَ المهمة أو غيّر حالتَها،
  // وهي صلاحيةُ **جدولة** لا صلاحيةُ إدارة.
  test('ولا يُعيد بها إسنادَ المهمة', async () => {
    const db = asUser('u-plan', { perms: { mtd: true } });
    await assertFails(
      db.collection('tasks').doc('t1').update({
        dueDate: new Date('2026-03-02T00:00:00.000Z'),
        assigneeUid: 'u-plan',
      }),
    );
  });

  test('ولا يغيّر بها حالةَ المهمة', async () => {
    const db = asUser('u-plan', { perms: { mtd: true } });
    await assertFails(
      db.collection('tasks').doc('t1').update({
        dueDate: new Date('2026-03-02T00:00:00.000Z'),
        status: 'done',
      }),
    );
  });
});

// ــ وما لا يمسّ الموعد يمرّ كما كان ــ
//
// الحدُّ شرطٌ على كتابات التاريخ وحدها، والقراءةُ من `projects` لا تقع
// إلا عندها. ولو شمل كلَّ كتابةٍ لَحمل كلُّ تحديثِ حالةٍ قراءةَ مستندٍ زائدة.
test('وتحديثُ المُسنَد إليه لحالته لا يمسّه الحدّ', async () => {
  const db = asUser('u-x');
  await assertSucceeds(
    db.collection('tasks').doc('t1').update({
      status: 'done',
      progressPercent: 100,
      lastUpdated: new Date(),
    }),
  );
});
