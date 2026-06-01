import 'package:flutter/material.dart';

class PatientAiAnalysisDialog extends StatelessWidget {
  final bool isArabic;
  final String title;
  final String report;
  final String? confidence;
  final Map<String, dynamic>? structuredResult;

  const PatientAiAnalysisDialog({
    super.key,
    required this.isArabic,
    required this.title,
    required this.report,
    required this.confidence,
    required this.structuredResult,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  String _cleanText(dynamic value, {String fallback = ''}) {
    final text = (value?.toString() ?? fallback)
        .replaceAll('*', '')
        .replaceAll('•', '')
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => _cleanText(e))
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Color _confidenceColor(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'mid':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _confidenceLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'high':
        return tr('مرتفع', 'High');
      case 'mid':
        return tr('متوسط', 'Medium');
      case 'low':
        return tr('منخفض', 'Low');
      default:
        return tr('غير محدد', 'Unknown');
    }
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _textBlock(String text) {
    return Text(
      _cleanText(text),
      style: const TextStyle(
        fontSize: 15,
        height: 1.8,
        color: Colors.black87,
      ),
    );
  }

  Widget _listBlock(List<String> items, {bool numbered = false}) {
    if (items.isEmpty) {
      return Text(
        tr('لا توجد بيانات كافية', 'No sufficient data'),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        final prefix = numbered ? '${index + 1}.' : '•';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefix,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _cleanText(items[index]),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _treatmentPlanBlock(List<Map<String, dynamic>> phases) {
    if (phases.isEmpty) {
      return Text(
        tr('لا توجد خطة علاجية مقترحة حاليًا', 'No suggested treatment plan available'),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      );
    }

    return Column(
      children: phases.map((phase) {
        final phaseTitle = _cleanText(phase['phase'], fallback: tr('مرحلة علاجية', 'Treatment Phase'));
        final priority = _cleanText(phase['priority'], fallback: 'mid').toLowerCase();
        final goal = _cleanText(phase['goal']);
        final steps = _stringList(phase['steps']);

        Color priorityColor;
        String priorityText;

        switch (priority) {
          case 'high':
            priorityColor = Colors.red;
            priorityText = tr('أولوية عالية', 'High Priority');
            break;
          case 'mid':
            priorityColor = Colors.orange;
            priorityText = tr('أولوية متوسطة', 'Medium Priority');
            break;
          default:
            priorityColor = Colors.green;
            priorityText = tr('أولوية منخفضة', 'Low Priority');
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      phaseTitle,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      priorityText,
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tr('الهدف: ', 'Goal: ') + goal,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 10),
                _listBlock(steps, numbered: true),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = structuredResult ?? <String, dynamic>{};

    final intro = _cleanText(data['introduction']);
    final summary = _cleanText(data['summary'], fallback: _cleanText(report));
    final clinicalNotes = _stringList(data['clinicalNotes']);
    final futureTreatmentPlan = _mapList(
      data['futureTreatmentPlan'] ?? data['suggestedTreatmentPlan'],
    );
    final homeCare = _stringList(data['homeCare']);
    final financialNotes = _stringList(data['financialNotes']);
    final questionsForDentist = _stringList(data['questionsForDentist']);
    final finalRecommendation = _cleanText(data['finalRecommendation']);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: const Color(0xFFF5F7FA),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 950,
            maxHeight: 700,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology_alt_outlined,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _cleanText(title, fallback: tr('تحليل ملف المريض', 'Patient File Analysis')),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _confidenceColor(confidence).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _confidenceLabel(confidence),
                        style: TextStyle(
                          color: _confidenceColor(confidence),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (intro.isNotEmpty)
                        _sectionCard(
                          context: context,
                          title: tr('مقدمة التحليل', 'Analysis Introduction'),
                          icon: Icons.auto_awesome,
                          child: _textBlock(intro),
                        ),
                      _sectionCard(
                        context: context,
                        title: tr('ملخص الحالة', 'Patient Summary'),
                        icon: Icons.description_outlined,
                        child: _textBlock(summary),
                      ),
                      _sectionCard(
                        context: context,
                        title: tr('ملاحظات سريرية', 'Clinical Notes'),
                        icon: Icons.medical_information_outlined,
                        child: _listBlock(clinicalNotes),
                      ),
                      _sectionCard(
                        context: context,
                        title: tr('الخطة العلاجية المستقبلية المقترحة', 'Suggested Future Treatment Plan'),
                        icon: Icons.assignment_turned_in_outlined,
                        child: _treatmentPlanBlock(futureTreatmentPlan),
                      ),
                      _sectionCard(
                        context: context,
                        title: tr('إرشادات المتابعة والعناية', 'Home Care & Follow-up'),
                        icon: Icons.favorite_border,
                        child: _listBlock(homeCare),
                      ),
                      _sectionCard(
                        context: context,
                        title: tr('ملاحظات مالية', 'Financial Notes'),
                        icon: Icons.payments_outlined,
                        child: _listBlock(financialNotes),
                      ),
                      _sectionCard(
                        context: context,
                        title: tr('أسئلة مهمة للطبيب', 'Important Questions for the Dentist'),
                        icon: Icons.help_outline_rounded,
                        child: _listBlock(questionsForDentist),
                      ),
                      if (finalRecommendation.isNotEmpty)
                        _sectionCard(
                          context: context,
                          title: tr('التوصية النهائية', 'Final Recommendation'),
                          icon: Icons.fact_check_outlined,
                          child: _textBlock(finalRecommendation),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          tr(
                            'هذا التحليل استرشادي فقط، والقرار النهائي للطبيب بعد الفحص السريري والصور الشعاعية.',
                            'This analysis is for guidance only. The final decision belongs to the dentist after clinical examination and radiographic assessment.',
                          ),
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.7,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}