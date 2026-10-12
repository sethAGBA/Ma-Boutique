import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_manager/screens/students/widgets/form_field.dart';
import 'package:uuid/uuid.dart';
import 'package:school_manager/screens/students/widgets/custom_dialog.dart';
import 'package:school_manager/models/staff.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:school_manager/models/course.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({Key? key}) : super(key: key);

  @override
  _StaffPageState createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _searchFocusNode;
  String _selectedTab = 'Tout le Personnel';
  String _searchQuery = '';
  String _selectedRoleTab = 'Tout le Personnel';
  final List<String> _roleTabs = ['Tout le Personnel', 'Personnel Enseignant', 'Personnel Administratif'];

  final DatabaseService _dbService = DatabaseService();
  List<Staff> _staffList = [];
  bool _isLoading = true;
  List<Course> _allCourses = [];
  int _currentPage = 0;
  static const int _rowsPerPage = 7;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _searchFocusNode = FocusNode();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadStaff();
    _loadCourses();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final staff = await _dbService.getStaff();
    setState(() {
      _staffList = staff;
      _isLoading = false;
    });
  }

  Future<void> _loadCourses() async {
    final courses = await _dbService.getCourses();
    setState(() {
      _allCourses = courses;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
          decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, isDarkMode, isDesktop),
              // Bouton Ajouter un cours
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _showAddCourseDialog,
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text('Ajouter un cours', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              // Tabs
              // Search
              // Table/cards
              Expanded(
                child: _buildStaffTable(context, isDesktop, isTablet, theme),
              ),
              // Bouton d'ajout membre
              Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showAddEditStaffDialog(null),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Ajouter un membre'),
                    backgroundColor: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                      Icons.group,
                      color: Colors.white,
                      size: isDesktop ? 32 : 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column( // Title and description
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion du Personnel',
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color, // Use bodyLarge for title
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gérez le personnel enseignant et administratif, assignez les cours et surveillez la présence.',
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
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou ID du personnel...',
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

  Widget _buildStaffTable(BuildContext context, bool isDesktop, bool isTablet, ThemeData theme) {
    final filtered = _staffList.where((staff) {
      final query = _searchQuery;
      final tab = _selectedRoleTab;
      bool matchRole = true;
      if (tab == 'Personnel Enseignant') {
        matchRole = staff.typeRole == 'Professeur';
      } else if (tab == 'Personnel Administratif') {
        matchRole = staff.typeRole == 'Administration';
      }
      if (query.isEmpty) return matchRole;
      return matchRole && (staff.name.toLowerCase().contains(query) || staff.id.toLowerCase().contains(query));
    }).toList();
    final totalPages = (filtered.length / _rowsPerPage).ceil();
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filtered.length);
    final paginated = filtered.sublist(start, end);
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isDesktop) _buildDesktopTable(paginated, theme),
                  if (isTablet) _buildTabletTable(paginated, theme),
                  if (!isDesktop && !isTablet) _buildMobileCards(paginated, theme),
                ],
              ),
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  Text('Page ${_currentPage + 1} / $totalPages'),
                  IconButton(
                    icon: Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Staff> staffData, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 1100),
      child: DataTable(
          headingRowColor: MaterialStateProperty.all(Color(0xFF6366F1).withOpacity(0.08)),
        dataRowColor: MaterialStateProperty.all(Colors.transparent),
        columns: [
          DataColumn(
              label: Text('Nom', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          ),
          DataColumn(
              label: Text('Rôle', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          ),
          DataColumn(
              label: Text('Classes', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          ),
          DataColumn(
              label: Text('Cours', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          ),
          DataColumn(
              label: Text('Actions', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          ),
        ],
        rows: staffData.map((staff) {
          return DataRow(
            cells: [
                DataCell(Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFF6366F1),
                      child: Text(
                        _getInitials(staff.name),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(staff.name, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                  ],
                )),
                DataCell(Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(staff.role, style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13)),
                )),
                DataCell(SizedBox(
                  width: 180,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 6,
                      children: staff.classes.map((c) => Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(c, style: TextStyle(color: Color(0xFF6366F1), fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                )),
                DataCell(SizedBox(
                  width: 180,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 6,
                      children: staff.courses.map((c) => Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(c, style: TextStyle(color: Color(0xFF6366F1), fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                )),
                DataCell(_buildActionsMenu(staff)),
            ],
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabletTable(List<Staff> staffData, ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: staffData.length,
      itemBuilder: (context, index) {
        final staff = staffData[index];
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                    Text(staff.role, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Text(staff.department, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
              ),
              _buildStatusChip(staff.status),
              SizedBox(width: 8),
              _buildActionButton(staff),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(List<Staff> staffData, ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: staffData.length,
      itemBuilder: (context, index) {
        final staff = staffData[index];
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF6366F1),
              child: Text(
                _getInitials(staff.name),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(staff.name, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
            subtitle: Text(staff.role, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            trailing: _buildStatusChip(staff.status),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Département', staff.department, theme),
                    _buildInfoRow('Cours Assignés', staff.courses.join(', '), theme),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(staff),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditStaffDialog(staff),
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('Modifier'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color gradientStart;
    Color gradientEnd;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'actif':
        gradientStart = const Color(0xFF10B981);
        gradientEnd = const Color(0xFF34D399);
        icon = Icons.check_circle;
        break;
      case 'en congé':
        gradientStart = const Color(0xFFF59E0B);
        gradientEnd = const Color(0xFFFBBF24);
        icon = Icons.pause_circle;
        break;
      default:
        gradientStart = const Color(0xFFE53E3E);
        gradientEnd = const Color(0xFFF87171);
        icon = Icons.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white, semanticLabel: status),
          const SizedBox(width: 4),
          Text(
        status,
            style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Staff staff) {
    return ElevatedButton.icon(
      onPressed: () => _showAddEditStaffDialog(staff),
      icon: Icon(Icons.visibility, size: 16),
      label: Text('Détails'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildActionsMenu(Staff staff) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'details') {
          _showAddEditStaffDialog(staff);
        } else if (value == 'edit') {
          _showAddEditStaffDialog(staff);
        } else if (value == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Supprimer ce membre ?'),
              content: Text('Cette action est irréversible.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Supprimer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _dbService.deleteStaff(staff.id);
            await _loadStaff();
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'details', child: Text('Détails')),
        PopupMenuItem(value: 'edit', child: Text('Modifier')),
        PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
      icon: Icon(Icons.more_vert, color: Color(0xFF6366F1)),
    );
  }

  void _showAddCourseDialog() {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.book, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Ajouter un cours', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomFormField(
                controller: nameController,
                labelText: 'Nom du cours',
                hintText: 'Ex: Mathématiques',
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              CustomFormField(
                controller: descController,
                labelText: 'Description (optionnelle)',
                hintText: 'Ex: Cours de base, avancé...'
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (_allCourses.where((c) => c.name == name).isEmpty) {
                  final course = Course(id: const Uuid().v4(), name: name, description: desc.isNotEmpty ? desc : null);
                  await _dbService.insertCourse(course);
                  await _loadCourses();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cours ajouté !'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ce cours existe déjà.'), backgroundColor: Colors.orange),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1)),
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddEditStaffDialog(Staff? staff) async {
    final isEdit = staff != null;
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: staff?.name ?? '');
    String? selectedRole = staff?.typeRole ?? null;
    final roleDescriptionController = TextEditingController(text: staff != null && staff.role != 'Professeur' && staff.role != 'Administration' ? staff.role : '');
    final phoneController = TextEditingController(text: staff?.phone ?? '');
    final emailController = TextEditingController(text: staff?.email ?? '');
    final qualificationsController = TextEditingController(text: staff?.qualifications ?? '');
    final statusList = ['Actif', 'En congé', 'Inactif'];
    String status = staff?.status ?? 'Actif';
    DateTime hireDate = staff?.hireDate ?? DateTime.now();
    List<String> selectedCourses = List<String>.from(staff?.courses ?? []);
    List<String> selectedClasses = List<String>.from(staff?.classes ?? []);
    List<Course> allCourses = List<Course>.from(_allCourses);
    List<String> allClasses = [];
    bool loadingClasses = true;
    final roleList = ['Professeur', 'Administration'];
    await showDialog(
      context: context,
      builder: (context) {
        _dbService.getClasses().then((classes) {
          allClasses = classes.map((c) => c.name).toList();
          loadingClasses = false;
          (context as Element).markNeedsBuild();
        });
        return StatefulBuilder(
          builder: (context, setState) {
            return CustomDialog(
              title: isEdit ? 'Modifier le membre' : 'Ajouter un membre',
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section infos
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFF6366F1),
                            child: Text(
                              _getInitials(nameController.text),
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: CustomFormField(
                              controller: nameController,
                              labelText: 'Nom',
                              hintText: 'Entrez le nom complet',
                              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      Text('Informations personnelles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 8),
                      CustomFormField(
                        isDropdown: true,
                        labelText: 'Rôle',
                        dropdownItems: roleList,
                        dropdownValue: selectedRole,
                        onDropdownChanged: (val) => setState(() => selectedRole = val),
                        validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                      ),
                      if (selectedRole == 'Professeur')
                        CustomFormField(
                          controller: roleDescriptionController,
                          labelText: 'Professeur de…',
                          hintText: 'Ex: Professeur de Sciences',
                          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                        ),
                      if (selectedRole == 'Administration')
                        CustomFormField(
                          controller: roleDescriptionController,
                          labelText: 'Fonction',
                          hintText: 'Ex: Directeur, Secrétaire…',
                          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                        ),
                      CustomFormField(
                        controller: phoneController,
                        labelText: 'Téléphone',
                        hintText: 'Ex: +33 6 12 34 56 78'
                      ),
                      CustomFormField(
                        controller: emailController,
                        labelText: 'Email',
                        hintText: 'exemple@ecole.fr'
                      ),
                      CustomFormField(
                        controller: qualificationsController,
                        labelText: 'Qualifications',
                        hintText: 'Diplômes, formations...'
                      ),
                      CustomFormField(
                        isDropdown: true,
                        labelText: 'Statut',
                        dropdownItems: statusList,
                        dropdownValue: status,
                        onDropdownChanged: (val) => setState(() => status = val ?? 'Actif'),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: hireDate,
                            firstDate: DateTime(1980),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => hireDate = picked);
                        },
                        child: AbsorbPointer(
                          child: CustomFormField(
                            controller: TextEditingController(text: DateFormat('dd/MM/yyyy').format(hireDate)),
                            labelText: "Date d'embauche",
                            hintText: 'Sélectionnez la date',
                            readOnly: true,
                            suffixIcon: Icons.calendar_today,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      // Section cours
                      Text('Cours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: allCourses.map((course) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(course.name),
                              selected: selectedCourses.contains(course.name),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedCourses.add(course.name);
                                  } else {
                                    selectedCourses.remove(course.name);
                                  }
                                });
                              },
                              selectedColor: Color(0xFF6366F1),
                              labelStyle: TextStyle(color: selectedCourses.contains(course.name) ? Colors.white : Color(0xFF6366F1)),
                              backgroundColor: Color(0xFF6366F1).withOpacity(0.08),
                            ),
                          )).toList(),
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      // Section classes
                      Text('Classes assignées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 8),
                      loadingClasses
                          ? Center(child: CircularProgressIndicator())
                          : Wrap(
                              spacing: 8,
                              children: allClasses.map((cls) => FilterChip(
                                label: Text(cls),
                                selected: selectedClasses.contains(cls),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedClasses.add(cls);
                                    } else {
                                      selectedClasses.remove(cls);
                                    }
                                  });
                                },
                              )).toList(),
                            ),
                    ],
                  ),
                ),
              ),
              onSubmit: () async {
                if (_formKey.currentState!.validate()) {
                  final newStaff = Staff(
                    id: staff?.id ?? const Uuid().v4(),
                    name: nameController.text.trim(),
                    role: roleDescriptionController.text.trim(),
                    typeRole: selectedRole ?? 'Administration',
                    department: '', // plus utilisé
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    qualifications: qualificationsController.text.trim(),
                    courses: selectedCourses,
                    classes: selectedClasses,
                    status: status,
                    hireDate: hireDate,
                  );
                  if (isEdit) {
                    await _dbService.updateStaff(newStaff.id, newStaff);
                  } else {
                    await _dbService.insertStaff(newStaff);
                  }
                  await _loadStaff();
                  Navigator.of(context).pop();
                }
              },
              actions: [
                if (isEdit)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Supprimer ce membre ?'),
                          content: Text('Cette action est irréversible.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Supprimer'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _dbService.deleteStaff(staff!.id);
                        await _loadStaff();
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((n) => n.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String initials = parts.map((n) => n[0]).join();
    if (initials.length > 2) initials = initials.substring(0, 2);
    return initials.toUpperCase();
  }

  Future<void> refreshStaffFromOutside() async {
    await _loadStaff();
  }
}