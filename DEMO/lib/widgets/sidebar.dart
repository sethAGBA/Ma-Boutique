import 'package:flutter/material.dart';
import 'package:school_manager/main.dart';
import 'dart:math';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isDarkMode;
  final Function(bool) onThemeToggle;
  final AnimationController animationController;
  final String? currentRole;
  final Set<String>? currentPermissions;

  Sidebar({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.animationController,
    this.currentRole,
    this.currentPermissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Color(0xFF1E3A8A), Color(0xFF3B82F6)]
              : [Color(0xFF60A5FA), Color(0xFF93C5FD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: animationController.value * 2 * pi,
                      child: Icon(
                        Icons.school,
                        size: 50,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                Text(
                  'École Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
            title: Text(
              isDarkMode ? 'Mode Sombre' : 'Mode Clair',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: Switch(
              value: isDarkMode,
              onChanged: onThemeToggle,
              activeColor: Colors.blue[300],
            ),
          ),
          Divider(color: Theme.of(context).dividerColor),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  _buildMenuItem(0, Icons.dashboard, 'Tableau de bord'),
                  _buildMenuItem(1, Icons.people, 'Élèves'),
                  _buildMenuItem(2, Icons.person, 'Personnel'),
                  _buildMenuItem(3, Icons.grade, 'Notes & Bulletins'),
                  _buildMenuItem(4, Icons.payment, 'Paiements'),
                  _buildMenuItem(5, Icons.settings, 'Paramètres'),
                  if ((currentRole ?? '') == 'admin' || (currentPermissions?.contains('view_users') ?? false))
                    _buildMenuItem(6, Icons.admin_panel_settings, 'Utilisateurs'),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Déconnexion'),
                            content: const Text('Voulez-vous vous déconnecter ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Se déconnecter')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          // Import here to avoid top-level dependency for this file
                          // ignore: use_build_context_synchronously
                          await _handleLogout(context);
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    bool isSelected = selectedIndex == index;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 28,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          onTap: () => onItemSelected(index),
        ),
      ),
    );
  }
}

Future<void> _handleLogout(BuildContext context) async {
  // Delay import to avoid cyclic import warning
  // Directly call AuthService
  // ignore: depend_on_referenced_packages
  // ignore: use_build_context_synchronously
  // We import at top-level in the original file; to avoid circularity, we access via a static method
  // The simplest approach: push a new MyApp by clearing current user and rebuilding
  // Import service here
  // ignore_for_file: library_prefixes
  // ignore: unnecessary_import
  // ignore: implementation_imports
  // Use a small helper to avoid needing context outside
  // Real call:
  // await AuthService.instance.logout();
  // But since we can't import here dynamically, we use a method channel-like workaround
  // We will add a small global function in main.dart to handle logout
  await performGlobalLogout(context);
}