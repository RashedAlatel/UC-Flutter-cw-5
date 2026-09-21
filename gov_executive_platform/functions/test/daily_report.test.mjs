// اختبارات حساب التقرير التنفيذي اليومي.
//
// الحساب كله دوالّ خالصة، فيُختبر بلقطةٍ مصنوعة بلا محاكي ولا شبكة. وهذا
// مقصود: التقرير قرارٌ إداري يُتّخذ بناءً على تصنيفه، فيجب أن يكون التصنيف
// نفسه مُثبتاً لا مستنتَجاً من كون شاشةٍ تعرض شيئاً.
//
// التشغيل: npm --prefix functions test  (يبني ثم يشغّل)
import {test, describe} from "node:test";
import assert from "node:assert";

import {
  buildReport,
  assessProject,
  assessItem,
  expectedProgress,
  daysBetween,
  DEFAULT_THRESHOLDS,
  reportSubject,
  renderReportHtml,
  linkFor,
  emailTargets,
} from "../lib/daily_report.js";

const TODAY = new Date(2026, 7, 22); // ٢٢ أغسطس ٢٠٢٦
const DEPT = "d-1";
const OTHER = "d-2";

const day = (n) => new Date(2026, 7, 22 + n);

function project(over = {}) {
  return {
    id: "p1",
    name: "مشروع الرقمنة",
    departmentId: DEPT,
    status: "onTrack",
    progressPercent: 50,
    startDate: day(-50),
    dueDate: day(50),
    managerUids: ["u-mgr"],
    managerNames: ["مدير المشروع"],
    ...over,
  };
}

function item(over = {}) {
  return {
    id: "t1",
    kind: "task",
    title: "إعداد الدراسة",
    departmentId: DEPT,
    projectId: "p1",
    projectName: "مشروع الرقمنة",
    projectManagerName: "مدير المشروع",
    assigneeUid: "u-emp",
    assigneeName: "الموظف",
    status: "inProgress",
    progressPercent: 40,
    dueDate: day(30),
    lastUpdated: day(-1),
    createdAt: day(-20),
    approverUid: "",
    approverName: "",
    claimedByName: "",
    claimedAt: null,
    ...over,
  };
}

function update(over = {}) {
  return {
    id: "u1",
    kind: "project",
    refId: "p1",
    refName: "مشروع الرقمنة",
    departmentId: DEPT,
    authorName: "كاتب التحديث",
    date: day(0),
    progressPercent: 50,
    achievements: "أُنجزت المرحلة الأولى",
    blockers: [],
    newRisks: [],
    decisionsRequired: [],
    ...over,
  };
}

function snap(over = {}) {
  return {
    today: TODAY,
    projects: [],
    items: [],
    updates: [],
    blockers: [],
    thresholds: DEFAULT_THRESHOLDS,
    ...over,
  };
}

const ADMIN_SCOPE = {
  uid: "u-admin",
  name: "مسؤول النظام",
  viewsAll: true,
  departmentIds: [],
  projectIds: [],
  label: "كل الإدارات",
};

const HEAD_SCOPE = {
  uid: "u-head",
  name: "مدير الإدارة",
  viewsAll: false,
  departmentIds: [DEPT],
  projectIds: [],
  label: "إدارة النظم",
};

const build = (s, scope = ADMIN_SCOPE) =>
  buildReport(s, scope, "٢٠٢٦/٠٨/٢٢", "2026-08-22T04:00:00Z");

const section = (r, key) => r.sections.find((s) => s.key === key);

describe("أدوات الحساب", () => {
  test("فرق الأيام يتجاهل الساعات", () => {
    assert.equal(daysBetween(new Date(2026, 7, 1, 23), new Date(2026, 7, 2, 1)), 1);
  });

  test("والمتوقَّع من الزمن نصفٌ في منتصف المدة", () => {
    assert.equal(Math.round(expectedProgress(day(-50), day(50), TODAY)), 50);
  });

  test("ومشروعٌ لم يبدأ بعد متوقَّعه صفر", () => {
    assert.equal(expectedProgress(day(10), day(50), TODAY), 0);
  });

  test("ومشروعٌ انقضت مدّته متوقَّعه مئة", () => {
    assert.equal(expectedProgress(day(-50), day(-1), TODAY), 100);
  });
});

