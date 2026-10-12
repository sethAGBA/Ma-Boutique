import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'helpers.dart';
import 'ticket_service.dart';

class PanierEnAttente {
  final int id;
  final DateTime date;
  final List<LigneVente> lignes;
  final int remise;

  PanierEnAttente({
    required this.id,
    required this.date,
    required this.lignes,
    this.remise = 0,
  });

  int get total {
    final sub = lignes.fold(0, (sum, l) => sum + l.total);
    return (sub - remise) > 0 ? (sub - remise) : 0;
  }
}

class CaissePage extends StatefulWidget {
  const CaissePage({super.key});

  @override
  State<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends State<CaissePage> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  final List<LigneVente> _panier = [];
  final List<PanierEnAttente> _paniersEnAttente = [];
  int _remise = 0;
  int _panierNum = 1;
  String _query = '';
  String? _selectedCategory;

  int get _sousTotal => _panier.fold(0, (s, l) => s + l.total);
  int get _total => (_sousTotal - _remise) > 0 ? (_sousTotal - _remise) : 0;
  int get _totalArticles => _panier.fold(0, (s, l) => s + l.qte);

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ajouter(Produit p, {int qte = 1, bool estGros = false}) {
    if (qte <= 0) return;
    setState(() {
      final i = _panier.indexWhere((l) => l.produit.id == p.id && l.estGros == estGros);
      if (i >= 0) {
        _panier[i].qte += qte;
      } else {
        _panier.add(LigneVente(produit: p, qte: qte, estGros: estGros));
      }
    });
  }

  Future<void> _ajouterAvecQuantite(Produit p) async {
    final n = await demanderNombre(
      context,
      titre: 'Quantité : ${p.nom}',
      label: 'Nombre d’unités (${p.unite})',
      initial: 1,
    );
    if (n != null && n > 0 && mounted) {
      _ajouter(p, qte: n);
    }
  }

  Future<void> _modifierQuantite(int i) async {
    final l = _panier[i];
    final n = await demanderNombre(
      context,
      titre: 'Quantité : ${l.produit.nom}',
      label: 'Nombre d’unités (${l.produit.unite})',
      initial: l.qte,
    );
    if (n != null && mounted) {
      setState(() {
        if (n <= 0) {
          _panier.removeAt(i);
        } else {
          l.qte = n;
        }
      });
    }
  }

  /// Entrée clavier / lecteur de code-barres : gère aussi la quantité avec "*" (ex: 10*code).
  Future<void> _validerSaisie(String saisie) async {
    String code = saisie.trim();
    int quantite = 1;

    if (code.contains('*')) {
      final parties = code.split('*');
      final qteSaisie = int.tryParse(parties.first.trim());
      if (qteSaisie != null && qteSaisie > 0) {
        quantite = qteSaisie;
        code = parties.sublist(1).join('*').trim();
      }
    }

    final p = await context.read<Repo>().parCodeBarres(code);
    if (!mounted) return;
    if (p != null) {
      _ajouter(p, qte: quantite);
      _q.clear();
      setState(() => _query = '');
    }
    _focus.requestFocus();
  }

  void _mettreEnAttente() {
    if (_panier.isEmpty) return;
    final numPanier = _panierNum++;
    setState(() {
      _paniersEnAttente.add(PanierEnAttente(
        id: numPanier,
        date: DateTime.now(),
        lignes: List<LigneVente>.from(_panier),
        remise: _remise,
      ));
      _panier.clear();
      _remise = 0;
    });
    message(context, '✓ Panier #$numPanier mis en attente');
    _focus.requestFocus();
  }

