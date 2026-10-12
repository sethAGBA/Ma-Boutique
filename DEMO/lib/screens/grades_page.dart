import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/models/course.dart';
import 'package:school_manager/models/grade.dart';
import 'package:school_manager/models/staff.dart';
import 'package:school_manager/screens/dashboard_home.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:school_manager/utils/academic_year.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:school_manager/services/pdf_service.dart';
import 'package:school_manager/models/school_info.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:pdf/pdf.dart' as pw; // removed unused import
import 'package:school_manager/screens/students/student_profile_page.dart';
import 'package:archive/archive_io.dart';

class AppColors {
  static const primaryBlue = Color(0xFF3B82F6);
  static const bluePrimary = Color(0xFF3B82F6);
  static const successGreen = Color(0xFF10B981);
  static const shadowDark = Color(0xFF000000);
}

// SchoolInfo et loadSchoolInfo déplacés dans `models/school_info.dart`

// Ajout du notifier global pour le niveau scolaire
final schoolLevelNotifier = ValueNotifier<String>('');

class GradesPage extends StatefulWidget {
  const GradesPage({Key? key}) : super(key: key);

  @override
  _GradesPageState createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String? selectedSubject;
  String? selectedTerm;
  String? selectedStudent;
  String? selectedAcademicYear;
  String? selectedClass;
  bool _isDarkMode = true;
  String _studentSearchQuery = '';
  String _reportSearchQuery = '';
  String _archiveSearchQuery = '';
  String _periodMode = 'Trimestre'; // ou 'Semestre'
  int _archiveCurrentPage = 0;
  final int _archiveItemsPerPage = 10;
  bool _searchAllYears = false;

  List<Student> students = [];
  List<Class> classes = [];
  List<Course> subjects = [];
  List<String> years = [];
  List<Grade> grades = [];
  List<Staff> staff = [];
  bool isLoading = true;

  final List<String> terms = [
    'Trimestre 1', 'Trimestre 2', 'Trimestre 3'
  ];

  final DatabaseService _dbService = DatabaseService();

  final TextEditingController studentSearchController = TextEditingController();
  final TextEditingController reportSearchController = TextEditingController();
  final TextEditingController archiveSearchController = TextEditingController();

  List<String> get _periods => _periodMode == 'Trimestre'
      ? ['Trimestre 1', 'Trimestre 2', 'Trimestre 3']
      : ['Semestre 1', 'Semestre 2'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    selectedTerm = _periods.first;
    academicYearNotifier.addListener(_onAcademicYearChanged);
    getCurrentAcademicYear().then((year) {
      setState(() {
        selectedAcademicYear = year;
      });
      _loadAllData();
    });
    // Initialiser le niveau scolaire depuis les préférences
    SharedPreferences.getInstance().then((prefs) {
      schoolLevelNotifier.value = prefs.getString('school_level') ?? '';
    });
  }

  void _onFilterChanged() async {
    setState(() => isLoading = true);
    if (selectedClass != null) {
      subjects = await _dbService.getCoursesForClass(selectedClass!);
      if (subjects.isNotEmpty && (selectedSubject == null || !subjects.any((c) => c.name == selectedSubject))) {
        selectedSubject = subjects.first.name;
      }
    } else {
      subjects = [];
      selectedSubject = null;
    }
    await _loadAllGradesForPeriod();
    setState(() => isLoading = false);
  }

  void _onAcademicYearChanged() {
    setState(() {
      selectedAcademicYear = academicYearNotifier.value;
    });
    _onFilterChanged();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    students = await _dbService.getStudents();
    classes = await _dbService.getClasses();
    staff = await _dbService.getStaff();
    years = classes.map((c) => c.academicYear).toSet().toList()..sort();
    // Sélections par défaut
    selectedClass = classes.isNotEmpty ? classes.first.name : null;
    selectedAcademicYear = years.isNotEmpty ? years.first : null;
    selectedStudent = 'all';
    // Charger les matières de la classe sélectionnée
    if (selectedClass != null) {
      subjects = await _dbService.getCoursesForClass(selectedClass!);
    } else {
      subjects = [];
    }
    selectedSubject = subjects.isNotEmpty ? subjects.first.name : null;
    await _loadAllGradesForPeriod();
    setState(() => isLoading = false);
  }

  Future<void> _loadAllGradesForPeriod() async {
    if (selectedClass != null && selectedAcademicYear != null && selectedTerm != null) {
      grades = await _dbService.getAllGradesForPeriod(
        className: selectedClass!,
        academicYear: selectedAcademicYear!,
        term: selectedTerm!,
      );
    } else {
      grades = [];
    }
  }

