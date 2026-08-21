import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ornament_border.dart';

/// الشريط القيادي أعلى لوحة القيادة: الأرقام الكبرى على خلفية الهوية العميقة.
///
/// ولِمَ شريطٌ ملوّن في منصة كلها بيضاء؟ لأن الصفحة كانت تُقرأ رماديةً بيضاء
/// لا خضراء ذهبية: سبع بطاقات بيضاء متشابهة بارتفاع ٩٢ بكسل لسطرين من نص،
/// تُمرَّر كلها قبل الوصول إلى أي رسم — ولون الهوية الثاني لا يظهر إلا في
/// خيطين رفيعين. فالشريط يجمع ما يُسأل عنه أولاً في مكان واحد، ويعطي الصفحة
/// ثقلاً بصرياً يليق بجهة رسمية.
///
/// وهو **لا يعرض قائمة ثابتة**: [metrics] هي مؤشرات اللوحة التي اختارها
/// المستخدم، تُحذف وتُرتَّب كما كانت. الشريط يقرّر شكلها لا محتواها.
class CommandBand extends StatelessWidget {
  /// سطر تمهيدي فوق العنوان (اسم الدولة والجهة).
  final String eyebrow;
  final String title;
  final String subtitle;

  /// أزرار الترويسة — تُبنى بالألوان المناسبة للخلفية الداكنة.
  final List<Widget> actions;

  /// بطاقات المؤشرات كما هي على اللوحة. قد تكون فارغة إن حذفها المستخدم
  /// كلها، وحينها لا يُرسم صفّ المؤشرات أصلاً ولا يبقى فراغ بلا معنى.
  final List<Widget> metrics;

  const CommandBand({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.metrics = const [],
  });

  /// كم مؤشراً في السطر الواحد بحسب العرض المتاح.
  static int columnsFor(double width) {
    if (width >= 1150) return 5;
    if (width >= 720) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    // لون النص يُشتقّ من إضاءة الخلفية الفعلية، ولا يُفترض أبيض: «إعدادات
    // المظهر» تقبل إدخالاً حرّاً بالـhex، ولونٌ فاتح مع نصٍّ أبيض ثابت يجعل
    // أول ما يُرى في المنصة غير مقروء.
    final fg = AppColors.onBrand(AppColors.primary);
    final onDark = fg == Colors.white;
    final muted = fg.withValues(alpha: 0.68);
    final hairline = fg.withValues(alpha: 0.16);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          // الزخرفة الهندسية المعتمدة في وثائق الوزارة — نفس الويدجت المستعملة
          // في شاشة الدخول وتصدير PDF، لا نسخة منها. وتُخفى على الخلفية
          // الفاتحة: الذهبي عليها لا يُرى.
          if (onDark)
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              child: OrnamentBorder(width: 26, color: AppColors.accent.withValues(alpha: 0.5)),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.xl, 28, AppSpace.xl + 26, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  fg: fg,
                  muted: muted,
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Container(height: 1, color: hairline),
                  const SizedBox(height: AppSpace.lg),
                  _MetricGrid(metrics: metrics, hairline: hairline),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Color fg;
  final Color muted;

  const _Header({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.fg,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: AppText.label.copyWith(color: muted, letterSpacing: 0.4)),
        const SizedBox(height: 7),
        Text(title, style: AppText.pageTitle.copyWith(color: fg)),
        const SizedBox(height: 11),
        // الخيط الذهبي نفسه المستعمل في شاشة الدخول والشريط الجانبي: تكراره
        // مقصود، وهو ما يجعل الشاشات تبدو منصةً واحدة لا شاشات جُمعت.
        Container(height: 2, width: 52, color: AppColors.accent),
        const SizedBox(height: 11),
        Text(subtitle, style: AppText.body.copyWith(color: muted, height: 1.6)),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 620 || actions.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: actions),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: text),
          const SizedBox(width: AppSpace.md),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: actions),
          ),
        ],
      );
    });
  }
}

/// شبكة المؤشرات بفواصل رأسية بين أعمدة السطر الواحد.
///
/// `Wrap` مرفوض هنا: يعطي أبناءه عرضاً غير محدود، فمؤشرٌ بعنوان طويل يخرج من
/// الشريط بصمت بلا استثناء — وهو العطل نفسه الذي كلّف جولةً كاملة في بطاقات
/// المشاريع. والشبكة تفرض على كل عمود عرضاً محسوباً.
class _MetricGrid extends StatelessWidget {
  final List<Widget> metrics;
  final Color hairline;

  const _MetricGrid({required this.metrics, required this.hairline});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = CommandBand.columnsFor(constraints.maxWidth);
      final rows = <Widget>[];

      for (var start = 0; start < metrics.length; start += columns) {
        final slice = metrics.sublist(start, (start + columns).clamp(0, metrics.length));
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) Container(width: 1, height: 46, color: hairline),
              Expanded(
                child: i < slice.length
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                        child: slice[i],
                      )
                    // خانة فارغة تحفظ عرض الأعمدة في السطر الأخير الناقص، فلا
                    // يتمدّد آخر مؤشر ليملأ السطر ويبدو مختلفاً عن إخوته.
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: AppSpace.md),
              Container(height: 1, color: hairline),
              const SizedBox(height: AppSpace.md),
            ],
            rows[i],
          ],
        ],
      );
    });
  }
}

/// زرّ ترويسة على خلفية الهوية الداكنة.
///
/// أزرار المنصة العادية مبنية على خلفية بيضاء، فحدودها الرمادية ونصّها الأخضر
/// يختفيان على الأخضر العميق.
class BandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// الزرّ الرئيسي يُملأ بالذهبي — والنص عليه داكن، فتباينه عالٍ.
  final bool filled;

  /// حالة «مُفعَّل» لزرّ الترتيب.
  final bool active;

  const BandButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onBrand(AppColors.primary);
    final onGold = AppColors.onBrand(AppColors.accent);

    final background = filled || active ? AppColors.accent : fg.withValues(alpha: 0.08);
    final foreground = filled || active ? onGold : fg;
    final border = filled || active ? AppColors.accent : fg.withValues(alpha: 0.28);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(label, style: AppText.label.copyWith(color: foreground, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
