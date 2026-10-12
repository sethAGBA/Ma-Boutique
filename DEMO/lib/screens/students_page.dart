import 'package:flutter/material.dart';
import 'package:school_manager/screens/dashboard_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_manager/constants/colors.dart';
import 'package:school_manager/constants/sizes.dart';
import 'package:school_manager/constants/strings.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/screens/students/class_details_page.dart';
import 'package:school_manager/screens/students/widgets/chart_card.dart';
import 'package:school_manager/screens/students/widgets/custom_dialog.dart';
import 'package:school_manager/screens/students/widgets/form_field.dart';
import 'package:school_manager/screens/students/widgets/student_registration_form.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/screens/students/student_profile_page.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:school_manager/utils/academic_year.dart';

class StudentsPage extends StatefulWidget {
  @override
  _StudentsPageState createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, int> _classDistribution = {};
  Map<String, int> _academicYearDistribution = {};
  List<Map<String, dynamic>> _tableData = [];

  // Filtres sélectionnés
  String? _selectedClassFilter;
  String? _selectedGenderFilter;
  String? _selectedYearFilter;

  String _searchQuery = '';
  String _currentAcademicYear = '2024-2025';

  @override
  void initState() {
    super.initState();
    academicYearNotifier.addListener(_onAcademicYearChanged);
    getCurrentAcademicYear().then((year) {
      setState(() {
        _currentAcademicYear = year;
        if (_selectedYearFilter == null) {
          _selectedYearFilter = year;
        }
      });
      _loadData();
    });
  }

  void _onAcademicYearChanged() {
    setState(() {
      _currentAcademicYear = academicYearNotifier.value;
      _selectedYearFilter = academicYearNotifier.value;
    });
    _loadData();
  }