  Future<void> _afficherPaniersEnAttente() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text('Paniers en attente (${_paniersEnAttente.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: _paniersEnAttente.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Aucun panier en attente')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _paniersEnAttente.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = _paniersEnAttente[idx];
                      final heure = DateFormat('HH:mm').format(p.date);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFFB45309),
                          child: Text('#${p.id}'),
                        ),
                        title: Text(
                          '${p.lignes.length} article(s) • ${fcfa(p.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('Mis en attente à $heure'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                              tooltip: 'Supprimer',
                              onPressed: () {
                                setState(() => _paniersEnAttente.removeAt(idx));
                                setDialogState(() {});
                              },
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                if (_panier.isNotEmpty) {
                                  final ok = await confirmer(
                                    ctx,
                                    'Le panier en cours n’est pas vide. Voulez-vous le remplacer ?',
                                    oui: 'Remplacer',
                                  );
                                  if (!ok) return;
                                }
                                setState(() {
                                  _panier
                                    ..clear()
                                    ..addAll(p.lignes);
                                  _remise = p.remise;
                                  _paniersEnAttente.removeAt(idx);
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Reprendre'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  Future<void> _modifierRemise() async {
    final n = await showDialog<int>(
      context: context,
      builder: (_) => _RemiseDialog(
        sousTotal: _sousTotal,
        remiseActuelle: _remise,
      ),
    );
    if (n != null && mounted) {
      setState(() => _remise = n > _sousTotal ? _sousTotal : n);
    }
  }

  Future<void> _encaisser() async {
    final repo = context.read<Repo>();
    final r = await showDialog<(int, int?)>(
      context: context,
      builder: (_) => _PaiementDialog(total: _total),
    );
    if (r == null || !mounted) return;

    final copiePanier = List<LigneVente>.from(_panier);
    final totalVente = _total;
    final remiseVente = _remise;

    try {
      final venteId = await repo.enregistrerVente(
        copiePanier,
        montantPaye: r.$1,
        clientId: r.$2,
        remise: remiseVente,
      );
      if (!mounted) return;
      setState(() {
        _panier.clear();
        _remise = 0;
      });
      _q.clear();
      _focus.requestFocus();

      // Afficher le reçu de vente / ticket de caisse
      await showDialog<void>(
        context: context,
        builder: (_) => _TicketDialog(
          venteId: venteId,
          lignes: copiePanier,
          total: totalVente,
          montantPaye: r.$1,
          clientId: r.$2,
          remise: remiseVente,
        ),
      );
    } catch (e) {
      if (mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final large = MediaQuery.sizeOf(context).width >= 750;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Caisse'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Prêt pour vente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: large
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _produitsPane(repo)),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: _panierPane()),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: _produitsPane(repo)),
                const Divider(height: 1),
                Expanded(flex: 2, child: _panierPane()),
              ],
            ),
    );
  }

  Widget _produitsPane(Repo repo) {
    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _q,
            focusNode: _focus,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher un produit ou scanner un code-barres...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _q.clear();
                        setState(() => _query = '');
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Tooltip(
                      message: 'Compatible douchette code-barres USB',
                      child: Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: _validerSaisie,
          ),
        ),

        // Filtres par catégories
        FutureBuilder<List<String>>(
          future: repo.categories(),
          builder: (context, snap) {
            final categories = snap.data ?? const <String>[];
            if (categories.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilterChip(
                    selected: _selectedCategory == null,
                    label: const Text('Tous'),
                    onSelected: (_) => setState(() => _selectedCategory = null),
                    showCheckmark: false,
                  ),
                  for (final cat in categories)
                    FilterChip(
                      selected: _selectedCategory == cat,
                      label: Text(cat),
                      onSelected: (sel) => setState(() => _selectedCategory = sel ? cat : null),
                      showCheckmark: false,
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 4),

        // Grille des produits
        Expanded(
          child: FutureBuilder<List<Produit>>(
            future: _query.isEmpty && _selectedCategory == null
                ? repo.produitsFrequents()
                : repo.produits(q: _query, categorie: _selectedCategory),
            builder: (context, snap) {
              final liste = snap.data ?? const <Produit>[];
              if (liste.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'Aucun produit enregistré.'
                              : 'Aucun produit ne correspond à « $_query ».',
                          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  childAspectRatio: 1.25,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: liste.length,
                itemBuilder: (_, i) => _tuile(liste[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tuile(Produit p) {
    final theme = Theme.of(context);
    final isLow = p.enAlerte;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _ajouter(p),
        onLongPress: () => _ajouterAvecQuantite(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom du produit
              Expanded(
                child: Text(
                  p.nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Stock indicateur
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isLow ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLow ? '⚠️ Stock: ${p.stock}' : 'Stock: ${p.stock} ${p.unite}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Prix de vente
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fcfa(p.prixVente),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (p.prixGros > 0)
                        Text(
                          'Gros: ${fcfa(p.prixGros)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panierPane() {
    final theme = Theme.of(context);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête du panier
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Panier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                if (_panier.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalArticles art.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                const Spacer(),
                if (_paniersEnAttente.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFFEF3C7),
                      side: const BorderSide(color: Color(0xFFFCD34D)),
                      avatar: const Icon(Icons.pause_circle_filled_rounded, size: 16, color: Color(0xFFD97706)),
                      label: Text(
                        '${_paniersEnAttente.length} en attente',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                      onPressed: _afficherPaniersEnAttente,
                    ),
                  ),
                if (_panier.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Mettre en attente',
                    icon: const Icon(Icons.pause_circle_outline_rounded, size: 20, color: Color(0xFFD97706)),
                    onPressed: _mettreEnAttente,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await confirmer(context, 'Voulez-vous vider le panier actuel ?', oui: 'Vider');
                      if (ok && mounted) {
                        setState(() {
                          _panier.clear();
                          _remise = 0;
                        });
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Color(0xFFEF4444)),
                    label: const Text('Vider', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste des articles
          Expanded(
            child: _panier.isEmpty
                ? const Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_shopping_cart_rounded, size: 36, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text(
                            'Panier vide',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Touchez un produit pour l’ajouter',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _panier.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ligne(i),
                  ),
          ),

          // Pied de page / Total & Encaissement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Bouton de remise commerciale
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _panier.isEmpty ? null : _modifierRemise,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _remise > 0 ? Icons.discount_rounded : Icons.discount_outlined,
                              size: 15,
                              color: _remise > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _remise > 0 ? 'Remise accordée' : 'Ajouter une remise',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _remise > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _remise > 0 ? '- ${fcfa(_remise)}' : '0 F',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _remise > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_remise > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(fcfa(_sousTotal), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      fcfa(_total),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _panier.isEmpty ? null : _encaisser,
                    icon: const Icon(Icons.payments_rounded, size: 22),
                    label: const Text(
                      'ENCAISSER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(int i) {
    final l = _panier[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Détails produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.produit.nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '${fcfa(l.prixUnitaire)} / ${l.produit.unite}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          l.estGros = !l.estGros;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: l.estGros ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: l.estGros ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              l.estGros ? Icons.inventory_2_rounded : Icons.shopping_bag_outlined,
                              size: 11,
                              color: l.estGros ? const Color(0xFFB45309) : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              l.estGros ? 'GROS' : 'DÉTAIL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: l.estGros ? const Color(0xFFB45309) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stepper quantité
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => setState(() {
                    if (l.qte > 1) {
                      l.qte--;
                    } else {
                      _panier.removeAt(i);
                    }
                  }),
                ),
                Tooltip(
                  message: 'Appuyez pour saisir directement la quantité',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _modifierQuantite(i),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${l.qte}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => setState(() => l.qte++),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Total de la ligne
          SizedBox(
            width: 75,
            child: Text(
              fcfa(l.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fenêtre d'encaissement moderne : montant reçu, monnaie à rendre, ou reste à crédit.
class _PaiementDialog extends StatefulWidget {
  final int total;
  const _PaiementDialog({required this.total});

  @override
  State<_PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<_PaiementDialog> {
  late final TextEditingController _c = TextEditingController(text: '${widget.total}');
  List<Client> _clients = [];
  int? _clientId;

  int get _recu => toInt(_c.text);

  @override
  void initState() {
    super.initState();
    context.read<Repo>().clients().then((l) {
      if (mounted) setState(() => _clients = l);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _fixer(int v) => setState(() => _c.text = '$v');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.total;
    final recu = _recu;
    final credit = recu < total;
    final peutValider = !credit || _clientId != null;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Règlement', style: TextStyle(fontWeight: FontWeight.w700)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fcfa(total),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saisie du montant reçu
              TextField(
                controller: _c,
                autofocus: true,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant reçu par le client',
                  suffixText: 'F CFA',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Raccourcis billets de banque courants
              const Text('Coupures rapides :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 16),
                    label: const Text('Exact'),
                    onPressed: () => _fixer(total),
                  ),
                  for (final v in const [500, 1000, 2000, 5000, 10000, 20000])
                    ActionChip(
                      label: Text(fcfa(v)),
                      onPressed: () => _fixer(v),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Résultat : Monnaie à rendre OU Dette à crédit
              if (!credit)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Color(0xFF16A34A), size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monnaie à rendre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
                          Text(
                            fcfa(recu - total),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reste à crédit (dette client)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                          Text(
                            fcfa(total - recu),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _clientId,
                  decoration: const InputDecoration(
                    labelText: 'Attribuer la dette au client *',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  items: [
                    for (final c in _clients) DropdownMenuItem(value: c.id, child: Text('${c.nom} (${c.telephone})')),
                  ],
                  onChanged: (v) => setState(() => _clientId = v),
                ),
                if (_clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Aucun client enregistré. Ajoutez un client dans l’onglet Clients.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: peutValider ? () => Navigator.pop(context, (recu, _clientId)) : null,
          child: const Text('Valider la vente'),
        ),
      ],
    );
  }
}

/// Ticket de caisse numérique élégant avec récapitulatif et partage WhatsApp / texte.
class _TicketDialog extends StatelessWidget {
  final int venteId;
  final List<LigneVente> lignes;
  final int total;
  final int montantPaye;
  final int? clientId;
  final int remise;

  const _TicketDialog({
    required this.venteId,
    required this.lignes,
    required this.total,
    required this.montantPaye,
    this.clientId,
    this.remise = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final rendu = montantPaye >= total ? montantPaye - total : 0;
    final resteCredit = total > montantPaye ? total - montantPaye : 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Entête du ticket
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
              const SizedBox(height: 8),
              const Text(
                'Vente enregistrée !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'Ticket N° #$venteId • $dateStr',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              // Conteneur style ticket de caisse
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (final l in lignes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${l.qte}x ${l.produit.nom}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              fcfa(l.total),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 16),
                    if (remise > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sous-total', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(fcfa(total + remise), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remise accordée', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          Text('- ${fcfa(remise)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL PAYÉ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          fcfa(total),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reçu', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(fcfa(montantPaye), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    if (rendu > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monnaie rendue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                          Text(fcfa(rendu), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        ],
                      ),
                    if (resteCredit > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reste à crédit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          Text(fcfa(resteCredit), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => TicketService.imprimerTicket(
                context: context,
                venteId: venteId,
                lignes: lignes,
                total: total,
                montantPaye: montantPaye,
                remise: remise,
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Imprimer'),
            ),
            OutlinedButton.icon(
              onPressed: () => TicketService.telechargerPdf(
                context: context,
                venteId: venteId,
                lignes: lignes,
                total: total,
                montantPaye: montantPaye,
                remise: remise,
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Télécharger PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => TicketService.partagerTicket(
                venteId: venteId,
                lignes: lignes,
                total: total,
                montantPaye: montantPaye,
                remise: remise,
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Partager'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vente suivante'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fenêtre de remise commerciale : montant en Francs CFA ou pourcentage (%).
class _RemiseDialog extends StatefulWidget {
  final int sousTotal;
  final int remiseActuelle;

  const _RemiseDialog({
    required this.sousTotal,
    required this.remiseActuelle,
  });

  @override
  State<_RemiseDialog> createState() => _RemiseDialogState();
}

class _RemiseDialogState extends State<_RemiseDialog> {
  bool _enPourcentage = false;
  late final TextEditingController _ctrl;
  int _montantCalcule = 0;

  @override
  void initState() {
    super.initState();
    _montantCalcule = widget.remiseActuelle;
    _ctrl = TextEditingController(
      text: widget.remiseActuelle > 0 ? '${widget.remiseActuelle}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _calculer() {
    final val = double.tryParse(_ctrl.text.replaceAll(',', '.').trim()) ?? 0;
    setState(() {
      if (_enPourcentage) {
        _montantCalcule = ((widget.sousTotal * val) / 100).round();
      } else {
        _montantCalcule = val.round();
      }
      if (_montantCalcule > widget.sousTotal) {
        _montantCalcule = widget.sousTotal;
      }
    });
  }

  void _appliquerPourcentage(int pct) {
    setState(() {
      _enPourcentage = true;
      _ctrl.text = '$pct';
      _calculer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.discount_rounded, color: Color(0xFFD97706)),
          SizedBox(width: 10),
          Text('Remise Commerciale', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sous-total du panier : ${fcfa(widget.sousTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            // Sélecteur Montant fixe vs Pourcentage
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Montant (F CFA)'),
                  icon: Icon(Icons.money_rounded, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Pourcentage (%)'),
                  icon: Icon(Icons.percent_rounded, size: 16),
                ),
              ],
              selected: {_enPourcentage},
              onSelectionChanged: (set) {
                setState(() {
                  _enPourcentage = set.first;
                  _ctrl.clear();
                  _montantCalcule = 0;
                });
              },
            ),
            const SizedBox(height: 16),
            // Raccourcis rapides de pourcentage
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final p in [5, 10, 15, 20])
                  ActionChip(
                    label: Text('$p%'),
                    avatar: const Icon(Icons.bolt_rounded, size: 14),
                    onPressed: () => _appliquerPourcentage(p),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _enPourcentage ? 'Taux de remise (%)' : 'Montant de réduction (F CFA)',
                suffixText: _enPourcentage ? '%' : 'F CFA',
              ),
              onChanged: (_) => _calculer(),
            ),
            const SizedBox(height: 14),
            // Récapitulatif
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Réduction appliquée :',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                  ),
                  Text(
                    '- ${fcfa(_montantCalcule)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.remiseActuelle > 0)
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Supprimer remise'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _montantCalcule),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

