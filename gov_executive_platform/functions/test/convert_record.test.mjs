// المقابلة بين مشروعٍ وعمل — حقلاً حقلاً، وحالةً حالة.
//
// وما يُقاس هنا ثلاثة، وكلٌّ منها عطلٌ صامت لو سقط:
//
// (١) **لا يسقط حقلٌ مشترك.** التحويل يُنشئ سجلاً جديداً، وحقلٌ منسيٌّ في
//     المقابلة يعني بياناً ضاع بلا رسالة خطأ — يُكتشف بعد أسابيع حين يُسأل
//     عن وصف العمل فلا يوجد.
//
// (٢) **والحالات تُقابَل بمعناها.** لا بترتيبها في التعداد، ولا بأقربها
//     اسماً: «معلّقة» ليست «على المسار»، و«بانتظار الاعتماد» ليست إغلاقاً.
//
// (٣) **وحقول الربط تُكتب في الاتجاهين.** الجديد يشير إلى ما جاء منه —
//     وبغيره لا تعرف شاشةُ المحذوفات أن الأصل حُوّل لا حُذف.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  claimDepartments,
  mayConvertIn,
  projectStatusFor,
  projectToWork,
  targetCollection,
  targetKind,
  taskStatusFor,
  titleOf,
  workToProject,
} from "../lib/convert_record.js";

const NOW = "‗الآن‗";

const project = {
  name: "رقمنة صحيفة الدعوى",
  description: "تحويل صحيفة الدعوى إلى نموذج إلكتروني",
  departmentId: "d-tech",
  dueDate: "‗موعد‗",
  createdAt: "‗أُنشئ‗",
  status: "onTrack",
  priority: "high",
  progressPercent: 40,
  createdByUid: "u-creator",
  managerUids: ["u-lead"],
  executorUids: ["u-exec"],
};

const work = {
  title: "جرد أرشيف القضايا",
  description: "حصر ملفات ٢٠٢٤",
  departmentId: "d-arch",
  assigneeUid: "u-assignee",
  assigneeName: "سالم",
  dueDate: "‗موعد‗",
  createdAt: "‗أُنشئ‗",
  status: "inProgress",
  priority: "low",
  progressPercent: 25,
  createdByUid: "u-creator",
};

const opts = {sourceId: "src-1", ownerUid: "u-owner", ownerName: "نورة", now: NOW};

describe("مشروع ← عمل", () => {
  const out = projectToWork(project, opts);

  test("كل حقلٍ مشترك يُنقل — ولا يبقى فارغٌ بلا سبب", () => {
    assert.equal(out.title, project.name);
    assert.equal(out.description, project.description);
    assert.equal(out.departmentId, project.departmentId);
    assert.equal(out.dueDate, project.dueDate);
    assert.equal(out.priority, project.priority);
    assert.equal(out.progressPercent, project.progressPercent);
    assert.equal(out.createdAt, project.createdAt);
  });

  test("والمنشئ يبقى المنشئ — لا من ضغط زرّ التحويل", () => {
    assert.equal(out.createdByUid, "u-creator");
  });

  test("والمسؤول هو المختار عند التحويل، باسمه", () => {
    assert.equal(out.assigneeUid, "u-owner");
    assert.equal(out.assigneeName, "نورة");
  });

  test("ويُولد حيّاً: حقول الحذف مكتوبةٌ فارغة لا غائبة", () => {
    assert.equal(out.deletedAt, null);
    assert.ok("deletedBy" in out);
    assert.ok("deletedReason" in out);
  });

  test("ويشير إلى ما جاء منه", () => {
    assert.equal(out.convertedFromType, "project");
    assert.equal(out.convertedFromId, "src-1");
    assert.equal(out.convertedToId, null);
  });
});