describe("تصنيف المشروع", () => {
  const rules = {...DEFAULT_THRESHOLDS};

  test("المتأخر حرج", () => {
    const p = project({dueDate: day(-5)});
    const a = assessProject(p, snap({projects: [p], thresholds: rules}), []);
    assert.equal(a.severity, "critical");
    assert.match(a.reasons.join(" "), /تجاوز موعده النهائي/);
  });

  test("والمتوقف بعائق مفتوح حرج ولو لم يتأخر", () => {
    const p = project();
    const blocker = {
      id: "b1", projectId: "p1", departmentId: DEPT,
      description: "بانتظار موافقة المالية", status: "open", dateRaised: day(-3),
    };
    const a = assessProject(p, snap({projects: [p]}), [blocker]);
    assert.equal(a.severity, "critical");
    assert.match(a.reasons.join(" "), /بانتظار موافقة المالية/);
  });

  // هذه هي الحالة التي أُفردت بابًا مستقلاً بطلبٍ صريح: قربُ الاستحقاق وحده
  // «يحتاج انتباه»، وقربُه **بلا تحديث** حرج — لأن أحداً لا يعرف أين وصل.
  test("وقريبُ الاستحقاق بلا تحديث حديث حرج", () => {
    const p = project({dueDate: day(2)});
    const stale = update({date: day(-20)});
    const a = assessProject(p, snap({projects: [p], updates: [stale]}), []);
    assert.equal(a.severity, "critical");
    assert.match(a.reasons.join(" "), /آخر تحديث قبل/);
  });

  test("وقريبُ الاستحقاق بتحديثٍ حديث «يحتاج انتباه» لا حرج", () => {
    const p = project({dueDate: day(2)});
    const fresh = update({date: day(-1)});
    const a = assessProject(p, snap({projects: [p], updates: [fresh]}), []);
    assert.equal(a.severity, "needsAttention");
  });

  test("والسليم طبيعي — فلا يظهر في التقرير أصلاً", () => {
    const p = project();
    const fresh = update({date: day(0)});
    const a = assessProject(p, snap({projects: [p], updates: [fresh]}), []);
    assert.equal(a.severity, "normal");
    assert.deepEqual(a.reasons, []);
  });

  test("والمنجَز لا يُصنَّف ولو تجاوز موعده", () => {
    const p = project({status: "completed", dueDate: day(-40)});
    const a = assessProject(p, snap({projects: [p]}), []);
    assert.equal(a.severity, "normal");
  });

  test("والإنجاز الذي لم يتناسب مع الوقت المتبقي يُعلَّم", () => {
    // مضى نصف المدة والإنجاز ١٠٪ — الفارق ٤٠ نقطة، فوق هامش الـ١٥.
    const p = project({progressPercent: 10});
    const fresh = update({date: day(0), progressPercent: 10});
    const a = assessProject(p, snap({projects: [p], updates: [fresh]}), []);
    assert.equal(a.severity, "needsAttention");
    assert.match(a.reasons.join(" "), /والمتوقَّع من الوقت المنقضي/);
  });

  test("ولا يُعلَّم فارقٌ داخل الهامش", () => {
    const p = project({progressPercent: 42});
    const fresh = update({date: day(0), progressPercent: 42});
    const a = assessProject(p, snap({projects: [p], updates: [fresh]}), []);
    assert.equal(a.severity, "normal");
  });

  // النسبة محفوظة **يوم كُتبت** في كل تحديث، فالتراجع مقروء لا مستنتَج.
  test("وانخفاض نسبة التقدّم بين آخر تحديثين يُعلَّم", () => {
    const p = project();
    const before = update({id: "u1", date: day(-2), progressPercent: 60});
    const after = update({id: "u2", date: day(0), progressPercent: 45});
    const a = assessProject(p, snap({projects: [p], updates: [before, after]}), []);
    assert.equal(a.severity, "needsAttention");
    assert.match(a.reasons.join(" "), /انخفضت نسبة التقدّم/);
  });

  test("ولا يُعلَّم ارتفاعها", () => {
    const p = project();
    const before = update({id: "u1", date: day(-2), progressPercent: 45});
    const after = update({id: "u2", date: day(0), progressPercent: 60});
    const a = assessProject(p, snap({projects: [p], updates: [before, after]}), []);
    assert.ok(!a.reasons.join(" ").includes("انخفضت"));
  });
});

