import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repo.dart';
import 'caisse.dart';
import 'clients.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = context.read<Repo>();
      await repo.initialiserApplication();
    });
  }

  void _verrouillerSession() {
    context.read<Repo>().deconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 850;
    final body = IndexedStack(index: _i, children: _pages);
    final repo = context.watch<Repo>();
    final userActif = repo.utilisateurActif;

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
                    width: 48,
                    height: 48,
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
                      selectedIndex: _i,
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
                        for (final d in _destinations)
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
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$2),
              label: d.$1,
            ),
        ],
      ),
    );
  }
}

