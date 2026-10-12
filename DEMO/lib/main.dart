import 'package:flutter/material.dart';
import 'package:school_manager/screens/staff_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_home.dart';
import 'screens/students_page.dart';
import 'screens/grades_page.dart';
import 'screens/payments_page.dart';
import 'screens/settings_page.dart';
import 'widgets/sidebar.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/permission_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/users_management_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _ensureAdminExists();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  void _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = isDark;
    });
    await prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'École Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.grey[800]),
          bodyMedium: TextStyle(color: Colors.grey[600]),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey[300],
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        cardColor: Colors.grey[850],
        dividerColor: Colors.white24,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder(
        future: AuthService.instance.getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user == null) {
            return LoginPage(onSuccess: () => setState(() {}));
          }
          return SchoolDashboard(onThemeToggle: _toggleTheme, isDarkMode: _isDarkMode);
        },
      ),
    );
  }
}

Future<void> _ensureAdminExists() async {
  try {
    final users = await DatabaseService().getAllUserRows();
    if (users.isEmpty) {
      await AuthService.instance.createOrUpdateUser(
        username: 'admin',
        displayName: 'Administrateur',
        role: 'admin',
        password: 'admin',
        enable2FA: false,
      );
    }
  } catch (_) {}
}

class SchoolDashboard extends StatefulWidget {
  final ValueChanged<bool> onThemeToggle;
  final bool isDarkMode;

  SchoolDashboard({required this.onThemeToggle, required this.isDarkMode});

  @override
  _SchoolDashboardState createState() => _SchoolDashboardState();
}

// Helper accessible from widgets without importing services
Future<void> performGlobalLogout(BuildContext context) async {
  await AuthService.instance.logout();
  // After logout, rebuild root by replacing with LoginPage
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => LoginPage(
          onSuccess: () {
            Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MyApp()),
              (route) => false,
            );
          },
        ),
      ),
      (route) => false,
    );
  }
}

class _SchoolDashboardState extends State<SchoolDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late final List<Widget> _pages;
  String? _role;
  Set<String>? _permissions;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _pages = [
      DashboardHome(onNavigate: _onMenuItemSelected),
      StudentsPage(),
      StaffPage(),
      GradesPage(),
      PaymentsPage(),
      SettingsPage(),
      const UsersManagementPage(),
    ];
    _loadCurrentRole();
  }

  Future<void> _loadCurrentRole() async {
    final user = await AuthService.instance.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _role = user?.role;
      _permissions = user == null ? null : PermissionService.decodePermissions(user.permissions, role: user.role);
    });
  }

  

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMenuItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _animationController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onMenuItemSelected,
                isDarkMode: widget.isDarkMode,
                onThemeToggle: widget.onThemeToggle,
                animationController: _animationController,
                currentRole: _role,
                currentPermissions: _permissions,
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _pages[_selectedIndex],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}