describe("تصنيف المهمة والعمل", () => {
  test("المتأخرة حرجة", () => {
    const it = item({dueDate: day(-3)});
    const a = assessItem(it, snap({items: [it]}));
    assert.equal(a.severity, "critical");
  });

  test("والمنجزة لا تُصنَّف", () => {
    const it = item({status: "done", dueDate: day(-30)});
    const a = assessItem(it, snap({items: [it]}));
    assert.equal(a.severity, "normal");
  });

  test("وما ينتظر الاعتماد طويلاً يصير حرجاً", () => {
    const it = item({status: "awaitingApproval", claimedAt: day(-10), dueDate: day(30)});
    const a = assessItem(it, snap({items: [it]}));
    assert.equal(a.severity, "critical");
    assert.match(a.reasons.join(" "), /ينتظر الاعتماد منذ/);
  });

  test("وما أُفيد بإتمامه أمس «يحتاج انتباه» لا حرج", () => {
    const it = item({status: "awaitingApproval", claimedAt: day(-1), dueDate: day(30)});
    const a = assessItem(it, snap({items: [it]}));
    assert.equal(a.severity, "needsAttention");
  });
});

describe("الأبواب السبعة", () => {
  test("سبعةٌ بالترتيب المطلوب، ولا يُحذف الفارغ منها", () => {
    const r = build(snap());
    assert.deepEqual(r.sections.map((s) => s.key), [
      "urgentProjects",
      "lateItems",
      "dueSoon",
      "dueSoonStale",
      "recentUpdates",
      "crossDepartment",
      "awaitingApproval",
    ]);
    for (const s of r.sections) assert.ok(s.emptyNote.length > 0, s.key);
  });

  test("والمشروع السليم لا يظهر في باب التدخل العاجل", () => {
    const p = project();
    const r = build(snap({projects: [p], updates: [update({date: day(0)})]}));
    assert.equal(section(r, "urgentProjects").rows.length, 0);
    assert.equal(r.criticalCount, 0);
    assert.match(r.headline, /لا يوجد ما يستدعي تدخلاً/);
  });

  test("والمتأخر يظهر في بابَي التدخل والتأخير معاً", () => {
    const p = project({dueDate: day(-7)});
    const it = item({dueDate: day(-4)});
    const r = build(snap({projects: [p], items: [it]}));
    assert.equal(section(r, "urgentProjects").rows.length, 1);
    assert.equal(section(r, "lateItems").rows.length, 1);
  });

  test("وقريبُ الاستحقاق يُرتَّب بالأقرب أولاً لا بالأخطر", () => {
    const near = item({id: "t-near", title: "الأقرب", dueDate: day(1)});
    const far = item({id: "t-far", title: "الأبعد", dueDate: day(3)});
    const r = build(snap({items: [far, near]}));
    assert.deepEqual(section(r, "dueSoon").rows.map((x) => x.title), ["الأقرب", "الأبعد"]);
  });

  test("وبابُ «قريب بلا تحديث» أضيقُ من باب «قريب الاستحقاق»", () => {
    const fresh = item({id: "t-a", title: "عليه تحديث", dueDate: day(2), lastUpdated: day(-1)});
    const stale = item({id: "t-b", title: "بلا تحديث", dueDate: day(2), lastUpdated: day(-30)});
    const r = build(snap({items: [fresh, stale]}));
    assert.equal(section(r, "dueSoon").rows.length, 2);
    assert.deepEqual(section(r, "dueSoonStale").rows.map((x) => x.title), ["بلا تحديث"]);
  });

  test("وتحديثات ٢٤ ساعة تحمل النسبة القديمة والجديدة", () => {
    const before = update({id: "u1", date: day(-3), progressPercent: 30});
    const today = update({id: "u2", date: day(0), progressPercent: 45});
    const r = build(snap({projects: [project()], updates: [before, today]}));
    const rows = section(r, "recentUpdates").rows;
    assert.equal(rows.length, 1, "القديم خارج نافذة الـ٢٤ ساعة");
    const field = rows[0].fields.find((f) => f.label === "نسبة التقدّم");
    assert.equal(field.value, "٣٠٪ ← ٤٥٪");
  });

  test("والتحديث الذي يطلب قراراً من القيادة حرج", () => {
    const u = update({decisionsRequired: ["تمديد الموعد النهائي"]});
    const r = build(snap({projects: [project()], updates: [u]}));
    assert.equal(section(r, "recentUpdates").rows[0].severity, "critical");
  });

  test("وما بين الإدارات يُقرأ من وجود معتمِد", () => {
    const cross = item({
      id: "t-cross", approverUid: "u-req", approverName: "إدارة الشؤون القانونية",
      createdAt: day(-12),
    });
    const own = item({id: "t-own"});
    const r = build(snap({items: [cross, own]}));
    const rows = section(r, "crossDepartment").rows;
    assert.equal(rows.length, 1);
    assert.match(rows[0].reason, /إدارة الشؤون القانونية/);
    const wait = rows[0].fields.find((f) => f.label === "مدّة الانتظار");
    assert.equal(wait.value, "١٢ يوماً");
  });

  // مهام المشاريع لا تحمل تاريخ إنشاء في نموذج البيانات. والصفر هنا كذبٌ
  // يُقرأ «طُلبت اليوم»، فيتصدّر أقدمُ الطلبات إهمالاً آخرَ القائمة.
  test("ومدّة الانتظار تُقال «غير معروفة» حين لا تاريخ إنشاء", () => {
    const cross = item({
      id: "t-cross", approverUid: "u-req", approverName: "إدارة أخرى", createdAt: null,
    });
    const r = build(snap({items: [cross]}));
    const row = section(r, "crossDepartment").rows[0];
    assert.equal(row.fields.find((f) => f.label === "مدّة الانتظار").value, "غير معروفة");
    assert.equal(row.reason, "مطلوب من إدارة أخرى");
  });

  test("وبانتظار الاعتماد يسمّي من أفاد ومن يعتمد", () => {
    const it = item({
      status: "awaitingApproval", claimedByName: "المنفّذ", claimedAt: day(-2),
      approverUid: "u-req", approverName: "مدير المشروع",
    });
    const r = build(snap({items: [it]}));
    const row = section(r, "awaitingApproval").rows[0];
    assert.equal(row.fields.find((f) => f.label === "أفاد بالإتمام").value, "المنفّذ");
    assert.equal(row.fields.find((f) => f.label === "المعتمِد").value, "مدير المشروع");
  });
});