describe("عمل ← مشروع", () => {
  const out = workToProject(work, opts);

  test("كل حقلٍ مشترك يُنقل", () => {
    assert.equal(out.name, work.title);
    assert.equal(out.description, work.description);
    assert.equal(out.departmentId, work.departmentId);
    assert.equal(out.dueDate, work.dueDate);
    assert.equal(out.priority, work.priority);
    assert.equal(out.progressPercent, work.progressPercent);
  });

  test("وتاريخ البدء تاريخُ إنشاء العمل لا لحظةَ التحويل", () => {
    assert.equal(out.startDate, work.createdAt);
    assert.notEqual(out.startDate, NOW);
  });

  test("والقائد هو المختار، والحقل المفرد الموروث متسقٌ معه", () => {
    assert.deepEqual(out.managerUids, ["u-owner"]);
    assert.equal(out.managerUid, "u-owner");
  });

  test("والمُسنَد إليه الأصلي لا يسقط: يصير منفّذاً", () => {
    assert.deepEqual(out.executorUids, ["u-assignee"]);
    assert.deepEqual(out.executorNames, ["سالم"]);
  });

  test("ولا يتكرّر إن كان هو القائد نفسه", () => {
    const same = workToProject({...work, assigneeUid: "u-owner"}, opts);
    assert.deepEqual(same.executorUids, []);
  });

  test("ويشير إلى ما جاء منه", () => {
    assert.equal(out.convertedFromType, "work");
    assert.equal(out.convertedFromId, "src-1");
  });
});

describe("مقابلة الحالات", () => {
  test("المكتمل يبقى مكتملاً في الاتجاهين", () => {
    assert.equal(taskStatusFor("completed", 0), "done");
    assert.equal(projectStatusFor("done"), "completed");
  });

  test("وما لم يبدأ لا يُكتب «قيد التنفيذ»", () => {
    assert.equal(taskStatusFor("atRisk", 0), "todo");
    assert.equal(taskStatusFor("onTrack", 0), "todo");
  });

  test("وما بدأ فعلاً يُكتب قيد التنفيذ", () => {
    assert.equal(taskStatusFor("atRisk", 15), "inProgress");
    assert.equal(taskStatusFor("delayed", 60), "inProgress");
  });

  test("و«متأخر» لا يُنقل حقلاً: تأخّرُ العمل يُحسب من موعده", () => {
    assert.notEqual(taskStatusFor("delayed", 60), "blocked");
    assert.equal(taskStatusFor("delayed", 60), "inProgress");
  });

  test("والمعلّق ليس سائراً على المسار", () => {
    assert.equal(projectStatusFor("blocked"), "atRisk");
  });

  test("و«بانتظار الاعتماد» ليست إغلاقاً", () => {
    assert.notEqual(projectStatusFor("awaitingApproval"), "completed");
    assert.equal(projectStatusFor("awaitingApproval"), "onTrack");
  });
});

describe("من يحوّل", () => {
  test("مسؤول النظام في كل إدارة", () => {
    assert.equal(mayConvertIn("systemAdmin", [], "d-tech"), true);
  });

  test("ومدير الإدارة في إدارته", () => {
    assert.equal(mayConvertIn("departmentManager", ["d-tech"], "d-tech"), true);
  });

  test("ولا في غيرها", () => {
    assert.equal(mayConvertIn("departmentManager", ["d-arch"], "d-tech"), false);
  });

  test("والمستخدم التنفيذي يقرأ كل الإدارات ولا يحوّل شيئاً", () => {
    assert.equal(mayConvertIn("executiveViewer", ["d-tech"], "d-tech"), false);
  });

  test("والموظف لا يحوّل ولو كان في الإدارة", () => {
    assert.equal(mayConvertIn("employee", ["d-tech"], "d-tech"), false);
  });

  test("وسجلٌّ بلا إدارة لا يحوّله مديرُ إدارة", () => {
    assert.equal(mayConvertIn("departmentManager", ["d-tech"], ""), false);
  });
});

describe("قراءة الإدارات من بطاقة الدخول", () => {
  test("القائمة حين توجد", () => {
    assert.deepEqual(claimDepartments({departmentIds: ["a", "b"]}), ["a", "b"]);
  });

  test("والحقل المفرد الموروث حين لا توجد", () => {
    assert.deepEqual(claimDepartments({departmentId: "a"}), ["a"]);
  });

  test("وبطاقةٌ بلا إدارةٍ إطلاقاً لا تصير «كل الإدارات»", () => {
    assert.deepEqual(claimDepartments({}), []);
    assert.deepEqual(claimDepartments(undefined), []);
  });
});

describe("الوجهة", () => {
  test("المشروع يصير عملاً في مجموعة الأعمال", () => {
    assert.equal(targetCollection("project"), "works");
    assert.equal(targetKind("project"), "work");
  });

  test("والعمل يصير مشروعاً في مجموعة المشاريع", () => {
    assert.equal(targetCollection("work"), "projects");
    assert.equal(targetKind("work"), "project");
  });

  test("والاسم يُقرأ من حقله في كل نوع", () => {
    assert.equal(titleOf("project", project), project.name);
    assert.equal(titleOf("work", work), work.title);
  });
});
