import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:school_manager/models/payment.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/models/grade.dart';
import 'package:school_manager/models/school_info.dart';

class PdfService {
  /// Génère un PDF de reçu de paiement et retourne les bytes (pour aperçu ou impression)
  static Future<List<int>> generatePaymentReceiptPdf({
    required Payment currentPayment,
    required List<Payment> allPayments,
    required Student student,
    required SchoolInfo schoolInfo,
    required Class studentClass,
    required double totalPaid,
    required double totalDue,
  }) async {
    final pdf = pw.Document();
    final formatter = NumberFormat('#,##0 FCFA', 'fr_FR');
    final times = await pw.Font.times();
    final timesBold = await pw.Font.timesBold();
    final primaryColor = PdfColor.fromHex('#4F46E5');
    final secondaryColor = PdfColor.fromHex('#6B7280');
    final lightBgColor = PdfColor.fromHex('#F3F4F6');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final double remainingBalance = totalDue - totalPaid;
          return pw.Stack(children: [
            if (schoolInfo.logoPath != null && File(schoolInfo.logoPath!).existsSync())
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.06,
                    child: pw.Image(
                      pw.MemoryImage(File(schoolInfo.logoPath!).readAsBytesSync()),
                      width: 400,
                    ),
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
              // --- En-tête ---
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (schoolInfo.logoPath != null && File(schoolInfo.logoPath!).existsSync())
                      pw.Image(
                        pw.MemoryImage(File(schoolInfo.logoPath!).readAsBytesSync()),
                        height: 60,
                        width: 60,
                      ),
                    if (schoolInfo.logoPath != null) pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            schoolInfo.name,
                            style: pw.TextStyle(font: timesBold, fontSize: 20, color: primaryColor, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(schoolInfo.address, style: pw.TextStyle(font: times, fontSize: 10, color: secondaryColor)),
                          pw.SizedBox(height: 2),
                          pw.Text('Tel: ${schoolInfo.telephone ?? ''} | Email: ${schoolInfo.email ?? ''}', style: pw.TextStyle(font: times, fontSize: 10, color: secondaryColor)),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(font: timesBold, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Reçu N°: ${currentPayment.id ?? currentPayment.date.hashCode}', style: pw.TextStyle(font: times, fontSize: 10)),
                        pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(currentPayment.date))}', style: pw.TextStyle(font: times, fontSize: 10)),
                        pw.Text('Année: ${studentClass.academicYear}', style: pw.TextStyle(font: times, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // --- Informations sur l'élève ---
              pw.Text('Reçu de :', style: pw.TextStyle(font: timesBold, fontSize: 14, color: primaryColor)),
              pw.Divider(color: lightBgColor, thickness: 2),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Nom de l\'élève:', style: pw.TextStyle(font: timesBold))),
                  pw.Expanded(flex: 3, child: pw.Text(student.name, style: pw.TextStyle(font: times))),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Classe:', style: pw.TextStyle(font: timesBold))),
                  pw.Expanded(flex: 3, child: pw.Text(student.className, style: pw.TextStyle(font: times))),
                ],
              ),
              pw.SizedBox(height: 30),

              // --- Détails du paiement actuel ---
              pw.Text('Historique des transactions', style: pw.TextStyle(font: timesBold, fontSize: 14, color: primaryColor)),
              pw.Table(
                border: pw.TableBorder.all(color: lightBgColor, width: 1.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBgColor),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Date', style: pw.TextStyle(font: timesBold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(font: timesBold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Montant', style: pw.TextStyle(font: timesBold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...allPayments.map((payment) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(payment.date)), style: pw.TextStyle(font: times))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(payment.comment ?? 'Paiement frais de scolarité', style: pw.TextStyle(font: times))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatter.format(payment.amount), style: pw.TextStyle(font: times), textAlign: pw.TextAlign.right)),
                    ],
                  )),
                ],
              ),
              if (currentPayment.isCancelled)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text('LE DERNIER PAIEMENT A ÉTÉ ANNULÉ', style: pw.TextStyle(font: timesBold, color: PdfColors.red, fontWeight: pw.FontWeight.bold, fontSize: 14), textAlign: pw.TextAlign.center),
                ),
              pw.SizedBox(height: 30),

              // --- Résumé financier ---
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightBgColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Résumé Financier', style: pw.TextStyle(font: timesBold, fontSize: 14, color: primaryColor)),
                        pw.SizedBox(height: 10),
                        _buildSummaryRow('Total des Frais de Scolarité:', formatter.format(totalDue), times, timesBold),
                        _buildSummaryRow('Montant Total Payé:', formatter.format(totalPaid), times, timesBold),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: remainingBalance > 0 ? PdfColors.amber50 : PdfColors.green50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('Solde Restant', style: pw.TextStyle(font: timesBold, fontSize: 12)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            formatter.format(remainingBalance),
                            style: pw.TextStyle(font: timesBold, fontSize: 18, fontWeight: pw.FontWeight.bold, color: remainingBalance > 0 ? PdfColors.amber700 : PdfColors.green700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // --- Pied de page ---
              pw.Divider(color: lightBgColor, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Text('Merci pour votre paiement.', style: pw.TextStyle(font: times, fontStyle: pw.FontStyle.italic, color: secondaryColor), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 16),
              pw.Text('Signature et Cachet de l\'établissement', style: pw.TextStyle(font: times, color: secondaryColor), textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 40),
              ],
            ),
          ]);
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String title, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 11)),
          pw.SizedBox(width: 10),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Sauvegarde le PDF de reçu de paiement dans le dossier documents et retourne le fichier
  static Future<File> savePaymentReceiptPdf({
    required Payment currentPayment,
    required List<Payment> allPayments,
    required Student student,
    required SchoolInfo schoolInfo,
    required Class studentClass,
    required double totalPaid,
    required double totalDue,
  }) async {
    final bytes = await generatePaymentReceiptPdf(
      currentPayment: currentPayment,
      allPayments: allPayments,
      student: student,
      schoolInfo: schoolInfo,
      studentClass: studentClass,
      totalPaid: totalPaid,
      totalDue: totalDue,
    );
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/recu_paiement_${student.id}_${currentPayment.id ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Génère un PDF tabulaire de la liste des paiements (export)
  static Future<List<int>> exportPaymentsListPdf({
    required List<Map<String, dynamic>> rows,
  }) async {
    final pdf = pw.Document();
    final formatter = NumberFormat('#,##0.00', 'fr_FR');
    final times = await pw.Font.times();
    final timesBold = await pw.Font.timesBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Export des paiements', style: pw.TextStyle(font: timesBold, fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              cellStyle: pw.TextStyle(font: times, fontSize: 11),
              headerStyle: pw.TextStyle(font: timesBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headers: [
                'Nom', 'Classe', 'Année', 'Montant payé', 'Date', 'Statut', 'Commentaire'
              ],
              data: rows.map((row) {
                final student = row['student'];
                final payment = row['payment'];
                final classe = row['classe'];
                final montantMax = (classe?.fraisEcole ?? 0) + (classe?.fraisCotisationParallele ?? 0);
                final totalPaid = row['totalPaid'] ?? 0.0;
                String statut;
                if (montantMax > 0 && totalPaid >= montantMax) {
                  statut = 'Payé';
                } else if (payment != null && totalPaid > 0) {
                  statut = 'En attente';
                } else {
                  statut = 'Impayé';
                }
                return [
                  student.name,
                  student.className,
                  classe?.academicYear ?? '',
                  formatter.format(payment?.amount ?? 0),
                  payment != null ? payment.date.replaceFirst('T', ' ').substring(0, 16) : '',
                  statut,
                  payment?.comment ?? '',
                ];
              }).toList(),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(2),
              },
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  /// Génère un PDF tabulaire de la liste des élèves d'une classe (export)
  static Future<List<int>> exportStudentsListPdf({
    required List<Map<String, dynamic>> students,
  }) async {
    final pdf = pw.Document();
    final times = await pw.Font.times();
    final timesBold = await pw.Font.timesBold();

    // Trie par nom
    final sorted = List<Map<String, dynamic>>.from(students)
      ..sort((a, b) => (a['student'].name as String).compareTo(b['student'].name as String));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Liste des élèves', style: pw.TextStyle(font: timesBold, fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              cellStyle: pw.TextStyle(font: times, fontSize: 11),
              headerStyle: pw.TextStyle(font: timesBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headers: [
                'N°', 'Nom', 'Prénom', 'Sexe', 'Classe', 'Année', 'Date de naissance', 'Adresse', 'Contact', 'Email', 'Tuteur', 'Contact tuteur'
              ],
              data: List.generate(sorted.length, (i) {
                final student = sorted[i]['student'];
                final classe = sorted[i]['classe'];
                final names = (student.name as String).split(' ');
                final prenom = names.length > 1 ? names.sublist(1).join(' ') : '';
                final nom = names.isNotEmpty ? names[0] : '';
                return [
                  (i + 1).toString(),
                  nom,
                  prenom,
                  student.gender == 'M' ? 'Garçon' : 'Fille',
                  student.className,
                  classe?.academicYear ?? '',
                  student.dateOfBirth,
                  student.address,
                  student.contactNumber,
                  student.email,
                  student.guardianName,
                  student.guardianContact,
                ];
              }),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerLeft,
                7: pw.Alignment.centerLeft,
                8: pw.Alignment.centerLeft,
                9: pw.Alignment.centerLeft,
                10: pw.Alignment.centerLeft,
                11: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(1.5),
                7: const pw.FlexColumnWidth(2),
                8: const pw.FlexColumnWidth(1.5),
                9: const pw.FlexColumnWidth(2),
                10: const pw.FlexColumnWidth(2),
                11: const pw.FlexColumnWidth(1.5),
              },
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  /// Génère un PDF tabulaire de la liste des classes (export)
  static Future<List<int>> exportClassesListPdf({required List<Class> classes}) async {
    final pdf = pw.Document();
    final times = await pw.Font.times();
    final timesBold = await pw.Font.timesBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Liste des classes', style: pw.TextStyle(font: timesBold, fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              cellStyle: pw.TextStyle(font: times, fontSize: 11),
              headerStyle: pw.TextStyle(font: timesBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headers: ['Nom', 'Année', 'Titulaire', 'Frais école', 'Frais cotisation parallèle'],
              data: classes.map((c) => [
                c.name,
                c.academicYear,
                c.titulaire ?? '',
                c.fraisEcole?.toString() ?? '',
                c.fraisCotisationParallele?.toString() ?? '',
              ]).toList(),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  /// Génère un PDF fidèle du bulletin scolaire d'un élève
  static Future<List<int>> generateReportCardPdf({
    required Student student,
    required SchoolInfo schoolInfo,
    required List<Grade> grades,
    required Map<String, String> professeurs,
    required Map<String, String> appreciations,
    required Map<String, String> moyennesClasse,
    required String appreciationGenerale,
    required String decision,
    String recommandations = '',
    String forces = '',
    String pointsADevelopper = '',
    String sanctions = '',
    int attendanceJustifiee = 0,
    int attendanceInjustifiee = 0,
    int retards = 0,
    double presencePercent = 0.0,
    String conduite = '',
    required String telEtab,
    required String mailEtab,
    required String webEtab,
    required List<String> subjects,
    required List<double?> moyennesParPeriode,
    required double moyenneGenerale,
    required int rang,
    required int nbEleves,
    required String mention,
    required List<String> allTerms,
    required String periodLabel,
    required String selectedTerm,
    required String academicYear,
    required String faitA,
    required String leDate,
    required bool isLandscape,
    String niveau = '',
    double? moyenneGeneraleDeLaClasse,
    double? moyenneLaPlusForte,
    double? moyenneLaPlusFaible,
    double? moyenneAnnuelle,
  }) async {
    final pdf = pw.Document();
    final times = await pw.Font.times();
    final timesBold = await pw.Font.timesBold();
    final secondaryColor = PdfColors.blueGrey800;
    final mainColor = PdfColors.blue800;
    final tableHeaderBg = PdfColors.blue200;
    final tableHeaderText = PdfColors.white;
    final tableRowAlt = PdfColors.blue50;
    final now = DateTime.now();
    final prenom = student.name.split(' ').length > 1 ? student.name.split(' ').first : student.name;
    final nom = student.name.split(' ').length > 1 ? student.name.split(' ').sublist(1).join(' ') : '';
    final sexe = student.gender;
    // ---
    final PdfPageFormat _pageFormat = isLandscape ? PdfPageFormat(842, 595) : PdfPageFormat(595.28, 1000);
    final pw.PageTheme _pageTheme = pw.PageTheme(
      pageFormat: _pageFormat,
      margin: isLandscape ? const pw.EdgeInsets.all(12) : const pw.EdgeInsets.all(20),
      buildBackground: (schoolInfo.logoPath != null && File(schoolInfo.logoPath!).existsSync())
          ? (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Opacity(
                  opacity: 0.05,
                  child: pw.Image(
                    pw.MemoryImage(File(schoolInfo.logoPath!).readAsBytesSync()),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              )
          : null,
    );
    pdf.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme,
        build: (pw.Context context) {
          final double smallFont = isLandscape ? 6.0 : 6.8;
          final double baseFont = smallFont;
          final double headerFont = isLandscape ? 9.5 : 14.0;
          final double spacing = isLandscape ? 4 : 6;
          String _toOrdinalWord(int n) {
            switch (n) {
              case 1:
                return 'premier';
              case 2:
                return 'deuxième';
              case 3:
                return 'troisième';
              case 4:
                return 'quatrième';
              case 5:
                return 'cinquième';
              default:
                return '$nᵉ';
            }
          }
          String _buildBulletinSubtitle() {
            final String base = 'Bulletin du ';
            final String period = periodLabel.toLowerCase();
            final match = RegExp(r"(\d+)").firstMatch(selectedTerm);
            if (match != null) {
              final numStr = match.group(1);
              final idx = int.tryParse(numStr ?? '');
              if (idx != null) {
                return base + _toOrdinalWord(idx) + ' ' + period;
              }
            }
            if (selectedTerm.isNotEmpty) {
              return base + period + ' ' + selectedTerm.toLowerCase();
            }
            return base + period;
          }
          final String bulletinSubtitle = _buildBulletinSubtitle();
          return <pw.Widget>[
              // En-tête établissement
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (schoolInfo.logoPath != null && File(schoolInfo.logoPath!).existsSync())
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 16),
                      child: pw.Image(
                        pw.MemoryImage(File(schoolInfo.logoPath!).readAsBytesSync()),
                        height: isLandscape ? 28 : 80,
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolInfo.name,
                          style: pw.TextStyle(
                            font: timesBold,
                            fontSize: headerFont,
                            color: mainColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: isLandscape ? 2 : 4),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                schoolInfo.address,
                                style: pw.TextStyle(
                                  font: times,
                                  fontSize: smallFont,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            pw.Text(
                              'Année académique : $academicYear',
                              style: pw.TextStyle(
                                font: times,
                                fontSize: smallFont,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        if (schoolInfo.director.isNotEmpty)
                          pw.Text(
                            (niveau.toLowerCase().contains('lycée') ? 'Proviseur(e) : ' : 'Directeur(ice) : ') + schoolInfo.director,
                            style: pw.TextStyle(
                              font: times,
                              fontSize: smallFont,
                              color: secondaryColor,
                            ),
                          ),
                        pw.SizedBox(height: isLandscape ? 2 : 8),
                        if (isLandscape)
                          pw.Text(
                            [
                              if (telEtab.isNotEmpty) 'Tél. : $telEtab',
                              if (mailEtab.isNotEmpty) 'Mail : $mailEtab',
                              if (webEtab.isNotEmpty) 'Web : $webEtab',
                            ].join('  |  '),
                            style: pw.TextStyle(font: times, fontSize: smallFont, color: secondaryColor),
                          )
                        else
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text('Téléphone : $telEtab', style: pw.TextStyle(font: times, fontSize: smallFont, color: secondaryColor)),
                              ),
                              pw.Expanded(
                                child: pw.Text('Email : $mailEtab', style: pw.TextStyle(font: times, fontSize: smallFont, color: secondaryColor)),
                              ),
                              pw.Expanded(
                                child: pw.Text('Site web : $webEtab', style: pw.TextStyle(font: times, fontSize: smallFont, color: secondaryColor)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Center(
                child: pw.Column(children: [
                  pw.Text(
                    'BULLETIN SCOLAIRE',
                    style: pw.TextStyle(font: timesBold, fontSize: headerFont, color: mainColor, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(bulletinSubtitle, style: pw.TextStyle(font: timesBold, fontSize: smallFont, color: secondaryColor)),
                  if ((schoolInfo.motto ?? '').isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Divider(color: PdfColors.blue100, thickness: 1)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Text(
                            schoolInfo.motto!,
                            style: pw.TextStyle(font: times, fontStyle: pw.FontStyle.italic, fontSize: smallFont, color: secondaryColor),
                          ),
                        ),
                        pw.Expanded(child: pw.Divider(color: PdfColors.blue100, thickness: 1)),
                      ],
                    ),
                  ]
                ]),
              ),
              pw.SizedBox(height: spacing),
              // Bloc élève
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('Nom : $nom', style: pw.TextStyle(font: timesBold, color: mainColor))),
                    pw.Expanded(child: pw.Text('Prénom : $prenom', style: pw.TextStyle(font: timesBold, color: mainColor))),
                    pw.Expanded(child: pw.Text('Sexe : $sexe', style: pw.TextStyle(font: timesBold, color: mainColor))),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Text('Classe : ', style: pw.TextStyle(font: timesBold, color: mainColor)),
                          pw.Text(student.className, style: pw.TextStyle(font: times, color: secondaryColor)),
                        ],
                      ),
                    ),
                    pw.Text('Effectif : ' + (nbEleves > 0 ? '$nbEleves' : '-'), style: pw.TextStyle(font: times, color: secondaryColor)),
                  ],
                ),
              ),
              pw.SizedBox(height: spacing),
              // Tableau matières
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.blue100),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(0.7),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(0.9),
                  6: const pw.FlexColumnWidth(0.9),
                  7: const pw.FlexColumnWidth(1.3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: tableHeaderBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Matière', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Professeur', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Sur', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Devoir', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Composition', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Moy. élève', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Moy. classe', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Appréciation prof.', style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: 9))),
                    ],
                  ),
                  ...subjects.map((subject) {
                    final subjectGrades = grades.where((g) => g.subject == subject).toList();
                    final devoirs = subjectGrades.where((g) => g.type == 'Devoir').toList();
                    final compositions = subjectGrades.where((g) => g.type == 'Composition').toList();
                    final devoirNote = devoirs.isNotEmpty ? devoirs.first.value.toStringAsFixed(2) : '-';
                    final devoirSur = devoirs.isNotEmpty ? devoirs.first.maxValue.toStringAsFixed(2) : '-';
                    final compoNote = compositions.isNotEmpty ? compositions.first.value.toStringAsFixed(2) : '-';
                    final compoSur = compositions.isNotEmpty ? compositions.first.maxValue.toStringAsFixed(2) : '-';
                    double total = 0;
                    double totalCoeff = 0;
                    for (final g in [...devoirs, ...compositions]) {
                      if (g.maxValue > 0 && g.coefficient > 0) {
                        total += ((g.value / g.maxValue) * 20) * g.coefficient;
                        totalCoeff += g.coefficient;
                      }
                    }
                    final moyenneMatiere = (totalCoeff > 0) ? (total / totalCoeff) : 0.0;
                    // Affiche la ligne même si subjectGrades est vide
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(subject, style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(professeurs[subject] ?? '-', style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(devoirSur != '-' ? devoirSur : compoSur, style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(devoirNote, style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(compoNote, style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(subjectGrades.isNotEmpty ? moyenneMatiere.toStringAsFixed(2) : '-', style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(moyennesClasse[subject] ?? '-', style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(appreciations[subject] ?? '-', style: pw.TextStyle(color: secondaryColor, fontSize: 8))),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: spacing),
              // Synthèse : tableau des moyennes par période
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Moyenne par ' + periodLabel.toLowerCase(), style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: smallFont)),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.blue100),
                      columnWidths: {
                        for (int i = 0; i < allTerms.length; i++) i: const pw.FlexColumnWidth(),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: allTerms.map((t) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t, style: pw.TextStyle(font: timesBold, color: tableHeaderText, fontSize: smallFont)),
                          )).toList(),
                        ),
                        pw.TableRow(
                          children: moyennesParPeriode.map((m) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(m != null ? m.toStringAsFixed(2) : '-', style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                          )).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: spacing),
              // Synthèse générale
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Moyenne de l\'élève : ${moyenneGenerale.toStringAsFixed(2)}', style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: smallFont + 1)),
                          if (moyenneGeneraleDeLaClasse != null)
                            pw.Text('Moyenne de la classe : ${moyenneGeneraleDeLaClasse.toStringAsFixed(2)}', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          if (moyenneLaPlusForte != null)
                            pw.Text('Moyenne la plus forte : ${moyenneLaPlusForte.toStringAsFixed(2)}', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          if (moyenneLaPlusFaible != null)
                            pw.Text('Moyenne la plus faible : ${moyenneLaPlusFaible.toStringAsFixed(2)}', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          if (moyennesParPeriode.length == 3 && moyennesParPeriode.every((m) => m != null)) ...[
                            pw.SizedBox(height: 8),
                            pw.Text('Moyenne annuelle : '
                              + (moyennesParPeriode.every((m) => m != null)
                                  ? (moyennesParPeriode.whereType<double>().reduce((a, b) => a + b) / moyennesParPeriode.length).toStringAsFixed(2)
                                  : '-'),
                              style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: smallFont)),
                          ],
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Text('Rang : ', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                              pw.Text('$rang / $nbEleves', style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Text('Mention : ', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: mainColor,
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Text(mention, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: smallFont)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Appréciation générale :', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 8),
                          pw.Text(appreciationGenerale, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 16),
                          pw.Text('Décision du conseil de classe :', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 8),
                          pw.Text(decision, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 8),
                          pw.Text('Recommandations :', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 4),
                          pw.Text(recommandations, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 8),
                          pw.Text('Forces :', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 4),
                          pw.Text(forces, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 8),
                          pw.Text('Points à développer :', style: pw.TextStyle(font: timesBold, color: secondaryColor, fontSize: smallFont)),
                          pw.SizedBox(height: 4),
                          pw.Text(pointsADevelopper, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: spacing),
              // Assiduité & conduite
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.blue100),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Assiduité et Conduite', style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: smallFont)),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text('Présence: ' + (presencePercent > 0 ? '${presencePercent.toStringAsFixed(1)}%' : '-'), style: pw.TextStyle(color: secondaryColor, fontSize: smallFont))),
                      pw.Expanded(child: pw.Text('Retards: ' + (retards > 0 ? '$retards' : '-'), style: pw.TextStyle(color: secondaryColor, fontSize: smallFont))),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text('Absences justifiées: ' + (attendanceJustifiee > 0 ? '$attendanceJustifiee' : '-'), style: pw.TextStyle(color: secondaryColor, fontSize: smallFont))),
                      pw.Expanded(child: pw.Text('Absences injustifiées: ' + (attendanceInjustifiee > 0 ? '$attendanceInjustifiee' : '-'), style: pw.TextStyle(color: secondaryColor, fontSize: smallFont))),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Text('Conduite: ' + (conduite.isNotEmpty ? conduite : '-'), style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                  ],
                ),
              ),
              pw.SizedBox(height: spacing),
              // Sanctions
              if (sanctions.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.red100),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Sanctions', style: pw.TextStyle(font: timesBold, color: PdfColors.red700, fontSize: smallFont)),
                      pw.SizedBox(height: 6),
                      pw.Text(sanctions, style: pw.TextStyle(color: secondaryColor, fontSize: smallFont)),
                    ],
                  ),
                ),
              pw.SizedBox(height: spacing),
              // Bloc signature compact
              pw.Container(
                padding: pw.EdgeInsets.all(isLandscape ? 6 : 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.blue100, width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Fait à :', style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: baseFont)),
                          pw.SizedBox(height: 2),
                          pw.Text(faitA.isNotEmpty ? faitA : '__________________________', style: pw.TextStyle(font: times, color: secondaryColor, fontSize: baseFont)),
                          pw.SizedBox(height: spacing/2),
                          pw.Text(
                            niveau.toLowerCase().contains('lycée') ? 'Proviseur(e) :' : 'Directeur(ice) :',
                            style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: baseFont),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('__________________________', style: pw.TextStyle(font: times, color: secondaryColor, fontSize: baseFont)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: isLandscape ? 12 : 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Le :', style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: baseFont)),
                          pw.SizedBox(height: 2),
                          pw.Text(leDate.isNotEmpty ? leDate : '__________________________', style: pw.TextStyle(font: times, color: secondaryColor, fontSize: baseFont)),
                          pw.SizedBox(height: spacing/2),
                          pw.Text('Titulaire :', style: pw.TextStyle(font: timesBold, color: mainColor, fontSize: baseFont)),
                          pw.SizedBox(height: 2),
                          pw.Text('__________________________', style: pw.TextStyle(font: times, color: secondaryColor, fontSize: baseFont)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: isLandscape ? 8 : 24),
            ];
        },
      ),
    );
    return pdf.save();
  }

  // Prépare la structure pour d'autres types de PDF (statistiques, export, etc.)
} 