import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repo.dart';
import '../services/license_service.dart';
import 'caisse.dart';
import 'clients.dart';
import 'license_page.dart';
import 'parametres.dart';
import 'produits.dart';
import 'rapports.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _i = 0;

  static const _pages = <Widget>[
    CaissePage(),
    ProduitsPage(),
    ClientsPage(),
    RapportsPage(),
    ParametresPage(),
  ];

  static const _destinations = [
    ('Caisse', Icons.point_of_sale_rounded),
    ('Produits', Icons.inventory_2_rounded),
    ('Clients', Icons.people_alt_rounded),
    ('Rapports', Icons.bar_chart_rounded),
    ('Paramètres', Icons.settings_rounded),
  ];

  LicenseStatus? _licenseStatus;
  bool _allLicensesConsumed = false;

  @override
  void initState() {
    super.initState();
    _chargerLicence();
    LicenseService.instance.activeNotifier.addListener(_chargerLicence);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = context.read<Repo>();
      await repo.initialiserApplication();
    });
  }

  @override
  void dispose() {
    LicenseService.instance.activeNotifier.removeListener(_chargerLicence);
    super.dispose();
  }

  Future<void> _chargerLicence() async {
    final st = await LicenseService.instance.getStatus();
    final all = await LicenseService.instance.allKeysUsed();
    if (mounted) {
      setState(() {
        _licenseStatus = st;
        _allLicensesConsumed = all;
      });
    }
  }

  void _verrouillerSession() {
    context.read<Repo>().deconnecter();
  }

  Widget? _buildLicenseBanner() {
    if (_allLicensesConsumed) return null;
    final st = _licenseStatus;
    if (st == null) return null;

    if (st.isTrial && st.isActive) {
      return Container(
        color: const Color(0xFF1D4ED8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Version d’essai gratuite : il vous reste ${st.daysRemaining} jour(s) d’utilisation sur 14.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1D4ED8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranLicence())),
              child: const Text('Activer la licence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (st.isExpired) {
      return Container(
        color: const Color(0xFFDC2626),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                st.isTrial
                    ? 'Période d’essai de 14 jours terminée. Veuillez activer une clé de licence commerciale.'
                    : 'Votre licence logicielle est expirée. Veuillez activer une nouvelle clé.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranLicence())),
              child: const Text('Activer la licence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (!st.isLifetime && st.daysRemaining <= 14) {
      return Container(
        color: const Color(0xFFD97706),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Votre licence commerciale expire dans ${st.daysRemaining} jour(s). Pensez à renouveler votre clé.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD97706),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcranLicence())),
              child: const Text('Gérer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 850;
    final repo = context.watch<Repo>();
    final userActif = repo.utilisateurActif;
    final bool estGerant = userActif?.estGerant == true;

    // Le caissier ne doit pas voir les Rapports ni les Paramètres
    final List<(String, IconData)> destinationsActives = estGerant
        ? _destinations
        : _destinations.sublist(0, 3);

    // Ajustement de l'index si la page active n'est pas autorisée
    final currentIndex = _i < destinationsActives.length ? _i : 0;
    final body = IndexedStack(index: currentIndex, children: _pages);

    if (large) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 105,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/iconmaboutique.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ma Boutique',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(indent: 16, endIndent: 16),
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (i) => setState(() => _i = i),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.transparent,
                      indicatorColor: theme.colorScheme.primaryContainer,
                      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
                      selectedLabelTextStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      destinations: [
                        for (final d in destinationsActives)
                          NavigationRailDestination(
                            icon: Icon(d.$2),
                            label: Text(d.$1),
                          ),
                      ],
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  // Profil & Bouton Verrouiller
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Tooltip(
                      message: 'Verrouiller la session (${userActif?.nom ?? 'Non connecté'})',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _verrouillerSession,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                userActif?.estGerant == true ? Icons.admin_panel_settings_rounded : Icons.lock_outline_rounded,
                                size: 20,
                                color: const Color(0xFF475569),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userActif?.nom ?? 'Verrouiller',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  if (_buildLicenseBanner() != null) _buildLicenseBanner()!,
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (_buildLicenseBanner() != null) _buildLicenseBanner()!,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => _i = i),
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: [
          for (final d in destinationsActives)
            NavigationDestination(
              icon: Icon(d.$2),
              label: d.$1,
            ),
        ],
      ),
    );
  }
}

