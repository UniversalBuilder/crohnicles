import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../event_model.dart';

class PdfExportService {
  /// Generate PDF export with weather correlations and analysis
  static Future<File> generateInsightsPdf({
    required Map<String, Map<String, Map<String, int>>> correlationsByType,
    required Map<String, double> symptomBaselinePercentages,
    required int totalDaysAnalyzed,
    required List<EventModel> recentSymptoms,
    String? patientName,
    Map<String, int>? mostFrequentTags,
    Map<String, List<Map<String, dynamic>>>? correlations,
  }) async {
    final pdf = pw.Document();
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          _buildHeader(patientName, now, dateFormatter),
          pw.SizedBox(height: 20),
          
          // Summary Section
          _buildSummarySection(totalDaysAnalyzed, correlationsByType, symptomBaselinePercentages),
          pw.SizedBox(height: 20),
          
          // Frequent Foods Section (if data available)
          if (mostFrequentTags != null && mostFrequentTags.isNotEmpty) ...[
            _buildMostFrequentFoodsSection(mostFrequentTags, totalDaysAnalyzed),
            pw.SizedBox(height: 20),
          ],
          
          // Statistical Correlations Section (if data available)
          if (correlations != null && correlations.isNotEmpty) ...[
            _buildStatisticalCorrelationsSection(correlations),
            pw.SizedBox(height: 20),
          ],
          
          // Weather Correlations by Type
          _buildWeatherCorrelationsSection(correlationsByType, symptomBaselinePercentages, totalDaysAnalyzed),
          pw.SizedBox(height: 20),
          
          // Recent Symptoms
          if (recentSymptoms.isNotEmpty) ...[
            _buildRecentSymptomsSection(recentSymptoms, dateFormatter),
            pw.SizedBox(height: 20),
          ],
          
          // Methodology/Glossary
          _buildMethodologySection(),
          
          // Footer
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    // Save PDF to device
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'crohnicles_insights_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }

  static pw.Widget _buildHeader(String? patientName, DateTime date, DateFormat formatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CROHNICLES',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo700,
              ),
            ),
            pw.Text(
              'Rapport d\'Analyse',
              style: pw.TextStyle(
                fontSize: 16,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.indigo700, thickness: 2),
        pw.SizedBox(height: 12),
        if (patientName != null) ...[
          pw.Text(
            'Patient : $patientName',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
        ],
        pw.Text(
          'Date d\'export : ${formatter.format(date)}',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
        ),
      ],
    );
  }

  static pw.Widget _buildSummarySection(
    int totalDaysAnalyzed,
    Map<String, Map<String, Map<String, int>>> correlationsByType,
    Map<String, double> symptomBaselinePercentages,
  ) {
    final symptomTypes = ['Articulaires', 'Fatigue', 'Digestif'];
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.indigo200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUME DE L\'ANALYSE',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Période analysée : $totalDaysAnalyzed jours',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Répartition des symptômes (fréquence habituelle) :',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...symptomTypes.map((type) {
            final baseline = symptomBaselinePercentages[type] ?? 0.0;
            String label;
            switch (type) {
              case 'Articulaires':
                label = 'Douleurs articulaires';
                break;
              case 'Fatigue':
                label = 'Fatigue';
                break;
              case 'Digestif':
                label = 'Symptômes digestifs';
                break;
              default:
                label = type;
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, top: 2),
              child: pw.Text(
                '- $label : ${baseline.toStringAsFixed(1)}%',
                style: const pw.TextStyle(fontSize: 10),
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildWeatherCorrelationsSection(
    Map<String, Map<String, Map<String, int>>> correlationsByType,
    Map<String, double> symptomBaselinePercentages,
    int totalDaysAnalyzed,
  ) {
    final widgets = <pw.Widget>[];
    
    widgets.add(
      pw.Text(
        'CORRELATIONS METEO & SYMPTOMES',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo900,
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 12));

    correlationsByType.forEach((condition, typeData) {
      widgets.add(_buildWeatherConditionCard(
        condition,
        typeData,
        symptomBaselinePercentages,
      ));
      widgets.add(pw.SizedBox(height: 12));
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static pw.Widget _buildWeatherConditionCard(
    String condition,
    Map<String, Map<String, int>> typeData,
    Map<String, double> symptomBaselinePercentages,
  ) {
    final symptomTypes = ['Articulaires', 'Fatigue', 'Digestif'];
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            condition,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          ...symptomTypes.map((type) {
            final data = typeData[type];
            if (data == null) return pw.SizedBox();
            
            final total = data['total'] ?? 0;
            final withSymptom = data['withSymptom'] ?? 0;
            
            if (total == 0) return pw.SizedBox();
            
            final percentage = (withSymptom / total * 100);
            final baseline = symptomBaselinePercentages[type] ?? 0.0;
            final delta = percentage - baseline;
            
            String label;
            String possessif;
            switch (type) {
              case 'Articulaires':
                label = 'douleurs articulaires';
                possessif = 'vos douleurs articulaires';
                break;
              case 'Fatigue':
                label = 'fatigue';
                possessif = 'votre fatigue';
                break;
              case 'Digestif':
                label = 'symptômes digestifs';
                possessif = 'vos troubles digestifs';
                break;
              default:
                label = type;
                possessif = 'vos $type';
            }
            
            String significance;
            PdfColor deltaColor;
            if (delta.abs() < 10) {
              significance = 'Aucun lien';
              deltaColor = PdfColors.grey600;
            } else if (delta > 0) {
              if (delta > 35) {
                significance = '(!!) Forte correlation';
                deltaColor = PdfColors.red700;
              } else if (delta > 20) {
                significance = 'Corrélation modérée';
                deltaColor = PdfColors.orange700;
              } else {
                significance = 'Faible tendance';
                deltaColor = PdfColors.amber700;
              }
            } else {
              significance = '✓ Effet protecteur';
              deltaColor = PdfColors.green700;
            }
            
            final reliability = total >= 10 ? 'Fiable' : (total >= 5 ? 'Indicatif' : 'Insuffisant');
            final reliabilityColor = total >= 10 ? PdfColors.green700 : (total >= 5 ? PdfColors.amber700 : PdfColors.red700);
            
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        label.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: deltaColor.luminance > 0.5 ? deltaColor : deltaColor.shade(0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          significance,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Observation : $withSymptom jours avec $label sur $total jours (${percentage.toStringAsFixed(1)}%)',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Taux habituel : ${baseline.toStringAsFixed(1)}% - Delta : ${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: reliabilityColor.shade(0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          'Fiabilité : $reliability ($total jours)',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildRecentSymptomsSection(
    List<EventModel> symptoms,
    DateFormat dateFormatter,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SYMPTOMES RECENTS (Gravite >= 5)',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo900,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Symptôme', isHeader: true),
                _buildTableCell('Gravité', isHeader: true),
                _buildTableCell('Tags', isHeader: true),
              ],
            ),
            ...symptoms.take(10).map((symptom) {
              final date = DateTime.parse(symptom.dateTime);
              return pw.TableRow(
                children: [
                  _buildTableCell(dateFormatter.format(date)),
                  _buildTableCell(symptom.title),
                  _buildTableCell('${symptom.severity}/10'),
                  _buildTableCell(symptom.tags.take(2).join(', '), fontSize: 8),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES IMPORTANTES :',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '- Ce rapport est genere automatiquement par Crohnicles a partir de vos donnees de suivi.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '- Les correlations meteo sont basees sur des analyses statistiques et peuvent varier selon les individus.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '- Consultez toujours un professionnel de sante pour interpretation medicale.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // --- NEW SECTIONS ---

  /// Build section for most frequent food tags
  static pw.Widget _buildMostFrequentFoodsSection(Map<String, int> mostFrequentTags, int totalDays) {
    final sortedTags = mostFrequentTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topTags = sortedTags.take(10).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ALIMENTS LES PLUS FREQUENTS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Aliments consommés le plus souvent durant la période analysée ($totalDays jours)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Rang', isHeader: true),
                _buildTableCell('Aliment', isHeader: true),
                _buildTableCell('Fréquence', isHeader: true),
                _buildTableCell('% des repas', isHeader: true),
              ],
            ),
            ...topTags.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final tag = entry.value.key;
              final count = entry.value.value;
              final percentage = ((count / totalDays) * 100).toStringAsFixed(1);
              
              return pw.TableRow(
                children: [
                  _buildTableCell('#$rank'),
                  _buildTableCell(tag),
                  _buildTableCell('$count fois'),
                  _buildTableCell('$percentage%'),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'NOTE : Cette liste reflète uniquement la fréquence de consommation, pas les corrélations avec symptômes.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  /// Build section for statistical correlations between foods and symptoms
  static pw.Widget _buildStatisticalCorrelationsSection(Map<String, List<Map<String, dynamic>>> correlations) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CORRELATIONS STATISTIQUES (Aliments -> Symptomes)',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Associations observées entre aliments et symptômes (basées sur vos données uniquement)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        
        // Iterate over each symptom type with correlations
        ...correlations.entries.map((entry) {
          final symptomType = entry.key;
          final tagCorrelations = entry.value;
          
          if (tagCorrelations.isEmpty) {
            return pw.SizedBox.shrink();
          }
          
          // Take top 5 correlations for this symptom type
          final topCorrelations = tagCorrelations.take(5).toList();
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '- ${_getSymptomDisplayName(symptomType)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo600),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Aliment', isHeader: true),
                      _buildTableCell('Corrélation', isHeader: true),
                      _buildTableCell('Occurrences', isHeader: true),
                      _buildTableCell('Fiabilité', isHeader: true),
                    ],
                  ),
                  ...topCorrelations.map((corr) {
                    final tag = corr['tag'] as String? ?? 'Unknown';
                    final correlation = (corr['correlation'] as num?)?.toDouble() ?? 0.0;
                    final count = corr['count'] as int? ?? 0;
                    final reliability = count >= 10 ? 'Élevée' : count >= 5 ? 'Modérée' : 'Faible';
                    
                    return pw.TableRow(
                      children: [
                        _buildTableCell(tag),
                        _buildTableCell('${(correlation * 100).toStringAsFixed(1)}%'),
                        _buildTableCell('$count'),
                        _buildTableCell(reliability, fontSize: 8),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 12),
            ],
          );
        }),
        
        pw.Text(
          'INTERPRETATION : Une correlation de 80% signifie que dans 80% des cas ou cet aliment a ete consomme, le symptome est apparu dans les heures suivantes.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  /// Build methodology/glossary section
  static pw.Widget _buildMethodologySection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'METHODOLOGIE & GLOSSAIRE',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 8),
        
        _buildGlossaryItem('Fréquence', 
          'Nombre de fois où un aliment ou événement a été enregistré durant la période.'),
        
        _buildGlossaryItem('Corrélation', 
          'Pourcentage de cas où un symptôme apparaît après la consommation d\'un aliment spécifique. Ne prouve PAS de lien de causalité.'),
        
        _buildGlossaryItem('Baseline', 
          'Taux de référence d\'un symptôme (ex: douleurs articulaires présentes 35% du temps normalement).'),
        
        _buildGlossaryItem('Fiabilité', 
          'Elevee (>=10 observations) : donnee statistiquement robuste. Moderee (5-9 obs). Faible (<5 obs) : tendance indicative, necessite plus de donnees.'),
        
        _buildGlossaryItem('Modèles ML vs Statistiques', 
          'Les prédictions ML (machine learning) sont utilisées uniquement après l\'ajout d\'un repas pour estimer les risques futurs. Les analyses statistiques dans ce rapport sont basées sur des calculs de fréquence et corrélation directe.'),
        
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'AVERTISSEMENT : Ce rapport est un outil d\'aide au suivi personnel. Il ne remplace en aucun cas un diagnostic medical. Consultez toujours votre medecin ou gastro-enterologue pour toute decision therapeutique.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blue900),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildGlossaryItem(String term, String definition) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              term,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              definition,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to get localized symptom display name
  static String _getSymptomDisplayName(String symptomType) {
    const map = {
      'digestive': 'Digestif',
      'skin': 'Peau',
      'joint': 'Articulations',
      'fatigue': 'Fatigue',
      'pain': 'Douleurs',
      'other': 'Autres',
    };
    return map[symptomType] ?? symptomType;
  }

  /// Share or print PDF using system share sheet
  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }

  /// Print PDF directly
  static Future<void> printPdf(File pdfFile) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await pdfFile.readAsBytes(),
    );
  }
}
