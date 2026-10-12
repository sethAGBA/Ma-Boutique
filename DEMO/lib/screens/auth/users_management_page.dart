import 'package:flutter/material.dart';
import 'package:school_manager/models/user.dart';
import 'package:school_manager/services/auth_service.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:school_manager/services/permission_service.dart';
import 'package:school_manager/constants/colors.dart';
import 'package:school_manager/constants/sizes.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  List<AppUser> _users = [];
  bool _loading = true;
  AppUser? _current;
  String? _filterRole;
  
  List<AppUser> get _filteredUsers {
    if (_filterRole == null) return _users;
    return _users.where((u) => u.role == _filterRole).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseService().getAllUserRows();
    final me = await AuthService.instance.getCurrentUser();
    setState(() {
      _users = rows.map(AppUser.fromMap).toList();
      _loading = false;
      _current = me;
    });
  }

  Future<void> _showCreateUserDialog() async {
    final usernameCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    String role = 'staff';
    final passwordCtrl = TextEditingController();
    final passwordConfirmCtrl = TextEditingController();
    bool enable2FA = false;
    Set<String> selectedPerms = PermissionService.defaultForRole(role);
    bool obscurePwd = true;
    bool obscureConfirm = true;

        final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Créer un nouvel utilisateur'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: displayNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 20),
                      const SizedBox(width: 8),
                      const Text('Rôle:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                          DropdownMenuItem(value: 'staff', child: Text('Personnel')),
                          DropdownMenuItem(value: 'prof', child: Text('Professeur')),
                          DropdownMenuItem(value: 'viewer', child: Text('Observateur')),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setStateSB(() {
                            role = val;
                            selectedPerms = PermissionService.defaultForRole(role);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePwd,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscurePwd ? 'Afficher' : 'Masquer',
                        onPressed: () => setStateSB(() => obscurePwd = !obscurePwd),
                        icon: Icon(obscurePwd ? Icons.visibility : Icons.visibility_off),
                      ),
                      border: const OutlineInputBorder(),
                      helperText: 'Minimum 8 caractères',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordConfirmCtrl,
                    obscureText: obscureConfirm,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscureConfirm ? 'Afficher' : 'Masquer',
                        onPressed: () => setStateSB(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activer 2FA (TOTP)'),
                    subtitle: const Text('Authentification à deux facteurs'),
                    value: enable2FA,
                    onChanged: (v) => setStateSB(() => enable2FA = v),
                    secondary: const Icon(Icons.security),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Permissions', style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in {
                        ...PermissionService.defaultAdminPermissions,
                        ...PermissionService.defaultStaffPermissions,
                        ...PermissionService.defaultTeacherPermissions,
                      })
                        FilterChip(
                          selected: selectedPerms.contains(p),
                          label: Text(p),
                          onSelected: (sel) => setStateSB(() {
                            if (sel) {
                              selectedPerms.add(p);
                            } else {
                              selectedPerms.remove(p);
                            }
                          }),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final username = usernameCtrl.text.trim();
      final displayName = displayNameCtrl.text.trim();
      final password = passwordCtrl.text.trim();
      final confirm = passwordConfirmCtrl.text.trim();
      if (username.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le nom d\'utilisateur est obligatoire.')),
          );
        }
        return;
      }
      if (password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le mot de passe est obligatoire.')),
          );
        }
        return;
      }
      if (password.length < 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le mot de passe doit contenir au moins 8 caractères.')),
          );
        }
        return;
      }
      if (password != confirm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
          );
        }
        return;
      }
      await AuthService.instance.createOrUpdateUser(
        username: username,
        displayName: displayName,
        role: role,
        password: password,
        enable2FA: enable2FA,
        permissions: selectedPerms,
      );
      await _load();
    }
  }

  Future<void> _deleteUser(String username) async {
    // Prevent deleting the last admin
    final rows = await DatabaseService().getUserRowByUsername(username);
    if (rows != null) {
      final role = rows['role'] as String?;
      if (role == 'admin') {
        final adminsCount = await _countAdmins();
        if (adminsCount <= 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Impossible de supprimer le dernier compte admin.')),
            );
          }
          return;
        }
      }
    }
    await DatabaseService().deleteUserByUsername(username);
    await _load();
  }

  Future<void> _showEditUserDialog(AppUser user) async {
    final displayNameCtrl = TextEditingController(text: user.displayName);
    String role = user.role;
    final passwordCtrl = TextEditingController();
    final passwordConfirmCtrl = TextEditingController();
    bool enable2FA = user.isTwoFactorEnabled;
    Set<String> selectedPerms = PermissionService.decodePermissions(user.permissions, role: role);
    bool obscurePwd = true;
    bool obscureConfirm = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Modifier ${user.username}'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: displayNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 20),
                      const SizedBox(width: 8),
                      const Text('Rôle:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                          DropdownMenuItem(value: 'staff', child: Text('Personnel')),
                          DropdownMenuItem(value: 'prof', child: Text('Professeur')),
                          DropdownMenuItem(value: 'viewer', child: Text('Observateur')),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setStateSB(() {
                            role = val;
                            selectedPerms = PermissionService.defaultForRole(role);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePwd,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe (laisser vide pour conserver)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscurePwd ? 'Afficher' : 'Masquer',
                        onPressed: () => setStateSB(() => obscurePwd = !obscurePwd),
                        icon: Icon(obscurePwd ? Icons.visibility : Icons.visibility_off),
                      ),
                      border: const OutlineInputBorder(),
                      helperText: 'Laissez vide pour conserver le mot de passe actuel',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordConfirmCtrl,
                    obscureText: obscureConfirm,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscureConfirm ? 'Afficher' : 'Masquer',
                        onPressed: () => setStateSB(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activer 2FA (TOTP)'),
                    subtitle: const Text('Authentification à deux facteurs'),
                    value: enable2FA,
                    onChanged: (v) => setStateSB(() => enable2FA = v),
                    secondary: const Icon(Icons.security),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Permissions', style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in {
                        ...PermissionService.defaultAdminPermissions,
                        ...PermissionService.defaultStaffPermissions,
                        ...PermissionService.defaultTeacherPermissions,
                      })
                        FilterChip(
                          selected: selectedPerms.contains(p),
                          label: Text(p),
                          onSelected: (sel) => setStateSB(() {
                            if (sel) {
                              selectedPerms.add(p);
                            } else {
                              selectedPerms.remove(p);
                            }
                          }),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final displayName = displayNameCtrl.text.trim();
      final newPwd = passwordCtrl.text.trim();
      final confirm = passwordConfirmCtrl.text.trim();
      // Prevent demoting the last admin
      if (user.role == 'admin' && role != 'admin') {
        final adminsCount = await _countAdmins();
        if (adminsCount <= 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Impossible de rétrograder le dernier compte admin.')),
            );
          }
          return;
        }
        final confirmDemote = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Êtes-vous sûr de vouloir rétrograder cet administrateur ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
            ],
          ),
        );
        if (confirmDemote != true) return;
      }
      if (newPwd.isNotEmpty) {
        if (newPwd.length < 8) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Le mot de passe doit contenir au moins 8 caractères.')),
            );
          }
          return;
        }
        if (newPwd != confirm) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
            );
          }
          return;
        }
      }

      await AuthService.instance.updateUser(
        username: user.username,
        displayName: displayName.isEmpty ? null : displayName,
        role: role,
        newPassword: newPwd.isEmpty ? null : newPwd,
        enable2FA: enable2FA,
        permissions: selectedPerms,
      );
      await _load();
    }
  }

  Future<int> _countAdmins() async {
    final rows = await DatabaseService().getAllUserRows();
    return rows.where((r) => (r['role'] as String?) == 'admin').length;
  }



  @override
  Widget build(BuildContext context) {
    final perms = PermissionService.decodePermissions(_current?.permissions, role: _current?.role ?? 'staff');
    final bool isAdmin = _current?.role == 'admin';
    final bool canManage = isAdmin || perms.contains('manage_users');
    final bool allowed = canManage || perms.contains('view_users');
    
    if (!allowed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 64,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Accès refusé',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vous n\'avez pas les permissions nécessaires pour accéder à cette page.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 960),
          margin: EdgeInsets.symmetric(horizontal: AppSizes.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSizes.padding),
              _buildHeader(context, isDesktop),
              SizedBox(height: AppSizes.padding),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildUsersList(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
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
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: isDesktop ? 32 : 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion des utilisateurs',
                        style: TextStyle(
                          fontSize: isDesktop ? 32 : 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gérez les comptes utilisateurs, leurs rôles et permissions.',
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
                  if (_current?.role == 'admin' || PermissionService.decodePermissions(_current?.permissions, role: _current?.role ?? 'staff').contains('manage_users'))
                    ElevatedButton.icon(
                      onPressed: _showCreateUserDialog,
                      icon: Icon(Icons.add),
                      label: Text('Nouvel utilisateur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Filtre rôle
                DropdownButton<String?>(
                  value: _filterRole,
                  hint: Text('Rôle', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('Tous les rôles', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                    DropdownMenuItem<String?>(value: 'admin', child: Text('Administrateurs', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                    DropdownMenuItem<String?>(value: 'staff', child: Text('Personnel', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                    DropdownMenuItem<String?>(value: 'prof', child: Text('Professeurs', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                    DropdownMenuItem<String?>(value: 'viewer', child: Text('Observateurs', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                  ],
                  onChanged: (value) => setState(() => _filterRole = value),
                  dropdownColor: theme.cardColor,
                  iconEnabledColor: theme.iconTheme.color,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                const SizedBox(width: 16),
                // Bouton rafraîchir
                IconButton(
                  onPressed: _load,
                  icon: Icon(Icons.refresh, color: theme.iconTheme.color),
                  tooltip: 'Rafraîchir',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildUsersList(BuildContext context) {
    final theme = Theme.of(context);
    final perms = PermissionService.decodePermissions(_current?.permissions, role: _current?.role ?? 'staff');
    final bool isAdmin = _current?.role == 'admin';
    final bool canManage = isAdmin || perms.contains('manage_users');

    if (_loading) {
      return Container(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Utilisateurs (${_filteredUsers.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _filteredUsers.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (ctx, i) {
              final u = _filteredUsers[i];
              final raw = (u.displayName.trim().isNotEmpty ? u.displayName.trim() : u.username.trim());
              final initial = raw.isNotEmpty ? raw.substring(0, 1).toUpperCase() : '?';
              final titleText = raw.isNotEmpty ? raw : 'Utilisateur';
              
              return Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  titleText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              _buildRoleBadge(u.role),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${u.username}${u.isTwoFactorEnabled ? '  •  2FA activé' : ''}',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManage) ...[
                      IconButton(
                        tooltip: 'Modifier',
                        icon: Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
                        onPressed: () => _showEditUserDialog(u),
                      ),
                      if (u.isTwoFactorEnabled)
                        IconButton(
                          tooltip: 'Voir la configuration 2FA',
                          icon: Icon(Icons.key_outlined, color: Colors.orange),
                          onPressed: () async {
                            final uri = await AuthService.instance.getTotpProvisioningUri(u.username);
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Configurer 2FA'),
                                content: SelectableText(
                                  (uri == null)
                                      ? 'Aucun secret TOTP.'
                                      : 'Scannez ce lien dans Google Authenticator / Authy:\n\n$uri',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Fermer'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteUser(u.username),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'admin':
        color = Colors.red;
        label = 'ADMIN';
        break;
      case 'staff':
        color = AppColors.primaryBlue;
        label = 'STAFF';
        break;
      case 'prof':
        color = AppColors.successGreen;
        label = 'PROF';
        break;
      case 'viewer':
        color = Colors.grey;
        label = 'VIEWER';
        break;
      default:
        color = Colors.grey;
        label = role.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
