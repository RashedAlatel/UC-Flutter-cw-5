/// مهلُ الاستجابة والحلّ — **يضبطها مسؤولُ النظام وحدَه**.
///
/// ولا تُكتب في الشيفرة: كلُّ جهةٍ تتعهّد بما تستطيع، ومهلةٌ مفروضةٌ من
/// المطوّر تُقاس بها إدارةٌ لم توافق عليها رقمٌ بلا معنى.
///
/// ــــ ولماذا ليست في مستند البلاغ ــــ
///
/// الهدفُ يُحسب عند القراءة من هذه السياسة، فتعديلُها يسري على الطابور
/// كلِّه في حينه. ولو خُزّن في كلّ بلاغٍ لَبقيت آلافُ البلاغات على أهدافٍ
/// لم تعد قائمة، ولا يعرف قارئُ التقرير أيُّهما الصحيح.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../itsm/sla.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class SlaPolicyScreen extends StatefulWidget {
  const SlaPolicyScreen({super.key});

  @override
  State<SlaPolicyScreen> createState() => _SlaPolicyScreenState();
}

class _SlaPolicyScreenState extends State<SlaPolicyScreen> {
  final Map<String, TextEditingController> _respond = {};
  final Map<String, TextEditingController> _resolve = {};
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final policy = context.read<AppStore>().slaPolicy;
    for (final p in PriorityLevel.values) {
      final t = policy.targetFor(p);
      _respond[p.name] = TextEditingController(text: '${t.respondMinutes}');
      _resolve[p.name] = TextEditingController(text: '${t.resolveMinutes}');
    }
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in [..._respond.values, ..._resolve.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final out = <String, SlaTarget>{};
    for (final p in PriorityLevel.values) {
      out[p.name] = SlaTarget.fromMap(
        {
          'respondMinutes': int.tryParse(_respond[p.name]!.text.trim()),
          'resolveMinutes': int.tryParse(_resolve[p.name]!.text.trim()),
        },
        // وما لا يُقرأ يبقى على ما كان لا على صفر: حقلٌ مُسح سهواً لا يُلغي
        // مهلةً متّفقاً عليها.
        store.slaPolicy.targetFor(p),
      );
    }
    final messenger = ScaffoldMessenger.of(context);
    await store.saveSlaPolicy(
      SlaPolicy(byPriority: out, atRiskFraction: store.slaPolicy.atRiskFraction),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(const SnackBar(content: Text('حُفظت المهل')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          const SectionTitle('مهلُ الاستجابة والحلّ', icon: Icons.timer_outlined),
          SizedBox(height: AppSpace.xs),
          Text(
            'بالدقائق. وتسري على الطابور كلِّه فورَ الحفظ — ولا تُخزَّن في البلاغات.',
            style: AppText.label,
          ),
          SizedBox(height: AppSpace.md),
          for (final p in PriorityLevel.values)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpace.sm),
              child: AppCard(
                shrinkToChild: true,
                title: p.label,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _respond[p.name],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'مهلةُ أوّلِ ردّ'),
                      ),
                    ),
                    SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: TextField(
                        controller: _resolve[p.name],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'مهلةُ الحلّ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: AppSpace.sm),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'يُحفَظ…' : 'احفظ المهل'),
          ),
        ],
      ),
    );
  }
}