  @override
  void dispose() {
    academicYearNotifier.removeListener(_onAcademicYearChanged);
    _tabController.dispose();
    studentSearchController.dispose();
    reportSearchController.dispose();
    archiveSearchController.dispose();
    super.dispose();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Color(0xFFF9FAFB),
      cardColor: Colors.white,
      dividerColor: Color(0xFFE5E7EB),
      shadowColor: Colors.black.withOpacity(0.1),
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4F46E5)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF10B981),
        surface: Colors.white,
        onSurface: Color(0xFF1F2937),
        background: Color(0xFFF9FAFB),
        error: Color(0xFFEF4444),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF111827),
      cardColor: Color(0xFF1F2937),
      dividerColor: Color(0xFF374151),
      shadowColor: Colors.black.withOpacity(0.4),
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF9FAFB)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFD1D5DB)),
      ),
      iconTheme: IconThemeData(color: Color(0xFF818CF8)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF34D399),
        surface: Color(0xFF1F2937),
        onSurface: Color(0xFFF9FAFB),
        background: Color(0xFF111827),
        error: Color(0xFFF87171),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode, bool isDesktop) {
    final theme = Theme.of(context);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                      Icons.grade,
                      color: Colors.white,
                      size: isDesktop ? 32 : 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion des Notes',
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Système intégré de notation et bulletins',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildQuickActions(),
                  SizedBox(width: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    return Row(
      children: [
        _buildActionButton(
          Icons.upload_file,
          'Import CSV',
          theme.colorScheme.primary,
          () => _showImportDialog(),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          Icons.analytics,
          'Statistiques',
          theme.colorScheme.secondary,
          () => _showStatsDialog(),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Saisie Notes'),
          Tab(text: 'Bulletins'),
          Tab(text: 'Archives'),
        ],
      ),
    );
  }

  Widget _buildGradeInputTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(
            controller: studentSearchController,
            hintText: 'Rechercher un élève...',
            onChanged: (val) => setState(() => _studentSearchQuery = val),
          ),
          const SizedBox(height: 16),
          _buildSelectionSection(),
          const SizedBox(height: 24),
          _buildStudentGradesSection(),
          const SizedBox(height: 24),
          _buildGradeDistributionSection(),
        ],
      ),
    );
  }

  Widget _buildSelectionSection() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mode : ', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _periodMode,
                items: ['Trimestre', 'Semestre'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: theme.textTheme.bodyMedium))).toList(),
                onChanged: (val) {
                  setState(() {
                    _periodMode = val!;
                    selectedTerm = _periods.first;
                    _onFilterChanged();
                  });
                },
                dropdownColor: theme.cardColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune, color: theme.iconTheme.color, size: 24),
              const SizedBox(width: 12),
              Text(
                'Sélection Matière et Période',
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Matière',
                  selectedSubject ?? '',
                  subjects.map((c) => c.name).toList(),
                  (value) => setState(() => selectedSubject = value!),
                  Icons.book,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  _periodMode == 'Trimestre' ? 'Trimestre' : 'Semestre',
                  selectedTerm ?? '',
                  _periods,
                  (value) => setState(() => selectedTerm = value!),
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: academicYearNotifier,
                  builder: (context, currentYear, _) {
                    final yearList = years.toSet().toList();
                    return DropdownButton<String?>(
                      value: selectedAcademicYear,
                      hint: Text('Année Académique', style: theme.textTheme.bodyLarge),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Toutes les années'),
                        ),
                        DropdownMenuItem<String?>(
                          value: currentYear,
                          child: Text('Année courante ($currentYear)', style: theme.textTheme.bodyLarge),
                        ),
                        ...yearList
                            .where((y) => y != currentYear)
                            .map((y) => DropdownMenuItem<String?>(
                                  value: y,
                                  child: Text(y, style: theme.textTheme.bodyLarge),
                                )),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          selectedAcademicYear = value;
                        });
                        _onFilterChanged();
                      },
                      isExpanded: true,
                      dropdownColor: theme.cardColor,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  'Classe',
                  selectedClass ?? '',
                  classes.map((c) => c.name).toList(),
                  (value) => setState(() => selectedClass = value!),
                  Icons.class_,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged, IconData icon) {
    String? currentValue = (value != null && items.contains(value)) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).textTheme.bodyMedium?.color),
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).iconTheme.color, size: 18),
                    const SizedBox(width: 8),
                    Text(item, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )).toList(),
              onChanged: (val) {
                onChanged(val);
                _onFilterChanged();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentGradesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: Theme.of(context).iconTheme.color, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Notes des Élèves',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showBulkGradeDialog(),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Saisie Rapide'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildClassAverage(),
          _buildStudentGradesList(),
        ],
      ),
    );
  }

  Widget _buildClassAverage() {
    if (isLoading || grades.isEmpty || selectedSubject == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final classAvg = _calculateClassAverageForSubject(selectedSubject!);
    if (classAvg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.leaderboard, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Text('Moyenne de la classe : ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(classAvg.toStringAsFixed(2), style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudentGradesList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Filtrage dynamique des élèves
    List<Student> filteredStudents = students.where((s) {
      final classMatch = selectedClass == null || s.className == selectedClass;
      final classObj = classes.firstWhere((c) => c.name == s.className, orElse: () => Class.empty());
      final yearMatch = selectedAcademicYear == null || classObj.academicYear == selectedAcademicYear;
      final searchMatch = _studentSearchQuery.isEmpty || s.name.toLowerCase().contains(_studentSearchQuery.toLowerCase());
      return classMatch && yearMatch && searchMatch;
    }).toList();
    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.group_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucun élève trouvé.', style: TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      );
    }
    return Column(
      children: [
        ...filteredStudents.map((student) => _buildStudentGradeCard(student)).toList(),
      ],
    );
  }

  Widget _buildStudentGradeCard(Student student) {
    // Cherche la note existante pour cet élève et la sélection courante
    Grade? grade;
    try {
      grade = grades.firstWhere((g) =>
          g.studentId == student.id &&
          g.className == selectedClass &&
          g.academicYear == selectedAcademicYear &&
          g.term == selectedTerm &&
          (selectedSubject == null || g.subject == selectedSubject));
    } catch (_) {
      grade = null;
    }
    final controller = TextEditingController(text: grade != null ? grade.value.toString() : '');

    // Moyenne de l'élève pour la matière sélectionnée (ici, une seule note possible par élève/matière/trimestre)
    final double? studentAvg = grade?.value;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              student.name.isNotEmpty ? student.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join() : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Classe: ${student.className}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Note',
                labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              ),
              onSubmitted: (val) async {
                final note = double.tryParse(val);
                if (note != null && selectedClass != null && selectedAcademicYear != null && selectedSubject != null && selectedTerm != null) {
                  // Trouver l'id de la matière à partir du nom
                  final course = subjects.firstWhere((c) => c.name == selectedSubject, orElse: () => Course.empty());
                  final newGrade = Grade(
                    id: grade?.id,
                    studentId: student.id,
                    className: selectedClass!,
                    academicYear: selectedAcademicYear!,
                    subjectId: course.id,
                    subject: selectedSubject!,
                    term: selectedTerm!,
                    value: note,
                    label: grade?.label,
                  );
                  if (grade == null) {
                    await _dbService.insertGrade(newGrade);
                  } else {
                    await _dbService.updateGrade(newGrade);
                  }
                  await _loadAllGradesForPeriod();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Note enregistrée pour ${student.name}'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Icon(Icons.bar_chart, size: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
              Text(
                studentAvg != null ? studentAvg.toStringAsFixed(2) : '-',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.orange),
            tooltip: 'Modifier toutes les notes',
            onPressed: () => _showEditStudentGradesDialog(student),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Theme.of(context).iconTheme.color, size: 24),
              const SizedBox(width: 12),
              Text(
                'Répartition des Notes - ${selectedSubject ?? ""}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildGradeChart(),
        ],
      ),
    );
  }

  Widget _buildGradeChart() {
    final theme = Theme.of(context);
    final gradeDistribution = ['A', 'B', 'C', 'D', 'F'];
    final values = [0.6, 0.7, 0.8, 0.7, 0.4]; // Dummy data
    final colors = [
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
      Colors.grey.shade500
    ];

    return Container(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(gradeDistribution.length, (index) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${(values[index] * 100).toInt()}%',
                style: TextStyle(
                  color: colors[index],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: values[index] * 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [colors[index], colors[index].withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: colors[index].withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gradeDistribution[index],
                style: theme.textTheme.bodyMedium,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildReportCardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(
            controller: reportSearchController,
            hintText: 'Rechercher un élève (bulletin)...',
            onChanged: (val) => setState(() => _reportSearchQuery = val),
          ),
          const SizedBox(height: 16),
          _buildSelectionSection(),
          const SizedBox(height: 24),
          _buildReportCardSelection(),
          const SizedBox(height: 24),
          _buildReportCardPreview(),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
        prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      style: theme.textTheme.bodyLarge,
    );
  }

  Widget _buildReportCardSelection() {
    final filteredStudents = students.where((s) {
      final classMatch = selectedClass == null || s.className == selectedClass;
      final searchMatch = _reportSearchQuery.isEmpty || s.name.toLowerCase().contains(_reportSearchQuery.toLowerCase());
      return classMatch && searchMatch;
    }).toList();

    final dropdownItems = [
      {'id': 'all', 'name': 'Sélectionner un élève'},
      ...filteredStudents.map((s) => {'id': s.id, 'name': s.name})
    ];

    if (selectedStudent == null || !dropdownItems.any((item) => item['id'] == selectedStudent)) {
      selectedStudent = dropdownItems.first['id'];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Theme.of(context).iconTheme.color, size: 24),
              const SizedBox(width: 12),
              Text(
                'Génération & Exportation',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: selectedStudent,
            items: dropdownItems.map((item) => DropdownMenuItem(
              value: item['id'],
              child: Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).iconTheme.color, size: 18),
                  const SizedBox(width: 8),
                  Text(item['name']!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )).toList(),
            onChanged: (val) {
              setState(() => selectedStudent = val!);
            },
            isExpanded: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: (selectedClass == null || selectedClass!.isEmpty) ? null : () => _exportClassReportCards(),
                icon: const Icon(Icons.archive, size: 18),
                label: const Text('Exporter les bulletins de la classe (ZIP)'),
                style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                  backgroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.primary)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCardPreview() {
    if (selectedStudent == null || selectedStudent == 'all') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text('Sélectionnez un élève pour voir son bulletin.', style: TextStyle(color: Colors.blueGrey.shade700)),
        ),
      );
    }
    final student = students.firstWhere((s) => s.id == selectedStudent, orElse: () => Student.empty());
    if (student.id.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text('Aucun élève trouvé.', style: TextStyle(color: Colors.blueGrey.shade700)),
        ),
      );
    }
    return FutureBuilder<SchoolInfo>(
      future: loadSchoolInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final info = snapshot.data!;
        // Ajout ValueListenableBuilder pour le niveau scolaire
        return ValueListenableBuilder<String>(
          valueListenable: schoolLevelNotifier,
          builder: (context, niveau, _) {
            final schoolYear = selectedAcademicYear ?? '';
            final periodLabel = _periodMode == 'Trimestre' ? 'Trimestre' : 'Semestre';
            final studentGrades = grades.where((g) =>
              g.studentId == student.id &&
              g.className == selectedClass &&
              g.academicYear == selectedAcademicYear &&
              g.term == selectedTerm
            ).toList();
            final subjectNames = subjects.map((c) => c.name).toList();
            final types = ['Devoir', 'Composition'];
            final Color mainColor = Colors.blue.shade800;
            final Color secondaryColor = Colors.blueGrey.shade700;
            final Color tableHeaderBg = Colors.blue.shade200;
            final Color tableHeaderText = Colors.white;
            final Color tableRowAlt = Colors.blue.shade50;
            final DateTime now = DateTime.now();
            // Bloc élève : nom, prénom, sexe
            final String prenom = student.name.split(' ').length > 1 ? student.name.split(' ').first : student.name;
            final String nom = student.name.split(' ').length > 1 ? student.name.split(' ').sublist(1).join(' ') : '';
            final String sexe = student.gender;
            // --- Champs éditables pour appréciations et décision ---
            final Map<String, TextEditingController> appreciationControllers = {
              for (final subject in subjectNames) subject: TextEditingController()
            };
            final Map<String, TextEditingController> moyClasseControllers = {
              for (final subject in subjectNames) subject: TextEditingController()
            };
            final Map<String, TextEditingController> profControllers = {
              for (final subject in subjectNames) subject: TextEditingController()
            };
            final TextEditingController appreciationGeneraleController = TextEditingController();
            final TextEditingController decisionController = TextEditingController();
            final TextEditingController recommandationsController = TextEditingController();
            final TextEditingController forcesController = TextEditingController();
            final TextEditingController pointsDevelopperController = TextEditingController();
            final TextEditingController conduiteController = TextEditingController();
            final TextEditingController absJustifieesController = TextEditingController();
            final TextEditingController absInjustifieesController = TextEditingController();
            final TextEditingController retardsController = TextEditingController();
            final TextEditingController presencePercentController = TextEditingController();
            // Champs éditables pour l'établissement (téléphone, mail, site web)
            final TextEditingController telEtabController = TextEditingController();
            final TextEditingController mailEtabController = TextEditingController();
            final TextEditingController webEtabController = TextEditingController();
            final TextEditingController faitAController = TextEditingController();
            final TextEditingController leDateController = TextEditingController();
  final TextEditingController sanctionsController = TextEditingController();

            // Charger les valeurs sauvegardées pour les champs établissement
            SharedPreferences.getInstance().then((prefs) {
              telEtabController.text = prefs.getString('school_phone') ?? '';
              mailEtabController.text = prefs.getString('school_email') ?? '';
              webEtabController.text = prefs.getString('school_website') ?? '';
            });
            // Fonction de sauvegarde automatique
            void saveEtabField(String key, String value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(key, value);
            }

            // --- Persistance appréciations/professeurs/moyenne_classe ---
            Future<void> loadSubjectAppreciations() async {
              for (final subject in subjectNames) {
                final data = await _dbService.getSubjectAppreciation(
                  studentId: student.id,
                  className: selectedClass ?? '',
                  academicYear: selectedAcademicYear ?? '',
                  subject: subject,
                  term: selectedTerm ?? '',
                );
                if (data != null) {
                  profControllers[subject]?.text = data['professeur'] ?? '';
                  appreciationControllers[subject]?.text = data['appreciation'] ?? '';
                  moyClasseControllers[subject]?.text = data['moyenne_classe'] ?? '';
                }
              }
            }
            // Charger à l'ouverture
            loadSubjectAppreciations();
            // Fonction de sauvegarde automatique
            void saveSubjectAppreciation(String subject) async {
              await _dbService.insertOrUpdateSubjectAppreciation(
                studentId: student.id,
                className: selectedClass ?? '',
                academicYear: selectedAcademicYear ?? '',
                subject: subject,
                term: selectedTerm ?? '',
                professeur: profControllers[subject]?.text,
                appreciation: appreciationControllers[subject]?.text,
                moyenneClasse: moyClasseControllers[subject]?.text,
              );
            }
            // --- Moyennes par période ---
            final List<String> allTerms = _periodMode == 'Trimestre'
                ? ['Trimestre 1', 'Trimestre 2', 'Trimestre 3']
                : ['Semestre 1', 'Semestre 2'];
            final List<double?> moyennesParPeriode = allTerms.map((term) {
              final termGrades = grades.where((g) =>
                g.studentId == student.id &&
                g.className == selectedClass &&
                g.academicYear == selectedAcademicYear &&
                g.term == term &&
                (g.type == 'Devoir' || g.type == 'Composition') &&
                g.value != null && g.value != 0
              ).toList();
              double sNotes = 0.0;
              double sCoeffs = 0.0;
              for (final g in termGrades) {
                if (g.maxValue > 0 && g.coefficient > 0) {
                  sNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
                  sCoeffs += g.coefficient;
                }
              }
              return (sCoeffs > 0) ? (sNotes / sCoeffs) : null;
            }).toList();
            // Calcul de la moyenne générale pondérée (devoirs + compos)
            double sommeNotes = 0.0;
            double sommeCoefficients = 0.0;
            for (final g in studentGrades.where((g) => (g.type == 'Devoir' || g.type == 'Composition') && g.value != null && g.value != 0)) {
              if (g.maxValue > 0 && g.coefficient > 0) {
                sommeNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
                sommeCoefficients += g.coefficient;
              }
            }
            final moyenneGenerale = (sommeCoefficients > 0) ? (sommeNotes / sommeCoefficients) : 0.0;
            // Calcul du rang
            final classStudentIds = students.where((s) => s.className == student.className).map((s) => s.id).toList();
            final List<double> allMoyennes = classStudentIds.map((sid) {
              final sg = grades.where((g) => g.studentId == sid && g.className == selectedClass && g.academicYear == selectedAcademicYear && g.term == selectedTerm && (g.type == 'Devoir' || g.type == 'Composition') && g.value != null && g.value != 0).toList();
              double sNotes = 0.0;
              double sCoeffs = 0.0;
              for (final g in sg) {
                if (g.maxValue > 0 && g.coefficient > 0) {
                  sNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
                  sCoeffs += g.coefficient;
                }
              }
              return (sCoeffs > 0) ? (sNotes / sCoeffs) : 0.0;
            }).toList();
            allMoyennes.sort((a, b) => b.compareTo(a));
            final rang = allMoyennes.indexWhere((m) => (m - moyenneGenerale).abs() < 0.001) + 1;
            final int nbEleves = classStudentIds.length;

            final double? moyenneGeneraleDeLaClasse = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a + b) / allMoyennes.length
                : null;
            final double? moyenneLaPlusForte = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a > b ? a : b)
                : null;
            final double? moyenneLaPlusFaible = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a < b ? a : b)
                : null;

            // Calcul de la moyenne annuelle
            double? moyenneAnnuelle;
            final allGradesForYear = grades.where((g) =>
              g.studentId == student.id &&
              g.className == selectedClass &&
              g.academicYear == selectedAcademicYear &&
              (g.type == 'Devoir' || g.type == 'Composition') &&
              g.value != null && g.value != 0
            ).toList();

            if (allGradesForYear.isNotEmpty) {
              double totalAnnualNotes = 0.0;
              double totalAnnualCoeffs = 0.0;
              for (final g in allGradesForYear) {
                if (g.maxValue > 0 && g.coefficient > 0) {
                  totalAnnualNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
                  totalAnnualCoeffs += g.coefficient;
                }
              }
              moyenneAnnuelle = totalAnnualCoeffs > 0 ? totalAnnualNotes / totalAnnualCoeffs : null;
            }

            // Mention
            String mention;
            if (moyenneGenerale >= 18) {
              mention = 'EXCELLENT';
            } else if (moyenneGenerale >= 16) {
              mention = 'TRÈS BIEN';
            } else if (moyenneGenerale >= 14) {
              mention = 'BIEN';
            } else if (moyenneGenerale >= 12) {
              mention = 'ASSEZ BIEN';
            } else if (moyenneGenerale >= 10) {
              mention = 'PASSABLE';
            } else {
              mention = 'INSUFFISANT';
            }
            // --- SAUVEGARDE AUTOMATIQUE DU BULLETIN ---
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final synthese = {
                'appreciation_generale': appreciationGeneraleController.text,
                'decision': decisionController.text,
                'recommandations': recommandationsController.text,
                'forces': forcesController.text,
                'points_a_developper': pointsDevelopperController.text,
                'fait_a': faitAController.text,
                'le_date': leDateController.text,
                'moyenne_generale': moyenneGenerale,
                'rang': rang,
                'nb_eleves': nbEleves,
                'mention': mention,
                'moyennes_par_periode': moyennesParPeriode.toString(),
                'all_terms': allTerms.toString(),
                'moyenne_annuelle': moyenneAnnuelle,
                'sanctions': sanctionsController.text,
                'attendance_justifiee': int.tryParse(absJustifieesController.text) ?? 0,
                'attendance_injustifiee': int.tryParse(absInjustifieesController.text) ?? 0,
                'retards': int.tryParse(retardsController.text) ?? 0,
                'presence_percent': double.tryParse(presencePercentController.text) ?? 0.0,
                'conduite': conduiteController.text,
              };

              await _dbService.insertOrUpdateReportCard(
                studentId: student.id,
                className: selectedClass ?? '',
                academicYear: selectedAcademicYear ?? '',
                term: selectedTerm ?? '',
                appreciationGenerale: appreciationGeneraleController.text,
                decision: decisionController.text,
                recommandations: recommandationsController.text,
                forces: forcesController.text,
                pointsADevelopper: pointsDevelopperController.text,
                faitA: faitAController.text,
                leDate: leDateController.text,
                moyenneGenerale: moyenneGenerale,
                rang: rang,
                nbEleves: nbEleves,
                mention: mention,
                moyennesParPeriode: moyennesParPeriode.toString(),
                allTerms: allTerms.toString(),
                moyenneGeneraleDeLaClasse: moyenneGeneraleDeLaClasse,
                moyenneLaPlusForte: moyenneLaPlusForte,
                moyenneLaPlusFaible: moyenneLaPlusFaible,
                moyenneAnnuelle: moyenneAnnuelle,
                sanctions: sanctionsController.text,
                attendanceJustifiee: int.tryParse(absJustifieesController.text),
                attendanceInjustifiee: int.tryParse(absInjustifieesController.text),
                retards: int.tryParse(retardsController.text),
                presencePercent: double.tryParse(presencePercentController.text),
                conduite: conduiteController.text,
              );

              await _dbService.archiveSingleReportCard(
                studentId: student.id,
                className: selectedClass ?? '',
                academicYear: selectedAcademicYear ?? '',
                term: selectedTerm ?? '',
                grades: studentGrades,
                professeurs: { for (final subject in subjectNames) subject: profControllers[subject]?.text ?? '-' },
                appreciations: { for (final subject in subjectNames) subject: appreciationControllers[subject]?.text ?? '-' },
                moyennesClasse: { for (final subject in subjectNames) subject: moyClasseControllers[subject]?.text ?? '-' },
                synthese: synthese,
              );
            });
            return Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blue.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête établissement amélioré
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (info.logoPath != null && File(info.logoPath!).existsSync())
                        Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: Image.file(File(info.logoPath!), height: 80),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: mainColor, letterSpacing: 1.5, fontFamily: 'Serif')),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(child: Text(info.address, style: TextStyle(fontSize: 15, color: secondaryColor))),
                                Text('Année académique : ${selectedAcademicYear ?? ''}', style: TextStyle(fontSize: 15, color: secondaryColor)),
                              ],
                            ),
                            // if (info.director.isNotEmpty) Text('Directeur : ${info.director}', style: TextStyle(fontSize: 15, color: secondaryColor)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: telEtabController,
                                    decoration: InputDecoration(
                                      hintText: 'Téléphone',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    style: TextStyle(fontSize: 13, color: secondaryColor),
                                    onChanged: (val) => saveEtabField('school_phone', val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: mailEtabController,
                                    decoration: InputDecoration(
                                      hintText: 'Email',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    style: TextStyle(fontSize: 13, color: secondaryColor),
                                    onChanged: (val) => saveEtabField('school_email', val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: webEtabController,
                                    decoration: InputDecoration(
                                      hintText: 'Site web',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    style: TextStyle(fontSize: 13, color: secondaryColor),
                                    onChanged: (val) => saveEtabField('school_website', val),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Assiduité & conduite
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assiduité et Conduite', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextField(
                              controller: absJustifieesController,
                              decoration: InputDecoration(labelText: 'Absences justifiées (jours/heures)', border: OutlineInputBorder(), isDense: true),
                              keyboardType: TextInputType.number,
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(
                              controller: absInjustifieesController,
                              decoration: InputDecoration(labelText: 'Absences injustifiées', border: OutlineInputBorder(), isDense: true),
                              keyboardType: TextInputType.number,
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(
                              controller: retardsController,
                              decoration: InputDecoration(labelText: 'Retards', border: OutlineInputBorder(), isDense: true),
                              keyboardType: TextInputType.number,
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(
                              controller: presencePercentController,
                              decoration: InputDecoration(labelText: 'Présence (%)', border: OutlineInputBorder(), isDense: true),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: conduiteController,
                          decoration: const InputDecoration(labelText: 'Conduite/Comportement', border: OutlineInputBorder(), isDense: true),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text('BULLETIN SCOLAIRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: mainColor, letterSpacing: 2)),
                        if ((info.motto ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(info.motto!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainColor)),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bloc élève (nom, prénom, sexe)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('Nom : $nom', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor))),
                        Expanded(child: Text('Prénom : $prenom', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor))),
                        Expanded(child: Text('Sexe : $sexe', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.class_, color: mainColor),
                        const SizedBox(width: 8),
                        Text('Classe : ', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                        Text(student.className, style: TextStyle(color: secondaryColor)),
                        const Spacer(),
                        Text('Effectif : ', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                        Text('$nbEleves', style: TextStyle(color: secondaryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tableau matières
                  Table(
                    border: TableBorder.all(color: Colors.blue.shade100),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth(),
                      3: FlexColumnWidth(),
                      4: FlexColumnWidth(2),
                      5: FlexColumnWidth(),
                      6: FlexColumnWidth(),
                      7: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: tableHeaderBg),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('Matière', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Professeur', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Sur', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Devoir', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Composition', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Moy. élève', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Moy. classe', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Appréciation prof.', style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText))),
                        ],
                      ),
                      ...subjectNames.map((subject) {
                        final subjectGrades = studentGrades.where((g) => g.subject == subject).toList();
                        if (subjectGrades.isEmpty) return TableRow(children: List.generate(8, (_) => SizedBox()));
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

                        // Trouver le professeur et pré-remplir le champ
                        final classInfo = classes.firstWhere((c) => c.name == selectedClass, orElse: () => Class.empty());
                        final titulaire = classInfo.titulaire ?? '-';
                        final course = subjects.firstWhere((c) => c.name == subject, orElse: () => Course.empty());
                        final teacher = staff.firstWhere((s) => (s.courses?.contains(course.id) ?? false) && (s.classes?.contains(selectedClass) ?? false), orElse: () => Staff.empty());
                        final profName = teacher.id.isNotEmpty ? teacher.name : titulaire;
                        profControllers[subject]?.text = profName;

                        final classSubjectAverage = _calculateClassAverageForSubject(subject);
                        moyClasseControllers[subject]?.text = classSubjectAverage != null ? classSubjectAverage.toStringAsFixed(2) : '-';

                        return TableRow(
                          decoration: BoxDecoration(color: Colors.white),
                          children: [
                            Padding(padding: EdgeInsets.all(6), child: Text(subject, style: TextStyle(color: secondaryColor))),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: TextField(
                                controller: profControllers[subject],
                                decoration: InputDecoration(
                                  hintText: 'Professeur',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(color: secondaryColor, fontSize: 13),
                                onChanged: (_) => saveSubjectAppreciation(subject),
                              ),
                            ),
                            Padding(padding: EdgeInsets.all(6), child: Text(devoirSur != '-' ? devoirSur : compoSur, style: TextStyle(color: secondaryColor))),
                            Padding(padding: EdgeInsets.all(6), child: Text(devoirNote, style: TextStyle(color: secondaryColor))),
                            Padding(padding: EdgeInsets.all(6), child: Text(compoNote, style: TextStyle(color: secondaryColor))),
                            Padding(padding: EdgeInsets.all(6), child: Text(moyenneMatiere.toStringAsFixed(2), style: TextStyle(color: secondaryColor))),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: TextField(
                                controller: moyClasseControllers[subject],
                                decoration: InputDecoration(
                                  hintText: 'Moy. classe',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(color: secondaryColor, fontSize: 13),
                                onChanged: (_) => saveSubjectAppreciation(subject),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: TextField(
                                controller: appreciationControllers[subject],
                                decoration: InputDecoration(
                                  hintText: 'Appréciation',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(color: secondaryColor, fontSize: 13),
                                onChanged: (_) => saveSubjectAppreciation(subject),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Synthèse : tableau des moyennes par période
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Moyennes par période', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                        const SizedBox(height: 8),
                        Table(
                          border: TableBorder.all(color: Colors.blue.shade100),
                          columnWidths: {
                            for (int i = 0; i < allTerms.length; i++) i: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: tableHeaderBg),
                              children: allTerms.map((t) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: tableHeaderText)),
                              )).toList(),
                            ),
                            TableRow(
                              children: List.generate(allTerms.length, (i) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  (i < moyennesParPeriode.length && moyennesParPeriode[i] != null)
                                    ? moyennesParPeriode[i]!.toStringAsFixed(2)
                                    : '-',
                                  style: TextStyle(color: secondaryColor),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Synthèse générale
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Moyenne générale : ${moyenneGenerale.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 18)),
                              if (moyenneGeneraleDeLaClasse != null)
                                Text('Moyenne de la classe : ${moyenneGeneraleDeLaClasse.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              if (moyenneLaPlusForte != null)
                                Text('Moyenne la plus forte : ${moyenneLaPlusForte.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              if (moyenneLaPlusFaible != null)
                                Text('Moyenne la plus faible : ${moyenneLaPlusFaible.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              if (moyenneAnnuelle != null)
                                Text('Moyenne Annuelle : ${moyenneAnnuelle.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              if (moyennesParPeriode.length > 1 && moyennesParPeriode.any((m) => m != null)) ...[
                                const SizedBox(height: 8),
                                Text('Moyenne période précédente : ${moyennesParPeriode.where((m) => m != null).length > 1 ? moyennesParPeriode[moyennesParPeriode.length - 2]?.toStringAsFixed(2) ?? '-' : '-'}', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Rang : ', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                                  Text('$rang / $nbEleves', style: TextStyle(color: secondaryColor)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('Mention : ', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mainColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(mention, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Appréciation générale :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: appreciationGeneraleController,
                                decoration: InputDecoration(
                                  hintText: 'Saisir une appréciation générale',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: 2,
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Text('Décision du conseil de classe :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: decisionController,
                                decoration: InputDecoration(
                                  hintText: 'Saisir la décision',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Text('Recommandations :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: recommandationsController,
                                decoration: InputDecoration(
                                  hintText: 'Conseils et recommandations',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: 2,
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Text('Forces :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: forcesController,
                                decoration: InputDecoration(
                                  hintText: 'Points forts',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: 2,
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Text('Points à développer :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: pointsDevelopperController,
                                decoration: InputDecoration(
                                  hintText: "Axes d'amélioration",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                maxLines: 2,
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Text('Sanctions :', style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: sanctionsController,
                                decoration: InputDecoration(
                                  hintText: 'Saisir les sanctions',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: TextStyle(color: secondaryColor, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fait à :', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                              SizedBox(height: 4),
                              Text(faitAController.text.isNotEmpty ? faitAController.text : '__________________________', style: TextStyle(color: secondaryColor)),
                              SizedBox(height: 16),
                              Text(
                                schoolLevelNotifier.value.toLowerCase().contains('lycée')
                                  ? 'Proviseur(e) :'
                                  : 'Directeur(ice) :',
                                style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
                              ),
                              SizedBox(height: 4),
                              Text('__________________________', style: TextStyle(color: secondaryColor)),
                            ],
                          ),
                        ),
                        SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Le :', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                              SizedBox(height: 4),
                              Text(leDateController.text.isNotEmpty ? leDateController.text : '__________________________', style: TextStyle(color: secondaryColor)),
                              SizedBox(height: 16),
                              Text('Titulaire :', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor)),
                              SizedBox(height: 4),
                              Text('__________________________', style: TextStyle(color: secondaryColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bouton Export PDF
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Demande l'orientation
                            final orientation = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Orientation du PDF'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: Text('Portrait'),
                                      leading: Icon(Icons.stay_current_portrait),
                                      onTap: () => Navigator.of(context).pop('portrait'),
                                    ),
                                    ListTile(
                                      title: Text('Paysage'),
                                      leading: Icon(Icons.stay_current_landscape),
                                      onTap: () => Navigator.of(context).pop('landscape'),
                                    ),
                                  ],
                                ),
                              ),
                            ) ?? 'portrait';
                            final isLandscape = orientation == 'landscape';
                            final professeurs = <String, String>{ for (final subject in subjectNames) subject: profControllers[subject]?.text ?? '-' };
                            final appreciations = <String, String>{ for (final subject in subjectNames) subject: appreciationControllers[subject]?.text ?? '-' };
                            final moyennesClasse = <String, String>{ for (final subject in subjectNames) subject: moyClasseControllers[subject]?.text ?? '-' };
                            final appreciationGenerale = appreciationGeneraleController.text;
                            final decision = decisionController.text;
                            final telEtab = telEtabController.text;
                            final mailEtab = mailEtabController.text;
                            final webEtab = webEtabController.text;
                            final faitA = faitAController.text;
                            final leDate = leDateController.text;
                            final pdfBytes = await PdfService.generateReportCardPdf(
                              student: student,
                              schoolInfo: info,
                              grades: studentGrades,
                              professeurs: professeurs,
                              appreciations: appreciations,
                              moyennesClasse: moyennesClasse,
                              appreciationGenerale: appreciationGenerale,
                              decision: decision,
                              recommandations: recommandationsController.text,
                              forces: forcesController.text,
                              pointsADevelopper: pointsDevelopperController.text,
                              sanctions: sanctionsController.text,
                              attendanceJustifiee: int.tryParse(absJustifieesController.text) ?? 0,
                              attendanceInjustifiee: int.tryParse(absInjustifieesController.text) ?? 0,
                              retards: int.tryParse(retardsController.text) ?? 0,
                              presencePercent: double.tryParse(presencePercentController.text) ?? 0.0,
                              conduite: conduiteController.text,
                              telEtab: telEtab,
                              mailEtab: mailEtab,
                              webEtab: webEtab,
                              subjects: subjectNames,
                              moyennesParPeriode: moyennesParPeriode,
                              moyenneGenerale: moyenneGenerale,
                              rang: rang,
                              nbEleves: nbEleves,
                              mention: mention,
                              allTerms: allTerms,
                              periodLabel: periodLabel,
                              selectedTerm: selectedTerm ?? '',
                              academicYear: schoolYear,
                              faitA: faitA,
                              leDate: leDate,
                              isLandscape: isLandscape,
                              niveau: niveau,
                              moyenneGeneraleDeLaClasse: moyenneGeneraleDeLaClasse,
                              moyenneLaPlusForte: moyenneLaPlusForte,
                              moyenneLaPlusFaible: moyenneLaPlusFaible,
                              moyenneAnnuelle: moyenneAnnuelle,
                            );
                            await Printing.layoutPdf(onLayout: (format) async => Uint8List.fromList(pdfBytes));
                          },
                          icon: Icon(Icons.picture_as_pdf),
                          label: Text('Exporter en PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Demande l'orientation
                            final orientation = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Orientation du PDF'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: Text('Portrait'),
                                      leading: Icon(Icons.stay_current_portrait),
                                      onTap: () => Navigator.of(context).pop('portrait'),
                                    ),
                                    ListTile(
                                      title: Text('Paysage'),
                                      leading: Icon(Icons.stay_current_landscape),
                                      onTap: () => Navigator.of(context).pop('landscape'),
                                    ),
                                  ],
                                ),
                              ),
                            ) ?? 'portrait';
                            final isLandscape = orientation == 'landscape';
                            final professeurs = <String, String>{ for (final subject in subjectNames) subject: profControllers[subject]?.text ?? '-' };
                            final appreciations = <String, String>{ for (final subject in subjectNames) subject: appreciationControllers[subject]?.text ?? '-' };
                            final moyennesClasse = <String, String>{ for (final subject in subjectNames) subject: moyClasseControllers[subject]?.text ?? '-' };
                            final appreciationGenerale = appreciationGeneraleController.text;
                            final decision = decisionController.text;
                            final telEtab = telEtabController.text;
                            final mailEtab = mailEtabController.text;
                            final webEtab = webEtabController.text;
                            final faitA = faitAController.text;
                            final leDate = leDateController.text;
                            final pdfBytes = await PdfService.generateReportCardPdf(
                              student: student,
                              schoolInfo: info,
                              grades: studentGrades,
                              professeurs: professeurs,
                              appreciations: appreciations,
                              moyennesClasse: moyennesClasse,
                              appreciationGenerale: appreciationGenerale,
                              decision: decision,
                              recommandations: recommandationsController.text,
                              forces: forcesController.text,
                              pointsADevelopper: pointsDevelopperController.text,
                              sanctions: sanctionsController.text,
                              attendanceJustifiee: int.tryParse(absJustifieesController.text) ?? 0,
                              attendanceInjustifiee: int.tryParse(absInjustifieesController.text) ?? 0,
                              retards: int.tryParse(retardsController.text) ?? 0,
                              presencePercent: double.tryParse(presencePercentController.text) ?? 0.0,
                              conduite: conduiteController.text,
                              telEtab: telEtab,
                              mailEtab: mailEtab,
                              webEtab: webEtab,
                              subjects: subjectNames,
                              moyennesParPeriode: moyennesParPeriode,
                              moyenneGenerale: moyenneGenerale,
                              rang: rang,
                              nbEleves: nbEleves,
                              mention: mention,
                              allTerms: allTerms,
                              periodLabel: periodLabel,
                              selectedTerm: selectedTerm ?? '',
                              academicYear: schoolYear,
                              faitA: faitA,
                              leDate: leDate,
                              isLandscape: isLandscape,
                              niveau: niveau,
                              moyenneGeneraleDeLaClasse: moyenneGeneraleDeLaClasse,
                              moyenneLaPlusForte: moyenneLaPlusForte,
                              moyenneLaPlusFaible: moyenneLaPlusFaible,
                            );
                            String? directoryPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisir le dossier de sauvegarde');
                            if (directoryPath != null) {
                              final fileName = 'Bulletin_${student.name.replaceAll(' ', '_')}_${selectedTerm ?? ''}_${selectedAcademicYear ?? ''}.pdf';
                              final file = File('$directoryPath/$fileName');
                              await file.writeAsBytes(pdfBytes);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Bulletin enregistré dans $directoryPath'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          icon: Icon(Icons.save_alt),
                          label: Text('Enregistrer PDF...'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double? _calculateClassAverageForSubject(String subject) {
    final gradesForSubject = grades.where((g) =>
      g.subject == subject &&
      g.className == selectedClass &&
      g.academicYear == selectedAcademicYear &&
      g.term == selectedTerm &&
      (g.type == 'Devoir' || g.type == 'Composition') &&
      g.value != null && g.value != 0
    ).toList();

    if (gradesForSubject.isEmpty) return null;

    double total = 0.0;
    double totalCoeff = 0.0;
    for (final g in gradesForSubject) {
      if (g.maxValue > 0 && g.coefficient > 0) {
        total += ((g.value / g.maxValue) * 20) * g.coefficient;
        totalCoeff += g.coefficient;
      }
    }
    return totalCoeff > 0 ? total / totalCoeff : null;
  }

  Widget _buildArchiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(
            controller: archiveSearchController,
            hintText: 'Rechercher dans les archives...',
            onChanged: (val) => setState(() => _archiveSearchQuery = val),
          ),
          CheckboxListTile(
            title: Text("Rechercher dans toutes les années"),
            value: _searchAllYears,
            onChanged: (bool? value) {
              setState(() {
                _searchAllYears = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          if (!_searchAllYears)
            _buildSelectionSection(),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _searchAllYears 
                ? _dbService.getAllArchivedReportCards() 
                : (selectedAcademicYear == null || selectedAcademicYear!.isEmpty || selectedClass == null || selectedClass!.isEmpty)
                    ? Future.value([])
                    : _dbService.getArchivedReportCardsByClassAndYear(
                        academicYear: selectedAcademicYear!,
                        className: selectedClass!,
                      ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('Aucune archive trouvée pour cette sélection.', style: TextStyle(color: Colors.grey)));
              }

              final allArchivedReportCards = snapshot.data!;
              final studentIdsFromArchive = allArchivedReportCards.map((rc) => rc['studentId'] as String).toSet();

              // Filtrer les élèves en fonction de la recherche et des archives
              final filteredStudents = students.where((student) {
                final nameMatch = _archiveSearchQuery.isEmpty || student.name.toLowerCase().contains(_archiveSearchQuery.toLowerCase());
                final inArchive = studentIdsFromArchive.contains(student.id);
                return nameMatch && inArchive;
              }).toList();

              if (filteredStudents.isEmpty) {
                return Center(child: Text('Aucun élève correspondant trouvé dans les archives.', style: TextStyle(color: Colors.grey)));
              }

              // Logique de pagination
              final startIndex = _archiveCurrentPage * _archiveItemsPerPage;
              final endIndex = (startIndex + _archiveItemsPerPage > filteredStudents.length)
                  ? filteredStudents.length
                  : startIndex + _archiveItemsPerPage;
              final paginatedStudents = filteredStudents.sublist(startIndex, endIndex);

              return Column(
                children: [
                  ...paginatedStudents.map((student) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            student.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(student.name, style: Theme.of(context).textTheme.bodyLarge),
                        subtitle: Text('Classe: ${student.className}', style: Theme.of(context).textTheme.bodyMedium),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color),
                          onSelected: (value) async {
                            if (value == 'profile') {
                              showDialog(
                                context: context,
                                builder: (context) => StudentProfilePage(student: student),
                              );
                            } else if (value == 'view') {
                              // TODO: Implement view bulletin logic
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'profile', child: Text('Voir le profil')),
                            const PopupMenuItem(value: 'view', child: Text('Voir le bulletin')),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  _buildPaginationControls(filteredStudents.length),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final totalPages = (totalItems / _archiveItemsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _archiveCurrentPage > 0
              ? () {
                  setState(() {
                    _archiveCurrentPage--;
                  });
                }
              : null,
        ),
        Text('Page ${_archiveCurrentPage + 1} sur $totalPages'),
        IconButton(
          icon: Icon(Icons.arrow_forward),
          onPressed: _archiveCurrentPage < totalPages - 1
              ? () {
                  setState(() {
                    _archiveCurrentPage++;
                  });
                }
              : null,
        ),
      ],
    );
  }

  void _showImportDialog() {
    // Implémentation du dialogue d'import CSV
  }

  void _showStatsDialog() {
    // Implémentation du dialogue des statistiques
  }

  void _showBulkGradeDialog() {
    // Implémentation de la saisie rapide des notes
  }

  Future<Map<String, dynamic>> _prepareReportCardData(Student student) async {
    final info = await loadSchoolInfo();
    final schoolYear = selectedAcademicYear ?? '';
    final periodLabel = _periodMode == 'Trimestre' ? 'Trimestre' : 'Semestre';
    final studentGrades = grades.where((g) =>
      g.studentId == student.id &&
      g.className == selectedClass &&
      g.academicYear == selectedAcademicYear &&
      g.term == selectedTerm
    ).toList();
    final subjectNames = subjects.map((c) => c.name).toList();

    // --- Moyennes par période ---
    final List<String> allTerms = _periodMode == 'Trimestre'
        ? ['Trimestre 1', 'Trimestre 2', 'Trimestre 3']
        : ['Semestre 1', 'Semestre 2'];
    final List<double?> moyennesParPeriode = allTerms.map((term) {
      final termGrades = grades.where((g) =>
        g.studentId == student.id &&
        g.className == selectedClass &&
        g.academicYear == selectedAcademicYear &&
        g.term == term &&
        (g.type == 'Devoir' || g.type == 'Composition') &&
        g.value != null && g.value != 0
      ).toList();
      double sNotes = 0.0;
      double sCoeffs = 0.0;
      for (final g in termGrades) {
        if (g.maxValue > 0 && g.coefficient > 0) {
          sNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
          sCoeffs += g.coefficient;
        }
      }
      return (sCoeffs > 0) ? (sNotes / sCoeffs) : null;
    }).toList();

    // Calcul de la moyenne générale pondérée (devoirs + compos)
    double sommeNotes = 0.0;
    double sommeCoefficients = 0.0;
    for (final g in studentGrades.where((g) => (g.type == 'Devoir' || g.type == 'Composition') && g.value != null && g.value != 0)) {
      if (g.maxValue > 0 && g.coefficient > 0) {
        sommeNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
        sommeCoefficients += g.coefficient;
      }
    }
    final moyenneGenerale = (sommeCoefficients > 0) ? (sommeNotes / sommeCoefficients) : 0.0;

    // Calcul du rang
    final classStudentIds = students.where((s) => s.className == student.className).map((s) => s.id).toList();
    final List<double> allMoyennes = classStudentIds.map((sid) {
      final sg = grades.where((g) => g.studentId == sid && g.className == selectedClass && g.academicYear == selectedAcademicYear && g.term == selectedTerm && (g.type == 'Devoir' || g.type == 'Composition') && g.value != null && g.value != 0).toList();
      double sNotes = 0.0;
      double sCoeffs = 0.0;
      for (final g in sg) {
        if (g.maxValue > 0 && g.coefficient > 0) {
          sNotes += ((g.value / g.maxValue) * 20) * g.coefficient;
          sCoeffs += g.coefficient;
        }
      }
      return (sCoeffs > 0) ? (sNotes / sCoeffs) : 0.0;
    }).toList();
    allMoyennes.sort((a, b) => b.compareTo(a));
    final rang = allMoyennes.indexWhere((m) => (m - moyenneGenerale).abs() < 0.001) + 1;
    final int nbEleves = classStudentIds.length;

    // Mention
    String mention;
    if (moyenneGenerale >= 18) {
      mention = 'EXCELLENT';
    } else if (moyenneGenerale >= 16) {
      mention = 'TRÈS BIEN';
    } else if (moyenneGenerale >= 14) {
      mention = 'BIEN';
    } else if (moyenneGenerale >= 12) {
      mention = 'ASSEZ BIEN';
    } else if (moyenneGenerale >= 10) {
      mention = 'PASSABLE';
    } else {
      mention = 'INSUFFISANT';
    }

    return {
      'student': student,
      'schoolInfo': info,
      'grades': studentGrades,
      'subjects': subjectNames,
      'moyennesParPeriode': moyennesParPeriode,
      'moyenneGenerale': moyenneGenerale,
      'rang': rang,
      'nbEleves': nbEleves,
      'mention': mention,
      'allTerms': allTerms,
      'periodLabel': periodLabel,
      'selectedTerm': selectedTerm ?? '',
      'academicYear': schoolYear,
      'niveau': schoolLevelNotifier.value,
    };
  }

  Future<void> _exportClassReportCards() async {
    if (selectedClass == null || selectedClass!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner une classe.')));
      return;
    }

    final studentsInClass = students.where((s) => s.className == selectedClass).toList();
    if (studentsInClass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucun élève dans cette classe.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Génération des bulletins en cours...')));

    final archive = Archive();

    for (final student in studentsInClass) {
      final data = await _prepareReportCardData(student);
      // Récupérer appréciations/professeurs/moyenne_classe enregistrées
      final subjectNames = data['subjects'] as List<String>;
      final subjectApps = await _dbService.getSubjectAppreciations(
        studentId: student.id,
        className: selectedClass!,
        academicYear: selectedAcademicYear!,
        term: selectedTerm!,
      );
      final professeurs = <String, String>{ for (final s in subjectNames) s: '-' };
      final appreciations = <String, String>{ for (final s in subjectNames) s: '-' };
      final moyennesClasse = <String, String>{ for (final s in subjectNames) s: '-' };
      for (final row in subjectApps) {
        final subject = row['subject'] as String?;
        if (subject != null) {
          professeurs[subject] = (row['professeur'] as String?)?.trim().isNotEmpty == true ? row['professeur'] as String : '-';
          appreciations[subject] = (row['appreciation'] as String?)?.trim().isNotEmpty == true ? row['appreciation'] as String : '-';
          moyennesClasse[subject] = (row['moyenne_classe'] as String?)?.trim().isNotEmpty == true ? row['moyenne_classe'] as String : '-';
        }
      }
      // Synthèse générale depuis report_cards
      final rc = await _dbService.getReportCard(
        studentId: student.id,
        className: selectedClass!,
        academicYear: selectedAcademicYear!,
        term: selectedTerm!,
      );
      final appreciationGenerale = rc?['appreciation_generale'] as String? ?? '';
      final decision = rc?['decision'] as String? ?? '';
      final recommandations = rc?['recommandations'] as String? ?? '';
      final forces = rc?['forces'] as String? ?? '';
      final pointsADevelopper = rc?['points_a_developper'] as String? ?? '';
      final sanctions = rc?['sanctions'] as String? ?? '';
      final attendanceJustifiee = (rc?['attendance_justifiee'] as int?) ?? 0;
      final attendanceInjustifiee = (rc?['attendance_injustifiee'] as int?) ?? 0;
      final retards = (rc?['retards'] as int?) ?? 0;
      final num? presenceNum = rc?['presence_percent'] as num?;
      final presencePercent = presenceNum?.toDouble() ?? 0.0;
      final conduite = rc?['conduite'] as String? ?? '';
      final faitA = rc?['fait_a'] as String? ?? '';
      final leDate = rc?['le_date'] as String? ?? '';

      final pdfBytes = await PdfService.generateReportCardPdf(
        student: data['student'],
        schoolInfo: data['schoolInfo'],
        grades: data['grades'],
        professeurs: professeurs,
        appreciations: appreciations,
        moyennesClasse: moyennesClasse,
        appreciationGenerale: appreciationGenerale,
        decision: decision,
        recommandations: recommandations,
        forces: forces,
        pointsADevelopper: pointsADevelopper,
        sanctions: sanctions,
        attendanceJustifiee: attendanceJustifiee,
        attendanceInjustifiee: attendanceInjustifiee,
        retards: retards,
        presencePercent: presencePercent,
        conduite: conduite,
        telEtab: data['schoolInfo'].telephone ?? '',
        mailEtab: data['schoolInfo'].email ?? '',
        webEtab: data['schoolInfo'].website ?? '',
        subjects: data['subjects'],
        moyennesParPeriode: data['moyennesParPeriode'],
        moyenneGenerale: data['moyenneGenerale'],
        rang: data['rang'],
        nbEleves: data['nbEleves'],
        mention: data['mention'],
        allTerms: data['allTerms'],
        periodLabel: data['periodLabel'],
        selectedTerm: data['selectedTerm'],
        academicYear: data['academicYear'],
        faitA: faitA,
        leDate: leDate,
        isLandscape: false,
        niveau: data['niveau'],
      );
      final fileName = 'Bulletin_${student.name.replaceAll(' ', '_')}_${selectedTerm ?? ''}_${selectedAcademicYear ?? ''}.pdf';
      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    if (zipBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la création du fichier ZIP.')));
        return;
    }

    String? directoryPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choisir le dossier de sauvegarde');
    if (directoryPath != null) {
      final fileName = 'Bulletins_${selectedClass!.replaceAll(' ', '_')}_${selectedTerm ?? ''}_${selectedAcademicYear ?? ''}.zip';
      final file = File('$directoryPath/$fileName');
      await file.writeAsBytes(zipBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulletins exportés dans $directoryPath'), backgroundColor: Colors.green),
      );
    }
  }

  void _showEditStudentGradesDialog(Student student) async {
    final List<String> subjectNames = subjects.map((c) => c.name).toList();
    // Récupère toutes les notes de l'élève pour la période sélectionnée directement depuis la base
    List<Grade> allGradesForPeriod = await _dbService.getAllGradesForPeriod(
      className: selectedClass!,
      academicYear: selectedAcademicYear!,
      term: selectedTerm!,
    );
    // Nouvelle structure : pour chaque matière, pour chaque type, liste de notes
    final types = ['Devoir', 'Composition'];
    Map<String, Map<String, List<Grade>>> subjectTypeGrades = {};
    for (final subject in subjectNames) {
      subjectTypeGrades[subject] = {};
      for (final type in types) {
        subjectTypeGrades[subject]![type] = allGradesForPeriod.where((g) => g.studentId == student.id && g.subject == subject && g.type == type).toList();
        // Si aucune note, on ajoute une note vide par défaut pour la saisie
        if (subjectTypeGrades[subject]![type]!.isEmpty) {
          final course = subjects.firstWhere((c) => c.name == subject, orElse: () => Course.empty());
          subjectTypeGrades[subject]![type] = [Grade(
            id: null,
            studentId: student.id,
            className: selectedClass!,
            academicYear: selectedAcademicYear!,
            subjectId: course.id,
            subject: subject,
            term: selectedTerm!,
            value: 0,
            label: subject,
            maxValue: 20,
            coefficient: 1,
            type: type,
          )];
        }
      }
    }
    // Contrôleurs pour chaque note (clé : subject-type-index)
    final Map<String, TextEditingController> valueControllers = {};
    final Map<String, TextEditingController> labelControllers = {};
    final Map<String, TextEditingController> maxValueControllers = {};
    final Map<String, TextEditingController> coefficientControllers = {};
    subjectTypeGrades.forEach((subject, typeMap) {
      typeMap.forEach((type, gradesList) {
        for (int i = 0; i < gradesList.length; i++) {
          final key = '$subject-$type-$i';
          valueControllers[key] = TextEditingController(text: gradesList[i].value.toString());
          labelControllers[key] = TextEditingController(text: gradesList[i].label ?? subject);
          maxValueControllers[key] = TextEditingController(text: gradesList[i].maxValue.toString());
          coefficientControllers[key] = TextEditingController(text: gradesList[i].coefficient.toString());
        }
      });
    });
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isDark ? Colors.white : Colors.black;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Notes de ${student.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: subjectNames.map((subject) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: types.map((type) {
                        final gradesList = subjectTypeGrades[subject]![type]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('$subject - $type', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                            ),
                            ...List.generate(gradesList.length, (i) {
                              final key = '$subject-$type-$i';
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: labelControllers[key],
                                      decoration: InputDecoration(
                                        labelText: 'Nom de la note',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: valueControllers[key],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Note',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: maxValueControllers[key],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Sur',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: coefficientControllers[key],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Coeff.',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Supprimer cette note',
                                    onPressed: () {
                                      setStateDialog(() {
                                        subjectTypeGrades[subject]![type]!.removeAt(i);
                                      });
                                    },
                                  ),
                                ],
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setStateDialog(() {
                                    final course = subjects.firstWhere((c) => c.name == subject, orElse: () => Course.empty());
                                    subjectTypeGrades[subject]![type]!.add(Grade(
                                      id: null,
                                      studentId: student.id,
                                      className: selectedClass!,
                                      academicYear: selectedAcademicYear!,
                                      subjectId: course.id,
                                      subject: subject,
                                      term: selectedTerm!,
                                      value: 0,
                                      label: subject,
                                      maxValue: 20,
                                      coefficient: 1,
                                      type: type,
                                    ));
                                  });
                                },
                                icon: Icon(Icons.add, color: color),
                                label: Text('Ajouter une note', style: TextStyle(color: color)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Sauvegarde toutes les notes
                    for (final subject in subjectNames) {
                      for (final type in types) {
                        final gradesList = subjectTypeGrades[subject]![type]!;
                        for (int i = 0; i < gradesList.length; i++) {
                          final key = '$subject-$type-$i';
                          final val = double.tryParse(valueControllers[key]?.text ?? '');
                          final label = labelControllers[key]?.text ?? subject;
                          final maxVal = double.tryParse(maxValueControllers[key]?.text ?? '') ?? 20.0;
                          final coeff = double.tryParse(coefficientControllers[key]?.text ?? '') ?? 1.0;
                          if (val != null && selectedClass != null && selectedAcademicYear != null && selectedTerm != null) {
                            Grade? existing;
                            try {
                              existing = allGradesForPeriod.firstWhere((g) =>
                                g.studentId == student.id &&
                                g.subject == subject &&
                                g.type == type &&
                                g.label == label
                              );
                            } catch (_) {
                              existing = null;
                            }
                            final course = subjects.firstWhere((c) => c.name == subject, orElse: () => Course.empty());
                            final newGrade = Grade(
                              id: existing?.id,
                              studentId: student.id,
                              className: selectedClass!,
                              academicYear: selectedAcademicYear!,
                              subjectId: course.id,
                              subject: subject,
                              term: selectedTerm!,
                              value: val,
                              label: label,
                              maxValue: maxVal,
                              coefficient: coeff,
                              type: type,
                            );
                            if (existing == null) {
                              await _dbService.insertGrade(newGrade);
                            } else {
                              await _dbService.updateGrade(newGrade);
                            }
                          }
                        }
                      }
                    }
                    await _loadAllGradesForPeriod();
                    setState(() {});
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notes mises à jour pour ${student.name}'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  

  @override
  Widget build(BuildContext context) {
    final theme = _isDarkMode ? _buildDarkTheme() : _buildLightTheme();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.grey[100],
        body: Column(
          children: [
            _buildHeader(context, _isDarkMode, isDesktop),
            const SizedBox(height: 16),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGradeInputTab(),
                  _buildReportCardsTab(),
                  _buildArchiveTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}