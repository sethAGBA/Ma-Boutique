import 'package:flutter/material.dart';
// import 'dart:typed_data';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/models/payment.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:school_manager/services/pdf_service.dart';
import 'package:school_manager/models/school_info.dart';
import 'package:school_manager/models/class.dart';
// import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class StudentProfilePage extends StatefulWidget {
  final Student student;

  const StudentProfilePage({Key? key, required this.student}) : super(key: key);

  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  List<Payment> _payments = [];
  List<Map<String, dynamic>> _reportCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final payments = await _dbService.getPaymentsForStudent(widget.student.id);
    final reportCards = await _dbService.getArchivedReportCardsForStudent(widget.student.id);
    setState(() {
      _payments = payments;
      _reportCards = reportCards;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme, // Ensure the dialog inherits the current theme
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Custom AppBar-like header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profil de ${widget.student.name}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.iconTheme.color),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // TabBar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                  indicatorColor: theme.colorScheme.primary,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.person), text: 'Infos'),
                    Tab(icon: Icon(Icons.payment), text: 'Paiements'),
                    Tab(icon: Icon(Icons.article), text: 'Bulletins'),
                  ],
                ),
              ),
              // TabBarView
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInfoTab(),
                          _buildPaymentsTab(),
                          _buildReportCardsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    widget.student.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.student.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  'ID: ${widget.student.id}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Informations Générales', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
          Divider(height: 24, color: theme.dividerColor),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildInfoRow('Date de Naissance:', widget.student.dateOfBirth, theme),
                  _buildInfoRow('Genre:', widget.student.gender, theme),
                  _buildInfoRow('Adresse:', widget.student.address, theme),
                  _buildInfoRow('Contact:', widget.student.contactNumber, theme),
                  _buildInfoRow('Email:', widget.student.email, theme),
                  _buildInfoRow('Contact d\'urgence:', widget.student.emergencyContact, theme),
                  _buildInfoRow('Tuteur:', widget.student.guardianName, theme),
                  _buildInfoRow('Contact Tuteur:', widget.student.guardianContact, theme),
                  _buildInfoRow('Classe Actuelle:', widget.student.className, theme),
                  if (widget.student.medicalInfo != null && widget.student.medicalInfo!.isNotEmpty)
                    _buildInfoRow('Informations Médicales:', widget.student.medicalInfo!, theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    final theme = Theme.of(context);
    if (_payments.isEmpty) {
      return Center(child: Text('Aucun paiement trouvé.', style: theme.textTheme.bodyMedium));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: Icon(Icons.receipt_long, color: theme.colorScheme.primary, size: 30),
            title: Text(
              'Paiement du ${payment.date.substring(0, 10)}',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Montant: ${payment.amount} FCFA', style: theme.textTheme.bodyMedium),
                if (payment.comment != null && payment.comment!.isNotEmpty)
                  Text('Commentaire: ${payment.comment}', style: theme.textTheme.bodySmall),
                if (payment.isCancelled)
                  Text('Annulé le: ${payment.cancelledAt?.substring(0, 10)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.secondary),
              onPressed: () async {
                final studentClass = await _dbService.getClassByName(widget.student.className);
                if (studentClass != null) {
                  final allPayments = await _dbService.getPaymentsForStudent(widget.student.id);
                  final totalPaid = allPayments.where((p) => !p.isCancelled).fold(0.0, (sum, item) => sum + item.amount);
                  final totalDue = (studentClass.fraisEcole ?? 0) + (studentClass.fraisCotisationParallele ?? 0);
                  final schoolInfo = await loadSchoolInfo();
                  final pdfBytes = await PdfService.generatePaymentReceiptPdf(
                    currentPayment: payment,
                    allPayments: allPayments,
                    student: widget.student,
                    schoolInfo: schoolInfo,
                    studentClass: studentClass,
                    totalPaid: totalPaid,
                    totalDue: totalDue,
                  );

                  String? directoryPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisir le dossier de sauvegarde');
                  if (directoryPath != null) {
                    final fileName = 'Recu_Paiement_${widget.student.name.replaceAll(' ', '_')}_${payment.date.substring(0, 10)}.pdf';
                    final file = File('$directoryPath/$fileName');
                    await file.writeAsBytes(pdfBytes);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reçu enregistré dans $directoryPath'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportCardsTab() {
    final theme = Theme.of(context);
    if (_reportCards.isEmpty) {
      return Center(child: Text('Aucun bulletin archivé trouvé.', style: theme.textTheme.bodyMedium));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _reportCards.length,
      itemBuilder: (context, index) {
        final reportCard = _reportCards[index];
        // Decode moyennes_par_periode and all_terms from JSON string
        final List<double?> moyennesParPeriode = (reportCard['moyennes_par_periode'] as String)
            .replaceAll('[', '').replaceAll(']', '').split(',').map((e) => double.tryParse(e.trim())).toList();
        final List<String> allTerms = (reportCard['all_terms'] as String)
            .replaceAll('[', '').replaceAll(']', '').split(',').map((e) => e.trim()).toList();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: Icon(Icons.article, color: theme.colorScheme.primary, size: 30),
            title: Text(
              'Bulletin ${reportCard['term']} - ${reportCard['academicYear']}',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moyenne de l\'élève: ${reportCard['moyenne_generale']?.toStringAsFixed(2) ?? '-'}', style: theme.textTheme.bodyMedium),
                Text('Moyenne Classe: ${reportCard['moyenne_generale_classe']?.toStringAsFixed(2) ?? '-'}', style: theme.textTheme.bodyMedium),
                Text('Moyenne la plus forte: ${reportCard['moyenne_la_plus_forte']?.toStringAsFixed(2) ?? '-'}', style: theme.textTheme.bodyMedium),
                Text('Moyenne la plus faible: ${reportCard['moyenne_la_plus_faible']?.toStringAsFixed(2) ?? '-'}', style: theme.textTheme.bodyMedium),
                Text('Moyenne Annuelle: ${reportCard['moyenne_annuelle']?.toStringAsFixed(2) ?? '-'}', style: theme.textTheme.bodyMedium),
                Text('Mention: ${reportCard['mention']}', style: theme.textTheme.bodyMedium),
                Text('Rang: ${reportCard['rang']} / ${reportCard['nb_eleves']}', style: theme.textTheme.bodyMedium),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.secondary),
              onPressed: () async {
                final info = await loadSchoolInfo();
                final studentClass = await _dbService.getClassByName(widget.student.className);
                if (studentClass == null) return;

                // Fetch grades and appreciations for this specific archived report card
                final archivedGrades = await _dbService.getArchivedGrades(
                  academicYear: reportCard['academicYear'],
                  className: reportCard['className'],
                  studentId: reportCard['studentId'],
                );

                final subjectApps = await _dbService.database.then((db) => db.query(
                  'subject_appreciation_archive',
                  where: 'report_card_id = ?',
                  whereArgs: [reportCard['id']],
                ));

                final Map<String, String> professeurs = {};
                final Map<String, String> appreciations = {};
                final Map<String, String> moyennesClasse = {};

                for (final app in subjectApps) {
                  professeurs[app['subject'] as String] = (app['professeur'] ?? '-').toString();
                  appreciations[app['subject'] as String] = (app['appreciation'] ?? '-').toString();
                  moyennesClasse[app['subject'] as String] = (app['moyenne_classe'] ?? '-').toString();
                }

                final pdfBytes = await PdfService.generateReportCardPdf(
                  student: widget.student,
                  schoolInfo: info,
                  grades: archivedGrades,
                  professeurs: professeurs,
                  appreciations: appreciations,
                  moyennesClasse: moyennesClasse,
                  appreciationGenerale: reportCard['appreciation_generale'] ?? '',
                  decision: reportCard['decision'] ?? '',
                  recommandations: reportCard['recommandations'] ?? '',
                  forces: reportCard['forces'] ?? '',
                  pointsADevelopper: reportCard['points_a_developper'] ?? '',
                  sanctions: reportCard['sanctions'] ?? '',
                  attendanceJustifiee: (reportCard['attendance_justifiee'] ?? 0) as int,
                  attendanceInjustifiee: (reportCard['attendance_injustifiee'] ?? 0) as int,
                  retards: (reportCard['retards'] ?? 0) as int,
                  presencePercent: (reportCard['presence_percent'] ?? 0.0) is int ? (reportCard['presence_percent'] as int).toDouble() : (reportCard['presence_percent'] ?? 0.0) as double,
                  conduite: reportCard['conduite'] ?? '',
                  telEtab: info.telephone ?? '',
                  mailEtab: info.email ?? '',
                  webEtab: info.website ?? '',
                  subjects: archivedGrades.map((e) => e.subject).toSet().toList(), // Extract subjects from grades
                  moyennesParPeriode: moyennesParPeriode,
                  moyenneGenerale: reportCard['moyenne_generale']?.toDouble() ?? 0.0,
                  rang: reportCard['rang'] ?? 0,
                  nbEleves: reportCard['nb_eleves'] ?? 0,
                  mention: reportCard['mention'] ?? '',
                  allTerms: allTerms,
                  periodLabel: reportCard['term']?.toString().contains('Semestre') == true ? 'Semestre' : 'Trimestre',
                  selectedTerm: reportCard['term'] ?? '',
                  academicYear: reportCard['academicYear'] ?? '',
                  faitA: reportCard['fait_a'] ?? '',
                  leDate: reportCard['le_date'] ?? '',
                  isLandscape: false, // You might want to store this in the archive or make it selectable
                  niveau: '', // You might want to store this in the archive or fetch it
                  moyenneGeneraleDeLaClasse: reportCard['moyenne_generale_classe']?.toDouble() ?? 0.0,
                  moyenneLaPlusForte: reportCard['moyenne_la_plus_forte']?.toDouble() ?? 0.0,
                  moyenneLaPlusFaible: reportCard['moyenne_la_plus_faible']?.toDouble() ?? 0.0,
                  moyenneAnnuelle: reportCard['moyenne_annuelle']?.toDouble() ?? 0.0,
                );

                String? directoryPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisir le dossier de sauvegarde');
                if (directoryPath != null) {
                  final fileName = 'Bulletin_${widget.student.name.replaceAll(' ', '_')}_${reportCard['term'] ?? ''}_${reportCard['academicYear'] ?? ''}.pdf';
                  final file = File('$directoryPath/$fileName');
                  await file.writeAsBytes(pdfBytes);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bulletin enregistré dans $directoryPath'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}