  @override
  void dispose() {
    academicYearNotifier.removeListener(_onAcademicYearChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final classDist = await _dbService.getClassDistribution();
    final yearDist = await _dbService.getAcademicYearDistribution();
    final students = await _dbService.getStudents();
    final classes = await _dbService.getClasses();

    final tableData = classes.map((cls) {
      final studentCount = classDist[cls.name] ?? 0;
      final boys = students.where((s) => s.className == cls.name && s.gender == 'M').length;
      final girls = students.where((s) => s.className == cls.name && s.gender == 'F').length;
      return {
        'className': cls.name,
        'total': studentCount.toString(),
        'boys': boys.toString(),
        'girls': girls.toString(),
        'year': cls.academicYear,
      };
    }).toList();

    setState(() {
      _classDistribution = classDist;
      _academicYearDistribution = yearDist;
      _tableData = tableData;
    });
  }

  List<Map<String, dynamic>> get _filteredTableData {
    return _tableData.where((data) {
      final matchClass = _selectedClassFilter == null || data['className'] == _selectedClassFilter;
      final matchYear = _selectedYearFilter == null || data['year'] == _selectedYearFilter;
      if (_selectedGenderFilter != null) {
        if (_selectedGenderFilter == 'M' && data['boys'] == '0') return false;
        if (_selectedGenderFilter == 'F' && data['girls'] == '0') return false;
      }
      final matchSearch = _searchQuery.isEmpty ||
        data['className'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        data['year'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchClass && matchYear && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSizes.padding),
          child: Container(
            constraints: BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                SizedBox(height: AppSizes.padding),
                _buildActionButtons(context),
                SizedBox(height: AppSizes.padding),
                _buildFilters(context),
                SizedBox(height: AppSizes.padding),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChartsSection(context, constraints),
                        SizedBox(height: AppSizes.padding),
                        _buildDataTable(context),
                        SizedBox(height: AppSizes.padding),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // To push notification icon to the end
            children: [
              Row( // This inner Row contains the icon, title, and description
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people,
                      color: Colors.white,
                      size: isDesktop ? 32 : 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column( // Title and description
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.studentsTitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color, // Use bodyLarge for title
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gérez les informations des élèves, leurs classes et leurs performances académiques.',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7), // Use bodyMedium for description
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Notification icon back in place
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowDark.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: theme.iconTheme.color,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une classe ou un élève...',
              hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final classList = _tableData.map((e) => e['className'] as String).toSet().toList();
    final yearList = _tableData.map((e) => e['year'] as String).toSet().toList();
    return Wrap(
      spacing: AppSizes.smallSpacing,
      runSpacing: AppSizes.smallSpacing,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedClassFilter,
              hint: Text(AppStrings.classFilter, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('Toutes les classes', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
                ...classList.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)))),
              ],
              onChanged: (value) => setState(() => _selectedClassFilter = value),
              dropdownColor: Theme.of(context).cardColor,
              iconEnabledColor: Theme.of(context).iconTheme.color,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedGenderFilter,
              hint: Text(AppStrings.genderFilter, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('Tous', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
                DropdownMenuItem<String?>(value: 'M', child: Text('Garçons', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
                DropdownMenuItem<String?>(value: 'F', child: Text('Filles', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
              ],
              onChanged: (value) => setState(() => _selectedGenderFilter = value),
              dropdownColor: Theme.of(context).cardColor,
              iconEnabledColor: Theme.of(context).iconTheme.color,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
            ),
          ),
        ),
        ValueListenableBuilder<String>(
          valueListenable: academicYearNotifier,
          builder: (context, currentYear, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedYearFilter,
                  hint: Text(AppStrings.yearFilter, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('Toutes les années', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
                    DropdownMenuItem<String?>(value: currentYear, child: Text('Année courante ($currentYear)', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color))),
                    ...yearList.where((y) => y != currentYear).map((y) => DropdownMenuItem<String?>(value: y, child: Text(y, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)))),
                  ],
                  onChanged: (value) => setState(() => _selectedYearFilter = value),
                  dropdownColor: Theme.of(context).cardColor,
                  iconEnabledColor: Theme.of(context).iconTheme.color,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
                ),
              ),
            );
          },
        ),
        if (_selectedClassFilter != null || _selectedGenderFilter != null || _selectedYearFilter != null)
          TextButton.icon(
            onPressed: () => setState(() {
              _selectedClassFilter = null;
              _selectedGenderFilter = null;
              _selectedYearFilter = _currentAcademicYear;
            }),
            icon: Icon(Icons.clear, color: Theme.of(context).textTheme.bodyMedium!.color),
            label: Text('Réinitialiser', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
          ),
      ],
    );
  }

  Widget _buildChartsSection(BuildContext context, BoxConstraints constraints) {
    return constraints.maxWidth > 600
        ? Row(
            children: [
              Expanded(
                child: ChartCard(
                  title: AppStrings.classDistributionTitle,
                  total: _classDistribution.values.fold(0, (a, b) => a + b).toString(),
                  percentage: _classDistribution.isEmpty ? '0%' : '+12%',
                  maxY: (_classDistribution.values.isEmpty ? 1 : _classDistribution.values.reduce((a, b) => a > b ? a : b)).toDouble() + 10,
                  bottomTitles: _classDistribution.keys.toList(),
                  barValues: _classDistribution.values.map((e) => e.toDouble()).toList(),
                  aspectRatio: AppSizes.chartAspectRatio,
                ),
              ),
              SizedBox(width: AppSizes.spacing),
              Expanded(
                child: ChartCard(
                  title: AppStrings.academicYearTitle,
                  total: _academicYearDistribution.values.fold(0, (a, b) => a + b).toString(),
                  percentage: _academicYearDistribution.isEmpty ? '0%' : '+5%',
                  maxY: (_academicYearDistribution.values.isEmpty ? 1 : _academicYearDistribution.values.reduce((a, b) => a > b ? a : b)).toDouble() + 10,
                  bottomTitles: _academicYearDistribution.keys.toList(),
                  barValues: _academicYearDistribution.values.map((e) => e.toDouble()).toList(),
                  aspectRatio: AppSizes.chartAspectRatio,
                ),
              ),
            ],
          )
        : Column(
            children: [
              ChartCard(
                title: AppStrings.classDistributionTitle,
                total: _classDistribution.values.fold(0, (a, b) => a + b).toString(),
                percentage: _classDistribution.isEmpty ? '0%' : '+12%',
                maxY: (_classDistribution.values.isEmpty ? 1 : _classDistribution.values.reduce((a, b) => a > b ? a : b)).toDouble() + 10,
                bottomTitles: _classDistribution.keys.toList(),
                barValues: _classDistribution.values.map((e) => e.toDouble()).toList(),
                aspectRatio: AppSizes.chartAspectRatio,
              ),
              SizedBox(height: AppSizes.spacing),
              ChartCard(
                title: AppStrings.academicYearTitle,
                total: _academicYearDistribution.values.fold(0, (a, b) => a + b).toString(),
                percentage: _academicYearDistribution.isEmpty ? '0%' : '+5%',
                maxY: (_academicYearDistribution.values.isEmpty ? 1 : _academicYearDistribution.values.reduce((a, b) => a > b ? a : b)).toDouble() + 10,
                bottomTitles: _academicYearDistribution.keys.toList(),
                barValues: _academicYearDistribution.values.map((e) => e.toDouble()).toList(),
                aspectRatio: AppSizes.chartAspectRatio,
              ),
            ],
          );
  }

  Widget _buildDataTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(
              label: Text(
                AppStrings.classLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                AppStrings.totalStudentsLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                AppStrings.boysLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                AppStrings.girlsLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                AppStrings.academicYearLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                AppStrings.actionsLabel,
                style: TextStyle(
                  fontSize: AppSizes.textFontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
            ),
          ],
          rows: _filteredTableData.map((data) => _buildRow(
            context,
            data['className'],
            data['total'],
            data['boys'],
            data['girls'],
            data['year'],
          )).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    String className,
    String total,
    String male,
    String female,
    String year,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            className,
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ),
        DataCell(
          Text(
            total,
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
        DataCell(
          Text(
            male,
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
        DataCell(
          Text(
            female,
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
        DataCell(
          Text(
            year,
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final students = await DatabaseService().getStudents();
                  final classStudents = students.where((s) => s.className == className).toList();
                  final classes = await DatabaseService().getClasses();
                  final classObj = classes.firstWhere((c) => c.name == className);
                  await showDialog(
                    context: context,
                    builder: (context) => ClassDetailsPage(
                      classe: classObj,
                      students: classStudents,
                    ),
                  );
                  await _loadData();
                },
                child: Text(
                  AppStrings.viewDetails,
                  style: TextStyle(
                    fontSize: AppSizes.textFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              ),
              
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final GlobalKey<StudentRegistrationFormState> studentFormKey = GlobalKey<StudentRegistrationFormState>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () {
            print('Ajouter un Élève button pressed');
            try {
              showDialog(
                context: context,
                builder: (context) => CustomDialog(
                  title: AppStrings.addStudent,
                  content: StudentRegistrationForm(
                    key: studentFormKey,
                    onSubmit: () {
                      print('Student form submitted');
                      _loadData();
                      Navigator.pop(context);
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
            } catch (e) {
              print('Error opening student dialog: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: null,
          ),
          child: const Text(
            'Ajouter un élève',
            style: TextStyle(fontSize: AppSizes.textFontSize, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _ClassDialog(
                onSubmit: () => _loadData(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          child: const Text(
            'Ajouter une classe',
            style: TextStyle(fontSize: AppSizes.textFontSize, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ClassDialog extends StatefulWidget {
  final VoidCallback onSubmit;

  const _ClassDialog({required this.onSubmit});

  @override
  State<_ClassDialog> createState() => __ClassDialogState();
}

class __ClassDialogState extends State<_ClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final classNameController = TextEditingController();
  final academicYearController = TextEditingController();
  final titulaireController = TextEditingController();
  final fraisEcoleController = TextEditingController();
  final fraisCotisationParalleleController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    academicYearController.text = academicYearNotifier.value;
  }

  @override
  void dispose() {
    classNameController.dispose();
    academicYearController.dispose();
    titulaireController.dispose();
    fraisEcoleController.dispose();
    fraisCotisationParalleleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: AppStrings.addClass,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomFormField(
              controller: classNameController,
              labelText: AppStrings.classNameDialog,
              hintText: 'Enter le nom de la classe',
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            const SizedBox(height: AppSizes.smallSpacing),
            CustomFormField(
              controller: academicYearController,
              labelText: AppStrings.academicYearDialog,
              hintText: 'Enter l\'année scolaire',
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            const SizedBox(height: AppSizes.smallSpacing),
            CustomFormField(
              controller: titulaireController,
              labelText: 'Titulaire',
              hintText: 'Nom du titulaire de la classe',
            ),
            const SizedBox(height: AppSizes.smallSpacing),
            CustomFormField(
              controller: fraisEcoleController,
              labelText: 'Frais d\'école',
              hintText: 'Montant des frais d\'école',
              validator: (value) {
                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                  return 'Veuillez entrer un montant valide';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.smallSpacing),
            CustomFormField(
              controller: fraisCotisationParalleleController,
              labelText: 'Frais de cotisation parallèle',
              hintText: 'Montant des frais de cotisation parallèle',
              validator: (value) {
                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                  return 'Veuillez entrer un montant valide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      fields: const [],
      onSubmit: () async {
        if (_formKey.currentState!.validate()) {
          try {
            final cls = Class(
              name: classNameController.text,
              academicYear: academicYearController.text,
              titulaire: titulaireController.text.isNotEmpty ? titulaireController.text : null,
              fraisEcole: fraisEcoleController.text.isNotEmpty ? double.tryParse(fraisEcoleController.text) : null,
              fraisCotisationParallele: fraisCotisationParalleleController.text.isNotEmpty ? double.tryParse(fraisCotisationParalleleController.text) : null,
            );
            await _dbService.insertClass(cls);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Classe ajoutée avec succès!'),
                backgroundColor: Colors.green,
              ),
            );
            widget.onSubmit();
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
            );
          }
        }
      },
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}