describe("أهم الحالات والخلاصة", () => {
  test("خمسٌ على الأكثر، الأخطر أولاً ثم الأطول تأخيراً", () => {
    const items = [];
    for (let i = 1; i <= 8; i++) {
      items.push(item({id: `t${i}`, title: `متأخرة ${i}`, dueDate: day(-i)}));
    }
    const r = build(snap({items}));
    assert.equal(r.top.length, 5);
    assert.deepEqual(r.top.map((x) => x.title), [
      "متأخرة 8", "متأخرة 7", "متأخرة 6", "متأخرة 5", "متأخرة 4",
    ]);
  });

  test("ولا يتكرر بندٌ ظهر في بابين", () => {
    // متأخرٌ **وبين الإدارات** — بندٌ واحد يظهر في بابين، وصدارةٌ واحدة.
    const it = item({
      id: "t-dup", dueDate: day(-5), approverUid: "u-req", approverName: "إدارة أخرى",
    });
    const r = build(snap({items: [it]}));
    assert.equal(r.top.length, 1);
    assert.equal(r.criticalCount, 1, "ولا يُعدّ مرّتين في الخلاصة");
  });

  test("والخلاصة تعدّ الحرج والانتباه", () => {
    const critical = item({id: "t-c", dueDate: day(-5)});
    const attention = item({id: "t-a", dueDate: day(2), lastUpdated: day(0)});
    const r = build(snap({items: [critical, attention]}));
    assert.equal(r.criticalCount, 1);
    assert.match(r.headline, /حالة حرجة/);
  });

  test("وموضوع البريد يحمل الخلاصة فيُقرأ بلا فتح", () => {
    const r = build(snap({items: [item({dueDate: day(-5)})]}));
    assert.match(reportSubject(r), /حالة حرجة/);
    assert.match(reportSubject(r), /٢٠٢٦\/٠٨\/٢٢/);
  });
});

