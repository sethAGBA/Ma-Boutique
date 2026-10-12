import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'helpers.dart';
import 'searchable_dropdown.dart';

/// Boîte de dialogue moderne permettant d'enregistrer une perte, avarie,
/// produit périmé ou consommation interne avec déduction automatique du stock.
class DeclarerPerteDialog extends StatefulWidget {
  final Produit? produitInitial;

  const DeclarerPerteDialog({super.key, this.produitInitial});

  @override
  State<DeclarerPerteDialog> createState() => _DeclarerPerteDialogState();
}

class _DeclarerPerteDialogState extends State<DeclarerPerteDialog> {
  final _cleForm = GlobalKey<FormState>();
  List<Produit> _produits = [];
  Produit? _produitSelectionne;
  late final TextEditingController _qteCtrl = TextEditingController(text: '1');
  late final TextEditingController _commCtrl = TextEditingController();
  String _motif = 'avarie';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _produitSelectionne = widget.produitInitial;
    _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    final list = await context.read<Repo>().produits();
    if (!mounted) return;
    setState(() {
      _produits = list;
      if (_produitSelectionne != null) {
        final match = list.where((p) => p.id == _produitSelectionne!.id);
        if (match.isNotEmpty) _produitSelectionne = match.first;
      } else if (list.isNotEmpty) {
        _produitSelectionne = list.first;
      }
      _chargement = false;
    });
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    _commCtrl.dispose();
    super.dispose();
  }

  int get _quantite => toInt(_qteCtrl.text);
  int get _coutAchat => (_produitSelectionne != null) ? _quantite * _produitSelectionne!.prixAchat : 0;
  int get _perteVente => (_produitSelectionne != null) ? _quantite * _produitSelectionne!.prixVente : 0;

  Future<void> _valider() async {
    if (!_cleForm.currentState!.validate() || _produitSelectionne == null) return;
    final repo = context.read<Repo>();
    final qte = _quantite;

    try {
      await repo.enregistrerPerte(
        produitId: _produitSelectionne!.id!,
        quantite: qte,
        motif: _motif,
        commentaire: _commCtrl.text.trim(),
        auteur: repo.utilisateurActif?.nom ?? 'Gérant',
      );
      if (mounted) {
        Navigator.pop(context, true);
        message(
          context,
          '✓ Perte de $qte ${_produitSelectionne!.unite}(s) enregistrée (-$qte au stock)',
        );
      }
    } catch (e) {
      if (mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const AlertDialog(
        content: SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Déclarer une Perte / Avarie', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text('Sortie définitive de stock hors-vente', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _cleForm,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sélection du produit avec recherche
                if (widget.produitInitial == null) ...[
                  const Text('Article concerné *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  SearchableDropdown<int>(
                    value: _produitSelectionne?.id,
                    label: 'Choisir un article',
                    hint: 'Rechercher parmi les 300+ articles...',
                    titreDialogue: 'Rechercher un article du stock',
                    prefixIcon: Icons.inventory_2_rounded,
                    items: [
                      for (final p in _produits)
                        SearchableItem<int>(
                          value: p.id!,
                          titre: p.nom,
                          sousTitre: 'Stock : ${p.stock} ${p.unite}(s) • Cat : ${p.categorie}',
                          reference: '${p.codeBarres} ${p.categorie}',
                          trailing: Text(
                            fcfa(p.prixAchat),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
                          ),
                          icone: Icons.inventory_2_outlined,
                        ),
                    ],
                    onChanged: (id) {
                      setState(() {
                        _produitSelectionne = id != null ? _produits.where((p) => p.id == id).firstOrNull : null;
                      });
                    },
                    validator: (v) => v == null ? 'Veuillez sélectionner un article' : null,
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFF334155)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _produitSelectionne!.nom,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Text(
                                'Stock actuel : ${_produitSelectionne!.stock} ${_produitSelectionne!.unite}(s) • Achat : ${fcfa(_produitSelectionne!.prixAchat)}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Motif de la perte
                const Text('Motif de la perte / avarie *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.broken_image_rounded, size: 16),
                      label: const Text('Casse / Avarie'),
                      selected: _motif == 'avarie',
                      onSelected: (s) {
                        if (s) setState(() => _motif = 'avarie');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.event_busy_rounded, size: 16),
                      label: const Text('Produit Périmé'),
                      selected: _motif == 'perime',
                      onSelected: (s) {
                        if (s) setState(() => _motif = 'perime');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.restaurant_rounded, size: 16),
                      label: const Text('Consommation interne'),
                      selected: _motif == 'consommation',
                      onSelected: (s) {
                        if (s) setState(() => _motif = 'consommation');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.report_problem_rounded, size: 16),
                      label: const Text('Vol / Manquant'),
                      selected: _motif == 'vol_manquant',
                      onSelected: (s) {
                        if (s) setState(() => _motif = 'vol_manquant');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                      label: const Text('Autre motif'),
                      selected: _motif == 'autre',
                      onSelected: (s) {
                        if (s) setState(() => _motif = 'autre');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quantité perdue
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qteCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          labelText: 'Quantité perdue *',
                          suffixText: _produitSelectionne?.unite ?? 'unités',
                          prefixIcon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFDC2626)),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = toInt(v ?? '');
                          if (n <= 0) return 'Quantité ≥ 1';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Commentaire / Précisions
                TextFormField(
                  controller: _commCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observations / Justification (facultatif)',
                    hintText: 'Ex: Sac percé par rongeur, boîte cabossée...',
                    prefixIcon: Icon(Icons.comment_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Récapitulatif de l'impact financier
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Coût de revient perdu (prix d’achat) :',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                          ),
                          Text(
                            fcfa(_coutAchat),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Manque à gagner sur vente (prix public) :',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                          ),
                          Text(
                            fcfa(_perteVente),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
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
        FilledButton.icon(
          onPressed: _valider,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: const Text('Valider la perte'),
        ),
      ],
    );
  }
}
