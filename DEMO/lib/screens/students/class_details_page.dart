import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:school_manager/models/course.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// ignore: depend_on_referenced_packages
import 'package:printing/printing.dart';
import 'package:school_manager/constants/strings.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/models/payment.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/screens/students/widgets/custom_dialog.dart';
import 'package:school_manager/screens/students/widgets/form_field.dart';
import 'package:school_manager/screens/students/widgets/student_registration_form.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:school_manager/services/pdf_service.dart';
import 'package:docx_template/docx_template.dart';
import 'package:school_manager/utils/academic_year.dart';

class ClassDetailsPage extends StatefulWidget {
  final Class classe;
  final List<Student> students;

  const ClassDetailsPage({required this.classe, required this.students, Key? key}) : super(key: key);

  @override
  State<ClassDetailsPage> createState() => _ClassDetailsPageState();
}

class _ClassDetailsPageState extends State<ClassDetailsPage> with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _yearController;
  late TextEditingController _titulaireController;
  late TextEditingController _fraisEcoleController;
  late TextEditingController _fraisCotisationParalleleController;
  late TextEditingController _searchController;
  late List<Student> _students;
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  String _studentSearchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  late FocusNode _nameFocusNode;
  late FocusNode _yearFocusNode;
  late FocusNode _titulaireFocusNode;
  late FocusNode _fraisEcoleFocusNode;
  late FocusNode _fraisCotisationFocusNode;
  late FocusNode _searchFocusNode;
  String _sortBy = 'name'; // Sort by name or ID
  bool _sortAscending = true;
  String _studentStatusFilter = 'Tous'; // 'Tous', 'Payé', 'En attente'

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.classe.name);
    _yearController = TextEditingController(text: widget.classe.academicYear);
    _titulaireController = TextEditingController(text: widget.classe.titulaire);
    _fraisEcoleController = TextEditingController(text: widget.classe.fraisEcole?.toString() ?? '');
    _fraisCotisationParalleleController = TextEditingController(text: widget.classe.fraisCotisationParallele?.toString() ?? '');
    _searchController = TextEditingController();
    _students = List<Student>.from(widget.students);

    _nameFocusNode = FocusNode();
    _yearFocusNode = FocusNode();
    _titulaireFocusNode = FocusNode();
    _fraisEcoleFocusNode = FocusNode();
    _fraisCotisationFocusNode = FocusNode();
    _searchFocusNode = FocusNode();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600), // Slightly faster for performance
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    _fraisEcoleController.addListener(_updateTotalClasse);
    _fraisCotisationParalleleController.addListener(_updateTotalClasse);

    getCurrentAcademicYear().then((year) {
      if (widget.classe.academicYear.isEmpty) {
        _yearController.text = year;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _titulaireController.dispose();
    _fraisEcoleController.dispose();
    _fraisCotisationParalleleController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    _nameFocusNode.dispose();
    _yearFocusNode.dispose();
    _titulaireFocusNode.dispose();
    _fraisEcoleFocusNode.dispose();
    _fraisCotisationFocusNode.dispose();
    _searchFocusNode.dispose();
    _fraisEcoleController.removeListener(_updateTotalClasse);
    _fraisCotisationParalleleController.removeListener(_updateTotalClasse);
    super.dispose();
  }

  void _updateTotalClasse() {
    setState(() {}); // Force le rebuild pour mettre à jour le total
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) {
      _showModernSnackBar('Veuillez remplir tous les champs obligatoires', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedClass = Class(
        name: _nameController.text,
        academicYear: _yearController.text,
        titulaire: _titulaireController.text,
        fraisEcole: _fraisEcoleController.text.isNotEmpty ? double.tryParse(_fraisEcoleController.text) : null,
        fraisCotisationParallele: _fraisCotisationParalleleController.text.isNotEmpty ? double.tryParse(_fraisCotisationParalleleController.text) : null,
      );
      await _dbService.updateClass(widget.classe.name, updatedClass);
      final refreshedClass = (await _dbService.getClasses()).firstWhere((c) => c.name == updatedClass.name);
      final refreshedStudents = (await _dbService.getStudents()).where((s) => s.className == updatedClass.name).toList();

      if (!mounted) return;
      setState(() {
        _nameController.text = refreshedClass.name;
        _yearController.text = refreshedClass.academicYear;
        _titulaireController.text = refreshedClass.titulaire ?? '';
        _fraisEcoleController.text = refreshedClass.fraisEcole?.toString() ?? '';
        _fraisCotisationParalleleController.text = refreshedClass.fraisCotisationParallele?.toString() ?? '';
        _students = refreshedStudents;
        _isLoading = false;
      });
      _showModernSnackBar('Classe mise à jour avec succès !');
    } catch (e) {
      setState(() => _isLoading = false);
      _showModernSnackBar('Erreur lors de la mise à jour : ${e.toString().contains('unique') ? 'Nom de classe déjà existant' : e}', isError: true);
    }
  }

  Future<void> _copyClass() async {
    setState(() => _isLoading = true);
    try {
      final newClass = Class(
        name: '${_nameController.text} (Copie)',
        academicYear: (int.parse(_yearController.text.split('-').first) + 1).toString() + '-' + (int.parse(_yearController.text.split('-').last) + 1).toString(),
        titulaire: _titulaireController.text,
        fraisEcole: _fraisEcoleController.text.isNotEmpty ? double.tryParse(_fraisEcoleController.text) : null,
        fraisCotisationParallele: _fraisCotisationParalleleController.text.isNotEmpty ? double.tryParse(_fraisCotisationParalleleController.text) : null,
      );
      await _dbService.insertClass(newClass);
      setState(() => _isLoading = false);
      _showModernSnackBar('Classe copiée avec succès !');
      Navigator.of(context).pop(); // Close dialog to refresh parent
    } catch (e) {
      setState(() => _isLoading = false);
      _showModernSnackBar('Erreur lors de la copie : $e', isError: true);
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 24,
              semanticLabel: isError ? 'Erreur' : 'Succès',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53E3E) : const Color(0xFF38A169),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _editStudent(Student student) async {
    final GlobalKey<StudentRegistrationFormState> studentFormKey = GlobalKey<StudentRegistrationFormState>();
    await showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: AppStrings.editStudent,
        content: StudentRegistrationForm(
          key: studentFormKey,
          onSubmit: () async {
            final refreshedStudents = (await _dbService.getStudents()).where((s) => s.className == _nameController.text).toList();
            setState(() {
              _students = refreshedStudents;
            });
            Navigator.of(context).pop();
            _showModernSnackBar('Élève mis à jour avec succès !');
          },
          student: student,
        ),
        fields: const [],
        onSubmit: () {
          studentFormKey.currentState?.submitForm();
        },
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(Student student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildModernDeleteDialog(student),
    );
    if (confirm == true) {
      try {
        await _dbService.deleteStudent(student.id);
        if (student.photoPath != null && File(student.photoPath!).existsSync()) {
          await File(student.photoPath!).delete();
        }
        final refreshedStudents = (await _dbService.getStudents()).where((s) => s.className == _nameController.text).toList();
        setState(() {
          _students = refreshedStudents;
        });
        _showModernSnackBar('Élève supprimé avec succès !');
      } catch (e) {
        _showModernSnackBar('Erreur lors de la suppression : $e', isError: true);
      }
    }
  }

  Widget _buildModernDeleteDialog(Student student) {
    return CustomDialog(
      title: 'Confirmer la suppression',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE53E3E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 40,
              color: Color(0xFFE53E3E),
              semanticLabel: 'Supprimer',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Voulez-vous vraiment supprimer l'élève ${student.name} ?\nCette action est irréversible.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium!.color,
              height: 1.5,
            ),
          ),
        ],
      ),
      fields: const [],
      onSubmit: () => Navigator.of(context).pop(true),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    );
  }

  Widget _buildModernSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
              semanticLabel: title,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge!.color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFormCard(List<Widget> children) {
    final int nbEleves = _students.length;
    final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
    final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
    final double totalClasse = nbEleves * (fraisEcole + fraisCotisation);
    final Color totalColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: CustomFormField(
          controller: TextEditingController(text: '${totalClasse.toStringAsFixed(2)} FCFA'),
          labelText: 'Total à payer pour la classe',
          hintText: '',
          readOnly: true,
          suffixIcon: Icons.summarize,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.98),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Nom de la classe
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: _nameController,
                              labelText: AppStrings.classNameDialog,
                              hintText: 'Entrez le nom de la classe',
                              validator: (value) => value!.isEmpty ? AppStrings.required : null,
                              suffixIcon: Icons.class_,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: _yearController,
                              labelText: AppStrings.academicYearDialog,
                              hintText: "Entrez l'année scolaire",
                              validator: (value) => value!.isEmpty ? AppStrings.required : null,
                              suffixIcon: Icons.calendar_today,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: _titulaireController,
                              labelText: 'Titulaire',
                              hintText: 'Nom du titulaire de la classe',
                              suffixIcon: Icons.person_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: _fraisEcoleController,
                              labelText: "Frais d'école",
                              hintText: "Montant des frais d'école",
                              validator: (value) {
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Veuillez entrer un montant valide';
                                }
                                return null;
                              },
                              suffixIcon: Icons.attach_money,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: _fraisCotisationParalleleController,
                              labelText: 'Frais de cotisation parallèle',
                              hintText: 'Montant des frais de cotisation parallèle',
                              validator: (value) {
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Veuillez entrer un montant valide';
                                }
                                return null;
                              },
                              suffixIcon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          // Champ du montant total à payer pour la classe
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: CustomFormField(
                              controller: TextEditingController(text: '${totalClasse.toStringAsFixed(2)} FCFA'),
                              labelText: 'Total à payer pour la classe',
                              hintText: '',
                              readOnly: true,
                              suffixIcon: Icons.summarize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: _nameController,
                        labelText: AppStrings.classNameDialog,
                        hintText: 'Entrez le nom de la classe',
                        validator: (value) => value!.isEmpty ? AppStrings.required : null,
                        suffixIcon: Icons.class_,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: _yearController,
                        labelText: AppStrings.academicYearDialog,
                        hintText: "Entrez l'année scolaire",
                        validator: (value) => value!.isEmpty ? AppStrings.required : null,
                        suffixIcon: Icons.calendar_today,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: _titulaireController,
                        labelText: 'Titulaire',
                        hintText: 'Nom du titulaire de la classe',
                        suffixIcon: Icons.person_outline,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: _fraisEcoleController,
                        labelText: "Frais d'école",
                        hintText: "Montant des frais d'école",
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Veuillez entrer un montant valide';
                          }
                          return null;
                        },
                        suffixIcon: Icons.attach_money,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: _fraisCotisationParalleleController,
                        labelText: 'Frais de cotisation parallèle',
                        hintText: 'Montant des frais de cotisation parallèle',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Veuillez entrer un montant valide';
                          }
                          return null;
                        },
                        suffixIcon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    // Champ du montant total à payer pour la classe (mobile)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: CustomFormField(
                        controller: TextEditingController(text: '${totalClasse.toStringAsFixed(2)} FCFA'),
                        labelText: 'Total à payer pour la classe',
                        hintText: '',
                        readOnly: true,
                        suffixIcon: Icons.summarize,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildModernSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, ID ou genre...',
          hintStyle: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium!.color?.withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 20,
              semanticLabel: 'Rechercher',
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        style: const TextStyle(fontSize: 16),
        onChanged: (value) => setState(() => _studentSearchQuery = value.trim()),
      ),
    );
  }

  Widget _buildModernStudentCard(Student student) {
    return FutureBuilder<double>(
      future: _dbService.getTotalPaidForStudent(student.id),
      builder: (context, snapshot) {
        final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
        final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
        final double montantMax = fraisEcole + fraisCotisation;
        final double totalPaid = snapshot.data ?? 0;
        final bool isPaid = montantMax > 0 && totalPaid >= montantMax;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667EEA),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    student.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? 'Payé' : 'En attente',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ID: ${student.id} • ${student.gender == 'M' ? 'Garçon' : 'Fille'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernActionButton(
                  icon: Icons.visibility_rounded,
                  color: const Color(0xFF3182CE),
                  tooltip: 'Détails',
                  onPressed: () => _showStudentDetailsDialog(student),
                  semanticLabel: 'Voir détails',
                ),
                const SizedBox(width: 8),
                _buildModernActionButton(
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF38A169),
                  tooltip: 'Paiement',
                  onPressed: () => _showPaymentDialog(student),
                  semanticLabel: 'Ajouter paiement',
                ),
                const SizedBox(width: 8),
                _buildModernActionButton(
                  icon: Icons.description_rounded,
                  color: const Color(0xFFD69E2E),
                  tooltip: 'Bulletin (bientôt disponible)',
                  onPressed: null,
                  semanticLabel: 'Imprimer bulletin',
                ),
                const SizedBox(width: 8),
                _buildModernActionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF667EEA),
                  tooltip: 'Modifier',
                  onPressed: () => _editStudent(student),
                  semanticLabel: 'Modifier élève',
                ),
                const SizedBox(width: 8),
                _buildModernActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFE53E3E),
                  tooltip: 'Supprimer',
                  onPressed: () => _deleteStudent(student),
                  semanticLabel: 'Supprimer élève',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
    required String semanticLabel,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(onPressed != null ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color.withOpacity(onPressed != null ? 1.0 : 0.5),
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: Color(0xFF667EEA),
              semanticLabel: 'Aucun élève',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun élève dans cette classe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium!.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez par ajouter des élèves à cette classe',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium!.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Student>> _getFilteredAndSortedStudentsAsync() async {
    final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
    final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
    final double montantMax = fraisEcole + fraisCotisation;
    List<Student> filtered = [];
    for (final student in _students) {
      final totalPaid = await _dbService.getTotalPaidForStudent(student.id);
      final isPaid = montantMax > 0 && totalPaid >= montantMax;
      final status = isPaid ? 'Payé' : 'En attente';
      final query = _studentSearchQuery.toLowerCase();
      final matchSearch = _studentSearchQuery.isEmpty ||
        student.name.toLowerCase().contains(query) ||
        student.id.toLowerCase().contains(query) ||
        (student.gender == 'M' && 'garçon'.contains(query)) ||
        (student.gender == 'F' && 'fille'.contains(query));
      if (_studentStatusFilter == 'Tous' && matchSearch) {
        filtered.add(student);
      } else if (_studentStatusFilter == status && matchSearch) {
        filtered.add(student);
      }
    }
    filtered.sort((a, b) {
      int compare;
      if (_sortBy == 'name') {
        compare = a.name.compareTo(b.name);
      } else {
        compare = a.id.compareTo(b.id);
      }
      return _sortAscending ? compare : -compare;
    });
    return filtered;
  }

  Widget _buildSortControls() {
    return Row(
      children: [
        Text(
          'Trier par : ',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
        DropdownButton<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'name', child: Text('Nom')),
            DropdownMenuItem(value: 'id', child: Text('ID')),
          ],
          onChanged: (value) => setState(() => _sortBy = value!),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
          underline: const SizedBox(),
        ),
        IconButton(
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
          onPressed: () => setState(() => _sortAscending = !_sortAscending),
          tooltip: _sortAscending ? 'Tri ascendant' : 'Tri descendant',
        ),
      ],
    );
  }

  void _showStudentDetailsDialog(Student student) async {
    final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
    final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
    final double montantMax = fraisEcole + fraisCotisation;
    final totalPaid = await _dbService.getTotalPaidForStudent(student.id);
    final reste = montantMax - totalPaid;
    final status = (montantMax > 0 && totalPaid >= montantMax) ? 'Payé' : 'En attente';
    final allPayments = await _dbService.getPaymentsForStudent(student.id);
    final db = await _dbService.database;
    final List<Map<String, dynamic>> allMaps = await db.query(
      'payments',
      where: 'studentId = ?',
      whereArgs: [student.id],
      orderBy: 'date DESC',
    );
    final payments = allMaps.map((m) => Payment.fromMap(m)).toList();
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: 'Détails de l\'élève',
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (student.photoPath != null && student.photoPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(student.photoPath!),
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.error, color: Colors.red)),
                    ),
                  ),
                ),
              _buildDetailRow('Nom complet', student.name),
              _buildDetailRow('ID', student.id),
              _buildDetailRow('Date de naissance', student.dateOfBirth),
              _buildDetailRow('Sexe', student.gender == 'M' ? 'Garçon' : 'Fille'),
              _buildDetailRow('Classe', student.className),
              _buildDetailRow('Adresse', student.address),
              _buildDetailRow('Contact', student.contactNumber),
              _buildDetailRow('Email', student.email),
              _buildDetailRow('Contact d\'urgence', student.emergencyContact),
              _buildDetailRow('Tuteur', student.guardianName),
              _buildDetailRow('Contact tuteur', student.guardianContact),
              if (student.medicalInfo != null && student.medicalInfo!.isNotEmpty)
                _buildDetailRow('Infos médicales', student.medicalInfo!),
              const SizedBox(height: 16),
              Divider(),
              Text('Paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _buildDetailRow('Montant dû', '${montantMax.toStringAsFixed(2)} FCFA'),
              _buildDetailRow('Déjà payé', '${totalPaid.toStringAsFixed(2)} FCFA'),
              _buildDetailRow('Reste à payer', '${reste.toStringAsFixed(2)} FCFA'),
              _buildDetailRow('Statut', status),
              const SizedBox(height: 8),
              if (payments.isNotEmpty) ...[
                Text('Historique des paiements', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...payments.map((p) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: p.isCancelled ? Colors.grey.shade200 : null,
                  child: ListTile(
                    leading: Icon(Icons.attach_money, color: p.isCancelled ? Colors.grey : Colors.green),
                    title: Row(
                      children: [
                        Text('${p.amount.toStringAsFixed(2)} FCFA', style: TextStyle(
                          color: p.isCancelled ? Colors.grey : null,
                          decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                        )),
                        if (p.isCancelled)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('(Annulé)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.date.replaceFirst('T', ' ').substring(0, 16)}', style: TextStyle(color: p.isCancelled ? Colors.grey : null)),
                        if (p.comment != null && p.comment!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Commentaire : ${p.comment!}', style: TextStyle(color: Colors.deepPurple, fontStyle: FontStyle.italic)),
                          ),
                        if (p.isCancelled && p.cancelledAt != null)
                          Text('Annulé le ${p.cancelledAt!.replaceFirst('T', ' ').substring(0, 16)}', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    trailing: p.isCancelled
                      ? Icon(Icons.block, color: Colors.grey)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.print, color: Colors.blue),
                              tooltip: 'Imprimer le reçu',
                              onPressed: () => _printReceipt(p, student),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Annuler ce paiement',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => CustomDialog(
                                    title: 'Confirmer l\'annulation',
                                    content: const Text('Voulez-vous vraiment annuler ce paiement ? Cette action est irréversible.'),
                                    fields: const [],
                                    onSubmit: () => Navigator.of(context).pop(true),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Annuler'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Confirmer'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _dbService.cancelPayment(p.id!);
                                  Navigator.of(context).pop();
                                  _showModernSnackBar('Paiement annulé');
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                  ),
                )),
              ] else ...[
                Text('Aucun paiement enregistré.'),
              ],
            ],
          ),
        ),
        fields: const [],
        onSubmit: () => Navigator.of(context).pop(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Student student) async {
    final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
    final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
    final double montantMax = fraisEcole + fraisCotisation;
    if (montantMax == 0) {
      showDialog(
        context: context,
        builder: (context) => CustomDialog(
          title: 'Alerte',
          content: const Text('Veuillez renseigner un montant de frais d\'école ou de cotisation dans la fiche classe avant d\'enregistrer un paiement.'),
          fields: const [],
          onSubmit: () => Navigator.of(context).pop(),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final montantController = TextEditingController(text: '0');
    final commentController = TextEditingController();
    final totalPaid = await _dbService.getTotalPaidForStudent(student.id);
    final reste = montantMax - totalPaid;
    if (reste <= 0) {
      showDialog(
        context: context,
        builder: (context) => CustomDialog(
          title: 'Alerte',
          content: const Text('L\'élève a déjà tout payé pour cette classe.'),
          fields: const [],
          onSubmit: () => Navigator.of(context).pop(),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    void showMontantDepasseAlerte() {
      showDialog(
        context: context,
        builder: (context) => CustomDialog(
          title: 'Montant trop élevé',
          content: Text('Le montant saisi dépasse le solde dû (${reste.toStringAsFixed(2)} FCFA).'),
          fields: const [],
          onSubmit: () => Navigator.of(context).pop(),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: 'Paiement pour ${student.name}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant maximum autorisé : ${reste.toStringAsFixed(2)} FCFA', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Déjà payé : ${totalPaid.toStringAsFixed(2)} FCFA'),
            const SizedBox(height: 12),
            CustomFormField(
              controller: montantController,
              labelText: 'Montant à payer',
              hintText: 'Saisir le montant',
              suffixIcon: Icons.attach_money,
              validator: (value) {
                final val = double.tryParse(value ?? '');
                if (val == null || val < 0) return 'Montant invalide';
                if (val > reste) return 'Ne peut excéder $reste';
                return null;
              },
            ),
            const SizedBox(height: 12),
            CustomFormField(
              controller: commentController,
              labelText: 'Commentaire (optionnel)',
              hintText: 'Ex: acompte, solde, etc.',
              suffixIcon: Icons.comment,
            ),
          ],
        ),
        fields: const [],
        onSubmit: () async {
          final val = double.tryParse(montantController.text);
          if (val == null || val < 0) return;
          if (val > reste) {
            showMontantDepasseAlerte();
            return;
          }
          final payment = Payment(
            studentId: student.id,
            className: student.className,
            amount: val,
            date: DateTime.now().toIso8601String(),
            comment: commentController.text.isNotEmpty ? commentController.text : null,
          );
          await _dbService.insertPayment(payment);
          Navigator.of(context).pop();
          _showModernSnackBar('Paiement enregistré !');
          setState(() {});
        },
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(montantController.text);
              if (val == null || val < 0) return;
              if (val > reste) {
                showMontantDepasseAlerte();
                return;
              }
              final payment = Payment(
                studentId: student.id,
                className: student.className,
                amount: val,
                date: DateTime.now().toIso8601String(),
                comment: commentController.text.isNotEmpty ? commentController.text : null,
              );
              await _dbService.insertPayment(payment);
              Navigator.of(context).pop();
              _showModernSnackBar('Paiement enregistré !');
              setState(() {});
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(Payment p, Student student) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Élève : ${student.name}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('Classe : ${student.className}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('ID : ${student.id}', style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.Text('Montant payé : ${p.amount.toStringAsFixed(2)} FCFA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date : ${p.date.replaceFirst('T', ' ').substring(0, 16)}', style: pw.TextStyle(fontSize: 14)),
              if (p.comment != null && p.comment!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text('Commentaire : ${p.comment!}', style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic)),
                ),
              if (p.isCancelled)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text('ANNULÉ le ${p.cancelledAt?.replaceFirst('T', ' ').substring(0, 16) ?? ''}', style: pw.TextStyle(color: PdfColor.fromInt(0xFFFF0000), fontWeight: pw.FontWeight.bold)),
                ),
              pw.SizedBox(height: 24),
              pw.Text('Signature : ___________________________', style: pw.TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: AppStrings.classDetailsTitle,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Boutons d'export PDF/Excel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _exportStudentsPdf,
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                          label: const Text('Exporter PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _exportStudentsExcel,
                          icon: const Icon(Icons.grid_on, color: Colors.white),
                          label: const Text('Exporter Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _exportStudentsWord,
                          icon: const Icon(Icons.description, color: Colors.white),
                          label: const Text('Exporter Word'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildModernSectionTitle('Informations sur la classe', Icons.class_rounded),
                    _buildModernFormCard([
                      CustomFormField(
                        controller: _nameController,
                        labelText: AppStrings.classNameDialog,
                        hintText: 'Entrez le nom de la classe',
                        validator: (value) => value!.isEmpty ? AppStrings.required : null,
                      ),
                      CustomFormField(
                        controller: _yearController,
                        labelText: AppStrings.academicYearDialog,
                        hintText: "Entrez l'année scolaire",
                        validator: (value) => value!.isEmpty ? AppStrings.required : null,
                      ),
                      CustomFormField(
                        controller: _titulaireController,
                        labelText: 'Titulaire',
                        hintText: 'Nom du titulaire de la classe',
                      ),
                      CustomFormField(
                        controller: _fraisEcoleController,
                        labelText: "Frais d'école",
                        hintText: "Montant des frais d'école",
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Veuillez entrer un montant valide';
                          }
                          return null;
                        },
                      ),
                      CustomFormField(
                        controller: _fraisCotisationParalleleController,
                        labelText: 'Frais de cotisation parallèle',
                        hintText: 'Montant des frais de cotisation parallèle',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                            return 'Veuillez entrer un montant valide';
                          }
                          return null;
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildModernSectionTitle('Élèves de la classe', Icons.people_rounded),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Ajouter un élève'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3182CE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final GlobalKey<StudentRegistrationFormState> studentFormKey = GlobalKey<StudentRegistrationFormState>();
                            await showDialog(
                              context: context,
                              builder: (context) => CustomDialog(
                                title: 'Ajouter un élève',
                                content: StudentRegistrationForm(
                                  key: studentFormKey,
                                  className: _nameController.text, // pré-rempli
                                  classFieldReadOnly: true, // à gérer dans le form
                                  onSubmit: () async {
                                    final refreshedStudents = (await _dbService.getStudents()).where((s) => s.className == _nameController.text).toList();
                                    setState(() {
                                      _students = refreshedStudents;
                                    });
                                    Navigator.of(context).pop();
                                    _showModernSnackBar('Élève ajouté avec succès !');
                                  },
                                ),
                                fields: const [],
                                onSubmit: () {
                                  studentFormKey.currentState?.submitForm();
                                },
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _buildModernSearchField()),
                        const SizedBox(width: 16),
                        _buildSortControls(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Student>>(
                      future: _getFilteredAndSortedStudentsAsync(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final filteredStudents = snapshot.data!;
                        if (filteredStudents.isEmpty) {
                          return _buildEmptyState();
                        }
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return _buildModernStudentCard(student);
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildModernSectionTitle('Matières de la classe', Icons.book),
                    FutureBuilder<List<Course>>(
                      future: _dbService.getCoursesForClass(_nameController.text),
                      builder: (context, snapshot) {
                        final List<Course> classCourses = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (classCourses.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text('Aucune matière associée à cette classe.', style: TextStyle(color: Colors.grey)),
                              ),
                            ...classCourses.map((course) => ListTile(
                              title: Text(course.name),
                              subtitle: course.description != null && course.description!.isNotEmpty ? Text(course.description!) : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Modifier cette matière',
                                    onPressed: () async {
                                      final nameController = TextEditingController(text: course.name);
                                      final descController = TextEditingController(text: course.description ?? '');
                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Modifier la matière'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: nameController,
                                                decoration: InputDecoration(labelText: 'Nom'),
                                              ),
                                              TextField(
                                                controller: descController,
                                                decoration: InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: Text('Annuler'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final newName = nameController.text.trim();
                                                final newDesc = descController.text.trim();
                                                if (newName.isEmpty) return;
                                                final updated = Course(id: course.id, name: newName, description: newDesc.isNotEmpty ? newDesc : null);
                                                await _dbService.updateCourse(course.id, updated);
                                                Navigator.of(context).pop();
                                                setState(() {});
                                              },
                                              child: Text('Enregistrer'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Retirer cette matière',
                                    onPressed: () async {
                                      await _dbService.removeCourseFromClass(_nameController.text, course.id);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: Icon(Icons.add),
                              label: Text('Ajouter des matières'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final allCourses = await _dbService.getCourses();
                                final classCourseIds = classCourses.map((c) => c.id).toSet();
                                final availableCourses = allCourses.where((c) => !classCourseIds.contains(c.id)).toList();
                                if (availableCourses.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Aucune matière disponible à ajouter.'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }
                                final Map<String, bool> selected = {
                                  for (final course in availableCourses) course.id: false
                                };
                                await showDialog(
                                  context: context,
                                  builder: (context) => StatefulBuilder(
                                    builder: (context, setStateDialog) => AlertDialog(
                                      title: Text('Ajouter des matières à la classe'),
                                      content: SizedBox(
                                        width: 350,
                                        child: ListView(
                                          shrinkWrap: true,
                                          children: availableCourses.map((course) => CheckboxListTile(
                                            value: selected[course.id],
                                            title: Text(course.name),
                                            subtitle: course.description != null && course.description!.isNotEmpty ? Text(course.description!) : null,
                                            onChanged: (val) {
                                              setStateDialog(() => selected[course.id] = val ?? false);
                                            },
                                          )).toList(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          onPressed: selected.values.any((v) => v)
                                              ? () async {
                                                  for (final entry in selected.entries) {
                                                    if (entry.value) {
                                                      await _dbService.addCourseToClass(_nameController.text, entry.key);
                                                    }
                                                  }
                                                  Navigator.of(context).pop();
                                                  setState(() {});
                                                }
                                              : null,
                                          child: Text('Ajouter'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      fields: const [],
      onSubmit: () {
        if (!_isLoading) _saveClass();
      },
      actions: [
        OutlinedButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: const Text(
            'Fermer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _copyClass,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38A169),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text(
            'Copier la classe',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsAndFilter() {
    return FutureBuilder<List<double>>(
      future: _getStatsForStudents(),
      builder: (context, snapshot) {
        final int nbPayes = snapshot.hasData ? snapshot.data![0].toInt() : 0;
        final int nbAttente = snapshot.hasData ? snapshot.data![1].toInt() : 0;
        final int total = nbPayes + nbAttente;
        final double percent = total > 0 ? (nbPayes / total * 100) : 0;
        return Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
              child: Text('Payé : $nbPayes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
              child: Text('En attente : $nbAttente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Text('Paiement global : ${percent.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<String>(
              value: _studentStatusFilter,
              items: const [
                DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                DropdownMenuItem(value: 'Payé', child: Text('Payé')),
                DropdownMenuItem(value: 'En attente', child: Text('En attente')),
              ],
              onChanged: (value) => setState(() => _studentStatusFilter = value!),
            ),
          ],
        );
      },
    );
  }

  Future<List<double>> _getStatsForStudents() async {
    int nbPayes = 0;
    int nbAttente = 0;
    final double fraisEcole = double.tryParse(_fraisEcoleController.text) ?? 0;
    final double fraisCotisation = double.tryParse(_fraisCotisationParalleleController.text) ?? 0;
    final double montantMax = fraisEcole + fraisCotisation;
    for (final s in _students) {
      final totalPaid = await _dbService.getTotalPaidForStudent(s.id);
      if (montantMax > 0 && totalPaid >= montantMax) {
        nbPayes++;
      } else {
        nbAttente++;
      }
    }
    return [nbPayes.toDouble(), nbAttente.toDouble()];
  }

  void _exportStudentsPdf() async {
    try {
      final studentsList = _students.map((student) {
        final classe = widget.classe;
        return {'student': student, 'classe': classe};
      }).toList();
      final pdfBytes = await PdfService.exportStudentsListPdf(students: studentsList);
      final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisissez un dossier de sauvegarde');
      if (dirPath == null) return; // Annulé
      final file = File('$dirPath/export_eleves_${widget.classe.name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export PDF réussi : ${file.path}')),
      );
    } catch (e) {
      print('Erreur export PDF élèves : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export PDF : $e')),
      );
    }
  }

  void _exportStudentsExcel() async {
    try {
      final studentsList = _students.map((student) {
        final classe = widget.classe;
        return {'student': student, 'classe': classe};
      }).toList();
      // Trie par nom
      studentsList.sort((a, b) => ((a['student'] as Student).name).compareTo((b['student'] as Student).name));
      final excel = Excel.createExcel();
      final sheet = excel['Élèves'];
      // En-têtes
      sheet.appendRow([
        TextCellValue('N°'),
        TextCellValue('Nom'),
        TextCellValue('Prénom'),
        TextCellValue('Sexe'),
        TextCellValue('Classe'),
        TextCellValue('Année'),
        TextCellValue('Date de naissance'),
        TextCellValue('Adresse'),
        TextCellValue('Contact'),
        TextCellValue('Email'),
        TextCellValue('Tuteur'),
        TextCellValue('Contact tuteur'),
      ]);
      for (int i = 0; i < studentsList.length; i++) {
        final student = studentsList[i]['student'] as Student;
        final classe = studentsList[i]['classe'];
        final names = student.name.split(' ');
        final prenom = names.length > 1 ? names.sublist(1).join(' ') : '';
        final nom = names.isNotEmpty ? names[0] : '';
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(nom),
          TextCellValue(prenom),
          TextCellValue(student.gender == 'M' ? 'Garçon' : 'Fille'),
          TextCellValue(student.className),
          TextCellValue((classe as Class?)?.academicYear ?? ''),
          TextCellValue(student.dateOfBirth ?? ''),
          TextCellValue(student.address ?? ''),
          TextCellValue(student.contactNumber ?? ''),
          TextCellValue(student.email ?? ''),
          TextCellValue(student.guardianName ?? ''),
          TextCellValue(student.guardianContact),
        ]);
      }
      final bytes = excel.encode()!;
      final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisissez un dossier de sauvegarde');
      if (dirPath == null) return; // Annulé
      final file = File('$dirPath/export_eleves_${widget.classe.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export Excel réussi : ${file.path}')),
      );
    } catch (e) {
      print('Erreur export Excel élèves : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export Excel : $e')),
      );
    }
  }

  void _exportStudentsWord() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisissez un dossier de sauvegarde');
      if (dirPath == null) return; // Annulé
      final docx = await _generateStudentsDocx();
      final file = File('$dirPath/export_eleves_${widget.classe.name}_${DateTime.now().millisecondsSinceEpoch}.docx');
      await file.writeAsBytes(docx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export Word réussi : ${file.path}')),
      );
    } catch (e) {
      print('Erreur export Word élèves : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export Word : $e')),
      );
    }
  }

  Future<List<int>> _generateStudentsDocx() async {
    try {
      final bytes = await DefaultAssetBundle.of(context).load('assets/empty.docx');
      final docx = await DocxTemplate.fromBytes(bytes.buffer.asUint8List());
      final studentsList = List<Map<String, dynamic>>.from(
        _students.map((student) {
          final classe = widget.classe;
          return {'student': student, 'classe': classe};
        }),
      );
      studentsList.sort((a, b) => ((a['student'] as Student).name).compareTo((b['student'] as Student).name));
      final rows = List<RowContent>.generate(studentsList.length, (i) {
        final student = studentsList[i]['student'] as Student;
        final classe = studentsList[i]['classe'] as Class;
        final names = student.name.split(' ');
        final prenom = names.length > 1 ? names.sublist(1).join(' ') : '';
        final nom = names.isNotEmpty ? names[0] : '';
        return RowContent()
          ..add(TextContent("numero", (i + 1).toString()))
          ..add(TextContent("nom", nom))
          ..add(TextContent("prenom", prenom))
          ..add(TextContent("sexe", student.gender == 'M' ? 'Garçon' : 'Fille'))
          ..add(TextContent("classe", student.className))
          ..add(TextContent("annee", classe.academicYear))
          ..add(TextContent("date_naissance", student.dateOfBirth ?? ''))
          ..add(TextContent("adresse", student.address ?? ''))
          ..add(TextContent("contact", student.contactNumber ?? ''))
          ..add(TextContent("email", student.email ?? ''))
          ..add(TextContent("tuteur", student.guardianName ?? ''))
          ..add(TextContent("contact_tuteur", student.guardianContact ?? ''));
      });
      final table = TableContent("eleves", List<RowContent>.from(rows));
      final content = Content()..add(table);
      final d = await docx.generate(content);
      return d!;
    } catch (e) {
      print('Erreur asset Word élèves : $e');
      rethrow;
    }
  }
}