// النطاق يُفرض في الحساب **وفي قواعد القراءة معاً**: هذا يمنع أن يُكتب في
// مستند المستلم ما ليس له، والقاعدة تمنع أن يقرأ مستند غيره.
describe("النطاق: لكل مستلم تقريره", () => {
  test("مدير الإدارة لا يرى مشروع إدارة أخرى", () => {
    const mine = project({id: "p-mine", name: "مشروعي", dueDate: day(-5)});
    const theirs = project({
      id: "p-theirs", name: "مشروع غيري", departmentId: OTHER, dueDate: day(-5),
    });
    const r = build(snap({projects: [mine, theirs]}), HEAD_SCOPE);
    assert.deepEqual(section(r, "urgentProjects").rows.map((x) => x.title), ["مشروعي"]);
  });

  test("ومسؤول النظام يرى الاثنين", () => {
    const mine = project({id: "p-mine", name: "مشروعي", dueDate: day(-5)});
    const theirs = project({
      id: "p-theirs", name: "مشروع غيري", departmentId: OTHER, dueDate: day(-5),
    });
    const r = build(snap({projects: [mine, theirs]}), ADMIN_SCOPE);
    assert.equal(section(r, "urgentProjects").rows.length, 2);
  });

  test("ومديرُ مشروعٍ في إدارةٍ أخرى يرى مشروعه وحده", () => {
    const scope = {
      uid: "u-pm", name: "مدير مشروع", viewsAll: false,
      departmentIds: [], projectIds: ["p-led"], label: "مشاريعك",
    };
    const led = project({id: "p-led", name: "الذي أقوده", departmentId: OTHER, dueDate: day(-5)});
    const other = project({id: "p-x", name: "غيره", departmentId: OTHER, dueDate: day(-5)});
    const r = build(snap({projects: [led, other]}), scope);
    assert.deepEqual(section(r, "urgentProjects").rows.map((x) => x.title), ["الذي أقوده"]);
  });

  // ولولا هذا لَمَا علم من ينتظره اعتمادٌ بما يقف على مكتبه، وهو نصف دورة
  // الإغلاق بين الإدارات.
  test("ومن ينتظره اعتمادٌ يراه ولو كان في إدارةٍ أخرى", () => {
    const scope = {
      uid: "u-approver", name: "الطالب", viewsAll: false,
      departmentIds: [DEPT], projectIds: [], label: "إدارتك",
    };
    const it = item({
      id: "t-far", departmentId: OTHER, projectId: null, projectName: null,
      status: "awaitingApproval", claimedAt: day(-1),
      approverUid: "u-approver", approverName: "الطالب",
    });
    const r = build(snap({items: [it]}), scope);
    assert.equal(section(r, "awaitingApproval").rows.length, 1);
  });
});

