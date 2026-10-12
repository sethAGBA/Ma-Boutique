import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'declarer_perte_dialog.dart';
import 'helpers.dart';
import 'searchable_dropdown.dart';

class ProduitsPage extends StatefulWidget {
  const ProduitsPage({super.key});

  @override
  State<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends State<ProduitsPage> {
  String _q = '';
  String? _selectedCategory;
  bool _onlyAlerts = false;

  Future<void> _exporterCsv() async {
    final repo = context.read<Repo>();
    final csv = await repo.exportProduitsCsv();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final nomFichier = 'catalogue_produits_$dateStr.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));

    if (mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: bytes,
        titreDialogue: 'Exporter le catalogue des produits',
      );
    }
  }

  Future<void> _importerCsv() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choisir un fichier CSV de produits',
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (res == null || res.files.single.path == null) return;

      final fichier = File(res.files.single.path!);
      final contenu = await fichier.readAsString();
      if (!mounted) return;

      final repo = context.read<Repo>();
      final count = await repo.importProduitsCsv(contenu);
      if (mounted) {
        message(context, '✓ $count produit(s) importé(s) ou mis à jour avec succès !');
      }
    } catch (e) {
      if (mounted) message(context, 'Erreur lors de l’importation : ${texteErreur(e)}', erreur: true);
    }
  }

  Future<void> _editer(Produit? p) async {
    final repo = context.read<Repo>();
    final r = await showDialog<(Produit, int)>(
      context: context,
      builder: (_) => _ProduitForm(produit: p),
    );
    if (r == null) return;
    await repo.sauverProduit(r.$1, stockInitial: r.$2);
  }

  Future<void> _entreeRapide(Produit p) async {
    final repo = context.read<Repo>();
    final n = await demanderNombre(
      context,
      titre: 'Entrée de stock : ${p.nom}',
      label: 'Quantité reçue (${p.unite})',
    );
    if (n != null && n > 0) {
      await repo.entreeStock(p.id!, n);
      if (mounted) message(context, '✓ $n ${p.unite}(s) ajoutée(s) à « ${p.nom} »');
    }
  }

  Future<void> _action(String a, Produit p) async {
    final repo = context.read<Repo>();
    switch (a) {
      case 'entree':
        await _entreeRapide(p);
      case 'perte':
        await showDialog<void>(
          context: context,
          builder: (_) => DeclarerPerteDialog(produitInitial: p),
        );
      case 'deconditionner':
        final nb = await demanderNombre(
          context,
          titre: 'Déconditionner : ${p.nom}',
          label: 'Nombre de cartons parents à ouvrir',
          initial: 1,
        );
        if (nb != null && nb > 0 && mounted) {
          try {
            await repo.deconditionnerProduit(produitDetailId: p.id!, nbCartons: nb);
            if (mounted) {
              message(context, '✓ $nb carton(s) ouvert(s) : +${nb * p.facteurConversion} ${p.unite}(s) au stock !');
            }
          } catch (e) {
            if (mounted) message(context, texteErreur(e), erreur: true);
          }
        }
      case 'ajuster':
        final n = await demanderNombre(
          context,
          titre: 'Inventaire réel : ${p.nom}',
          label: 'Nouveau stock compté (${p.unite})',
          initial: p.stock,
        );
        if (n != null) {
          await repo.ajusterStock(p.id!, n);
          if (mounted) message(context, '✓ Stock de « ${p.nom} » ajusté à $n');
        }
      case 'supprimer':
        final ok = await confirmer(
          context,
          'Supprimer définitivement « ${p.nom} » du rayon ? Les historiques de ventes seront préservés.',
          oui: 'Supprimer',
        );
        if (ok) {
          await repo.supprimerProduit(p.id!);
          if (mounted) message(context, 'Produit supprimé');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits & Stock'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Options du catalogue',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'exporter') _exporterCsv();
              if (val == 'importer') _importerCsv();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'exporter',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF15803D)),
                    SizedBox(width: 10),
                    Text('Exporter en CSV (Excel)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'importer',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 20, color: Color(0xFF0F766E)),
                    SizedBox(width: 10),
                    Text('Importer depuis un CSV'),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const DeclarerPerteDialog(),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFDC2626)),
            label: const Text('Déclarer perte', style: TextStyle(color: Color(0xFFDC2626))),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _editer(null),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Nouveau produit'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et statistiques
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un produit par nom, catégorie, code-barres...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(() => _q = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          // Filtres par catégorie et bouton filtre alerte (sur plusieurs lignes sans défilement horizontal forcé)
          FutureBuilder<List<String>>(
            future: repo.categories(),
            builder: (context, snap) {
              final categories = snap.data ?? const <String>[];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      selected: _selectedCategory == null && !_onlyAlerts,
                      label: const Text('Tous'),
                      onSelected: (_) => setState(() {
                        _selectedCategory = null;
                        _onlyAlerts = false;
                      }),
                      showCheckmark: false,
                    ),
                    FilterChip(
                      selected: _onlyAlerts,
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Stocks en alerte'),
                      onSelected: (sel) => setState(() => _onlyAlerts = sel),
                      showCheckmark: false,
                    ),
                    for (final cat in categories)
                      FilterChip(
                        selected: _selectedCategory == cat && !_onlyAlerts,
                        label: Text(cat),
                        onSelected: (sel) => setState(() {
                          _selectedCategory = sel ? cat : null;
                          _onlyAlerts = false;
                        }),
                        showCheckmark: false,
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          // Liste des produits
          Expanded(
            child: FutureBuilder<List<Produit>>(
              future: _onlyAlerts
                  ? repo.produitsEnAlerte()
                  : repo.produits(q: _q, categorie: _selectedCategory),
              builder: (context, snap) {
                final liste = snap.data ?? const <Produit>[];
                if (liste.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 54, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            _onlyAlerts
                                ? 'Aucun produit en rupture ou en alerte !'
                                : (_q.isEmpty ? 'Aucun produit dans le catalogue.' : 'Aucun résultat trouvé pour « $_q ».'),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          if (_q.isEmpty && !_onlyAlerts)
                            FilledButton.tonalIcon(
                              onPressed: () => _editer(null),
                              icon: const Icon(Icons.add),
                              label: const Text('Créer mon premier produit'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: liste.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = liste[i];
                    return _produitCard(p);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _produitCard(Produit p) {
    final theme = Theme.of(context);
    final isLow = p.enAlerte;
    final marge = p.prixVente - p.prixAchat;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editer(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar avec initiale
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLow ? const Color(0xFFFEE2E2) : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    p.nom.isNotEmpty ? p.nom[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isLow ? const Color(0xFFDC2626) : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Informations du produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nom,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.categorie.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.categorie,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          fcfa(p.prixVente),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  Achat : ${fcfa(p.prixAchat)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (marge > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(+${fcfa(marge)})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                          ),
                        ],
                        if (p.prixGros > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•  Gros : ${fcfa(p.prixGros)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                          ),
                        ],
                        if (p.estDeconditionne) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Text(
                              '📦 ${p.produitParentNom ?? "Carton"} (x${p.facteurConversion})',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Badge Stock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLow ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLow ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p.stock} ${p.unite}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isLow ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isLow ? 'Alerte ≤ ${p.seuilAlerte}' : 'Seuil : ${p.seuilAlerte}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isLow ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Bouton rapide "+ Stock"
              IconButton.filledTonal(
                tooltip: 'Réapprovisionner (+ Stock)',
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                onPressed: () => _entreeRapide(p),
              ),

              // Menu 3 points
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                onSelected: (a) => _action(a, p),
                itemBuilder: (_) => [
                  if (p.estDeconditionne)
                    PopupMenuItem(
                      value: 'deconditionner',
                      child: Row(
                        children: [
                          const Icon(Icons.unarchive_rounded, size: 20, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Text('Ouvrir carton (+${p.facteurConversion} ${p.unite})'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'perte',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 20, color: Color(0xFFDC2626)),
                        SizedBox(width: 10),
                        Text('Déclarer perte / avarie'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ajuster',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Inventaire (ajuster)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'supprimer',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProduitForm extends StatefulWidget {
  final Produit? produit;
  const _ProduitForm({this.produit});

  @override
  State<_ProduitForm> createState() => _ProduitFormState();
}

class _ProduitFormState extends State<_ProduitForm> {
  final _cle = GlobalKey<FormState>();
  late final TextEditingController _nom, _code, _cat, _unite, _achat, _vente, _gros, _stock, _seuil, _facteurConversion;
  int? _produitParentId;
  List<Produit> _produitsDisponibles = [];

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    _nom = TextEditingController(text: p?.nom ?? '');
    _code = TextEditingController(text: p?.codeBarres ?? '');
    _cat = TextEditingController(text: p?.categorie ?? '');
    _unite = TextEditingController(text: p?.unite ?? 'pièce');
    _achat = TextEditingController(text: p == null ? '' : '${p.prixAchat}');
    _vente = TextEditingController(text: p == null ? '' : '${p.prixVente}');
    _gros = TextEditingController(text: p == null ? '' : (p.prixGros > 0 ? '${p.prixGros}' : ''));
    _stock = TextEditingController(text: '0');
    _seuil = TextEditingController(text: '${p?.seuilAlerte ?? 5}');
    _produitParentId = p?.produitParentId;
    _facteurConversion = TextEditingController(text: '${p?.facteurConversion ?? 1}');

    context.read<Repo>().produits().then((list) {
      if (mounted) {
        setState(() {
          _produitsDisponibles = list.where((prod) => prod.id != widget.produit?.id).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_nom, _code, _cat, _unite, _achat, _vente, _gros, _stock, _seuil, _facteurConversion]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _champ(
    TextEditingController c,
    String label, {
    bool nombre = false,
    bool requis = false,
    bool autofocus = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        autofocus: autofocus,
        keyboardType: nombre ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        validator: (v) {
          if (requis && (v == null || v.trim().isEmpty)) return 'Ce champ est requis';
          if (requis && nombre && toInt(v!) <= 0) return 'Le montant doit être supérieur à 0';
          return null;
        },
      ),
    );
  }

  void _enregistrer() {
    if (!_cle.currentState!.validate()) return;
    final conv = toInt(_facteurConversion.text);
    final p = Produit(
      id: widget.produit?.id,
      nom: _nom.text.trim(),
      codeBarres: _code.text.trim(),
      categorie: _cat.text.trim(),
      unite: _unite.text.trim().isEmpty ? 'pièce' : _unite.text.trim(),
      prixAchat: toInt(_achat.text),
      prixVente: toInt(_vente.text),
      prixGros: toInt(_gros.text),
      seuilAlerte: toInt(_seuil.text),
      produitParentId: _produitParentId,
      facteurConversion: conv > 0 ? conv : 1,
    );
    Navigator.pop(context, (p, toInt(_stock.text)));
  }

  @override
  Widget build(BuildContext context) {
    final creation = widget.produit == null;
    return AlertDialog(
      title: Text(
        creation ? 'Nouveau produit' : 'Modifier le produit',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _cle,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _champ(_nom, 'Nom du produit *', requis: true, autofocus: true, hint: 'Ex: Savon Sunlight, Huile 1L...'),
                Row(
                  children: [
                    Expanded(child: _champ(_vente, 'Prix détail (F) *', nombre: true, requis: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _champ(_gros, 'Prix de gros (F)', nombre: true, hint: 'Carton / sac...')),
                    const SizedBox(width: 10),
                    Expanded(child: _champ(_achat, 'Prix d’achat (F)', nombre: true)),
                  ],
                ),
                Row(
                  children: [
                    if (creation) ...[
                      Expanded(child: _champ(_stock, 'Stock initial', nombre: true)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: _champ(_seuil, 'Seuil alerte stock', nombre: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _champ(_unite, 'Unité', hint: 'pièce, kg, sac, litre...')),
                    const SizedBox(width: 12),
                    Expanded(child: _champ(_cat, 'Catégorie', hint: 'Boissons, Épicerie...')),
                  ],
                ),
                _champ(_code, 'Code-barres (facultatif)', hint: 'Scannez avec la douchette'),

                // Liaison multi-conditionnement / déconditionnement carton
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text('Liaison Carton / Déconditionnement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Si cet article est vendu au détail issu d’un carton parent (ex: paquet de spaghetti issu du carton Bonita) :',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      SearchableDropdown<int?>(
                        value: _produitParentId,
                        label: 'Carton parent de réserve (facultatif)',
                        hint: 'Rechercher parmi les 300+ articles...',
                        titreDialogue: 'Sélectionner le carton parent',
                        prefixIcon: Icons.archive_rounded,
                        permetEffacer: true,
                        texteEffacer: 'Aucun carton parent (article indépendant)',
                        items: [
                          for (final prod in _produitsDisponibles)
                            SearchableItem<int?>(
                              value: prod.id,
                              titre: prod.nom,
                              sousTitre: 'Stock : ${prod.stock} ${prod.unite}(s) • Cat : ${prod.categorie}',
                              reference: '${prod.codeBarres} ${prod.categorie}',
                              trailing: Text(
                                fcfa(prod.prixVente),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
                              ),
                              icone: Icons.archive_outlined,
                            ),
                        ],
                        onChanged: (val) => setState(() => _produitParentId = val),
                      ),
                      if (_produitParentId != null) ...[
                        const SizedBox(height: 8),
                        _champ(
                          _facteurConversion,
                          'Nombre d’unités contenues dans 1 carton *',
                          nombre: true,
                          requis: true,
                          hint: 'Ex: 20 paquets par carton',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
      ],
    );
  }
}
