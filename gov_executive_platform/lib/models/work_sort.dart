import 'work_item.dart';

/// ترتيب صفحة الأعمال.
///
/// منفصل عن `ProjectSort` لأن الحقول تختلف: العمل لا يحمل تصنيفات ولا
/// `startDate`، ويحمل `createdAt` منذ إنشائه — فلا يحتاج الرجوع إلى بديل كما
/// تحتاج المشاريع المستوردة.
enum WorkSort {
  newest('الأحدث إضافةً'),
  dueDate('تاريخ الاستحقاق'),
  delay('أيام التأخير'),
  progress('نسبة الإنجاز'),
  title('الاسم');

  final String label;
  const WorkSort(this.label);
}

List<WorkItem> sortWorks(List<WorkItem> works, WorkSort sort) {
  final sorted = works.toList();
  switch (sort) {
    case WorkSort.newest:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case WorkSort.dueDate:
      sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    case WorkSort.delay:
      // الأكثر تأخيراً أولاً — وهو ما يُبحث عنه عند الترتيب بالتأخير.
      sorted.sort((a, b) => b.delayDays.compareTo(a.delayDays));
    case WorkSort.progress:
      // الأقل إنجازاً أولاً، للسبب نفسه.
      sorted.sort((a, b) => a.progressPercent.compareTo(b.progressPercent));
    case WorkSort.title:
      sorted.sort((a, b) => a.title.compareTo(b.title));
  }
  return sorted;
}