// قائمةُ سماحٍ لا قائمةَ استثناء — راجع `emailTargets`.
//
// والفرق ليس أسلوبياً: قائمة الاستثناء تنكسر بصمت كلّما وُظّف موظف جديد،
// فيخرج البريد لمن لم يُقصد ولا يُعلم بذلك إلا منه. وهذه مغلقةٌ بطبعها.
describe("حصر البريد بمستلمين بأعيانهم", () => {
  const reportFor = (uid) => ({...build(snap()), recipientUid: uid});
  const all = [reportFor("u-admin"), reportFor("u-head"), reportFor("u-pm")];

  test("قائمةٌ فارغة ⇒ البريد للجميع (السلوك المبدئي)", () => {
    assert.equal(emailTargets(all, []).length, 3);
  });

  test("وفيها واحد ⇒ هو وحده مهما كثر المستلمون", () => {
    const out = emailTargets(all, ["u-admin"]);
    assert.deepEqual(out.map((r) => r.recipientUid), ["u-admin"]);
  });

  test("وفيها اثنان ⇒ هما وحدهما", () => {
    const out = emailTargets(all, ["u-head", "u-pm"]);
    assert.deepEqual(out.map((r) => r.recipientUid), ["u-head", "u-pm"]);
  });

  // من أُدرج في القائمة وليس من المستوى الإشرافي لا يُولَّد له تقرير أصلاً.
  // فلا رسالة له، ولا انهيار — البريد صورةُ التقرير، فبلا تقريرٍ لا رسالة.
  test("ومعرّفٌ لا تقرير له ⇒ لا رسالة ولا انهيار", () => {
    assert.deepEqual(emailTargets(all, ["u-nobody"]), []);
  });

  test("ولا يُغيَّر التوليد نفسه — الحصر على البريد وحده", () => {
    // القائمة الأصلية تبقى كما هي: من له مدخل التقرير يقرؤه على الشاشة.
    emailTargets(all, ["u-admin"]);
    assert.equal(all.length, 3);
  });
});

describe("البريد", () => {
  test("كل سطرٍ فيه رابطٌ مباشر إلى صفحة العنصر", () => {
    const r = build(snap({items: [item({dueDate: day(-5)})], projects: [project()]}));
    const html = renderReportHtml(r, "https://moj.example.kw");
    assert.match(html, /https:\/\/moj\.example\.kw\/\?project=p1/);
  });

  test("والعمل التشغيلي يُربط بمعرّفه هو", () => {
    const row = {
      key: "work:w1", title: "عمل", severity: "critical", reason: "", fields: [],
      linkProjectId: null, linkWorkId: "w1",
    };
    assert.equal(linkFor(row, "https://x.kw"), "https://x.kw/?work=w1");
  });

  test("وبلا عنوانٍ أساس لا يُختلق رابط", () => {
    const row = {
      key: "p", title: "م", severity: "normal", reason: "", fields: [],
      linkProjectId: "p1", linkWorkId: null,
    };
    assert.equal(linkFor(row, ""), null);
  });

  test("ونصّ المستخدم لا يُحقن في HTML", () => {
    const p = project({name: "<script>alert(1)</script>", dueDate: day(-5)});
    const r = build(snap({projects: [p]}));
    const html = renderReportHtml(r, "https://x.kw");
    assert.ok(!html.includes("<script>"), "وسمُ script لا يخرج كما هو");
    assert.match(html, /&lt;script&gt;/);
  });

  test("والأبواب الفارغة تُذكر بخبرها لا تُحذف", () => {
    const html = renderReportHtml(build(snap()), "https://x.kw");
    assert.match(html, /لا مشروع يحتاج تدخلاً اليوم/);
  });
});
