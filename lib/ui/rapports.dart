import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'declarer_perte_dialog.dart';
import 'facture_service.dart';
import 'helpers.dart';
import 'ticket_service.dart';

enum OngletRapport { activite, inventaire, statistiques, pertes }

class RapportsPage extends StatefulWidget {
  const RapportsPage({super.key});

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  OngletRapport _onglet = OngletRapport.activite;
  String _filtreSi = '';
  String _filtrePeriodePertes = 'mois';
  String _filtreMotifPertes = 'tous';

  Future<(RapportJour, int, List<Produit>, List<Vente>, StatsPertes)> _chargerActivite(Repo repo) async {
    final r = await repo.rapportDuJour();
    final c = await repo.totalCredits();
    final a = await repo.produitsEnAlerte();
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day).toIso8601String();
    final v = await repo.ventes(dateDebut: debutJour, limit: 50);
    final p = await repo.statsPertes(dateDebut: debutJour);
    return (r, c, a, v, p);
  }

  Future<void> _ouvrirCloture(BuildContext context, Repo repo) async {
    final cloture = await repo.clotureDuJour();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF16A34A)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clôture de Caisse (Z)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Date : ${cloture.date}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LIQUIDE RÉEL EN CAISSE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fcfa(cloture.totalLiquideCaisse),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total physique à retrouver dans le tiroir-caisse',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ligneBilan('Chiffre d’affaires ventes', fcfa(cloture.totalVentes), bold: true),
                _ligneBilan('Nombre de ventes', '${cloture.nbVentes}'),
                _ligneBilan('Bénéfice estimé (marge)', fcfa(cloture.benefice), color: const Color(0xFF0F766E)),
                const Divider(height: 16),
                _ligneBilan('Espèces encaissées (ventes)', fcfa(cloture.especesVentes)),
                _ligneBilan('Dettes recouvrées (versements)', '+ ${fcfa(cloture.dettesRecouvrees)}', color: const Color(0xFF16A34A)),
                _ligneBilan('Nouveaux crédits accordés', fcfa(cloture.nouveauxCredits), color: const Color(0xFFD97706)),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => TicketService.imprimerCloture(ctx, cloture),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimer (80mm)'),
          ),
          OutlinedButton.icon(
            onPressed: () => TicketService.telechargerCloturePdf(ctx, cloture),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Télécharger PDF'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  static Widget _ligneBilan(String titre, String valeur, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titre, style: TextStyle(fontSize: 13, color: const Color(0xFF475569), fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(valeur, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Future<void> _exporterSiCsv(BuildContext context, SituationInventaire si) async {
    final sb = StringBuffer();
    sb.writeln('Article;Categorie;Code-barres;Unite;Prix achat;Prix vente;Stock actuel;Valeur achat;Valeur vente;Marge potentielle');
    for (final p in si.produits) {
      final nom = p.nom.replaceAll(';', ',');
      final cat = p.categorie.replaceAll(';', ',');
      final code = p.codeBarres.replaceAll(';', ',');
      final unite = p.unite.replaceAll(';', ',');
      final valAchat = p.stock * p.prixAchat;
      final valVente = p.stock * p.prixVente;
      final marge = p.stock * (p.prixVente - p.prixAchat);
      sb.writeln('$nom;$cat;$code;$unite;${p.prixAchat};${p.prixVente};${p.stock};$valAchat;$valVente;$marge');
    }
    final bytes = Uint8List.fromList(sb.toString().codeUnits);
    final nomFichier = 'situation_inventaire_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    if (context.mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: bytes,
        titreDialogue: 'Enregistrer la Situation d\'Inventaire CSV',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Statistiques'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => _ouvrirCloture(context, repo),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Clôture de Caisse (Z)'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Center(
              child: SegmentedButton<OngletRapport>(
                segments: const [
                  ButtonSegment(
                    value: OngletRapport.activite,
                    icon: Icon(Icons.today_rounded, size: 18),
                    label: Text('Activité du jour'),
                  ),
                  ButtonSegment(
                    value: OngletRapport.inventaire,
                    icon: Icon(Icons.inventory_2_rounded, size: 18),
                    label: Text('Situation d’Inventaire (SI)'),
                  ),
                  ButtonSegment(
                    value: OngletRapport.statistiques,
                    icon: Icon(Icons.analytics_rounded, size: 18),
                    label: Text('Statistiques & Ventes'),
                  ),
                  ButtonSegment(
                    value: OngletRapport.pertes,
                    icon: Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text('Pertes & Avaries'),
                  ),
                ],
                selected: {_onglet},
                onSelectionChanged: (val) => setState(() => _onglet = val.first),
              ),
            ),
          ),
        ),
      ),
      body: switch (_onglet) {
        OngletRapport.activite => _buildVueActivite(context, repo),
        OngletRapport.inventaire => _buildVueInventaire(context, repo),
        OngletRapport.statistiques => _buildVueStatistiques(context, repo),
        OngletRapport.pertes => _buildVuePertes(context, repo),
      },
    );
  }

  // =========================================================================
  // VUE 1 : ACTIVITÉ & CLÔTURE DU JOUR
  // =========================================================================
  Widget _buildVueActivite(BuildContext context, Repo repo) {
    return FutureBuilder<(RapportJour, int, List<Produit>, List<Vente>, StatsPertes)>(
      future: _chargerActivite(repo),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (r, credits, alertes, ventes, pertes) = snap.data!;
        final margeNette = r.benefice - pertes.totalValeurAchat;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Ligne des Métriques Clés
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final cards = [
                  _StatCard(
                    titre: 'Ventes du jour',
                    valeur: fcfa(r.total),
                    detail: '${r.nbVentes} vente(s) enregistrée(s)',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  _StatCard(
                    titre: 'Marge nette réelle',
                    valeur: fcfa(margeNette),
                    detail: pertes.totalValeurAchat > 0
                        ? 'Brut : ${fcfa(r.benefice)} (-${fcfa(pertes.totalValeurAchat)} pertes)'
                        : 'Bénéfice net (0 perte)',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF0F766E),
                    bgColor: const Color(0xFFF0FDFA),
                  ),
                  _StatCard(
                    titre: 'Pertes & Avaries',
                    valeur: fcfa(pertes.totalValeurAchat),
                    detail: pertes.totalPertes > 0 ? '${pertes.totalQuantite} article(s) perdu(s)' : 'Aucune perte déclarée',
                    icon: Icons.delete_sweep_rounded,
                    iconColor: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                  _StatCard(
                    titre: 'Crédits à recouvrer',
                    valeur: fcfa(credits),
                    detail: 'Total dû par vos clients',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      cards[i],
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Stocks en Alerte
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stocks à surveiller',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                if (alertes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${alertes.length} alerte(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (alertes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tous les stocks sont au vert',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              'Aucun produit n’a atteint son seuil d’alerte.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alertes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = alertes[i];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 20),
                      ),
                      title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text('Seuil d’alerte : ${p.seuilAlerte} ${p.unite}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          '${p.stock} ${p.unite}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Historique des Ventes du Jour
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ventes du jour',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${ventes.length} ticket(s)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (ventes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Aucune vente enregistrée pour le moment aujourd’hui.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ventes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final v = ventes[i];
                    DateTime? dt;
                    try {
                      dt = DateTime.parse(v.date);
                    } catch (_) {}
                    final heureStr = dt != null ? DateFormat('HH:mm').format(dt) : '';
                    final isCredit = v.modePaiement == 'credit' || v.resteCredit > 0;

                    return ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCredit ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCredit ? Icons.credit_card_rounded : Icons.receipt_long_rounded,
                          color: isCredit ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Ticket #${v.id}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (heureStr.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('à $heureStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                          if (isCredit && v.clientNom != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Crédit : ${v.clientNom}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        v.lignes.map((l) => '${l.qte}x ${l.produit.nom}').join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      onTap: () {
                        showDialog<void>(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ticket #${v.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Text(fcfa(v.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                              ],
                            ),
                            content: SizedBox(
                              width: 340,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final l in v.lignes)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text('${l.qte}x ${l.produit.nom}')),
                                            Text(fcfa(l.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              FilledButton.tonalIcon(
                                onPressed: () => FactureService.afficherDialogueFacture(
                                  context: dialogCtx,
                                  venteId: v.id,
                                  lignes: v.lignes,
                                  total: v.total,
                                  montantPaye: v.montantPaye,
                                  clientNom: v.clientNom,
                                  modePaiement: v.modePaiement,
                                  dateVente: v.date,
                                ),
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: const Text('Facture A4'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => TicketService.imprimerTicket(
                                  context: dialogCtx,
                                  venteId: v.id,
                                  lignes: v.lignes,
                                  total: v.total,
                                  montantPaye: v.montantPaye,
                                  clientNom: v.clientNom,
                                ),
                                icon: const Icon(Icons.print_rounded, size: 18),
                                label: const Text('Ticket'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => TicketService.telechargerPdf(
                                  context: dialogCtx,
                                  venteId: v.id,
                                  lignes: v.lignes,
                                  total: v.total,
                                  montantPaye: v.montantPaye,
                                  clientNom: v.clientNom,
                                ),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Télécharger PDF'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Fermer'),
                              ),
                            ],
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fcfa(v.total),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Annuler cette vente',
                            icon: const Icon(Icons.undo_rounded, size: 18, color: Color(0xFFDC2626)),
                            onPressed: () async {
                              final ok = await confirmer(
                                ctx,
                                'Annuler le ticket #${v.id} de ${fcfa(v.total)} ?\n'
                                'Les articles seront automatiquement réintégrés en stock.',
                                oui: 'Annuler la vente',
                              );
                              if (ok && ctx.mounted) {
                                await ctx.read<Repo>().annulerVente(v.id);
                                if (ctx.mounted) message(ctx, '✓ Vente #${v.id} annulée (stock restitué)');
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),
            const _SauvegardeCard(),
          ],
        );
      },
    );
  }

  // =========================================================================
  // VUE 2 : SITUATION D'INVENTAIRE (SI) & VALORISATION DU STOCK
  // =========================================================================
  Widget _buildVueInventaire(BuildContext context, Repo repo) {
    return FutureBuilder<SituationInventaire>(
      future: repo.situationInventaire(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final si = snap.data!;

        final filtrerProds = _filtreSi.isEmpty
            ? si.produits
            : si.produits
                .where((p) =>
                    p.nom.toLowerCase().contains(_filtreSi.toLowerCase()) ||
                    p.categorie.toLowerCase().contains(_filtreSi.toLowerCase()) ||
                    p.codeBarres.contains(_filtreSi))
                .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Barre d'actions exports SI
            Card(
              color: const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: Color(0xFF1E293B), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Situation d’Inventaire & Valorisation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('État complet du capital immobilisé en stock et potentiel de marge', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => TicketService.telechargerPdfSituationInventaire(context, si),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('Export PDF (SI)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _exporterSiCsv(context, si),
                          icon: const Icon(Icons.table_chart_rounded, size: 18),
                          label: const Text('Export Excel/CSV'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4 Cartes Métriques Valorisation
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 780;
                final cards = [
                  _StatCard(
                    titre: 'Valeur d’Achat (Capital)',
                    valeur: fcfa(si.valeurAchat),
                    detail: 'Coût total du stock en magasin',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                  _StatCard(
                    titre: 'Valeur de Vente (CA potentiel)',
                    valeur: fcfa(si.valeurVente),
                    detail: 'Chiffre d’affaires si tout est vendu',
                    icon: Icons.price_check_rounded,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  _StatCard(
                    titre: 'Marge Potentielle',
                    valeur: fcfa(si.margeTheorique),
                    detail: 'Bénéfice latent en rayon',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF0F766E),
                    bgColor: const Color(0xFFF0FDFA),
                  ),
                  _StatCard(
                    titre: 'Volume Total en Stock',
                    valeur: '${si.totalArticles} pièces',
                    detail: '${si.nbReferences} références d’articles',
                    icon: Icons.all_inbox_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      cards[i],
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Barre de filtre produit
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un article dans la situation d’inventaire...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filtreSi.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _filtreSi = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _filtreSi = v),
            ),

            const SizedBox(height: 12),

            // Tableau détaillé des articles
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Article', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Catégorie', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Stock actuel', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Prix achat', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Prix vente', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Valeur achat', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Valeur vente', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Marge unitaire', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    for (final p in filtrerProds)
                      DataRow(cells: [
                        DataCell(Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(p.categorie.isEmpty ? 'Général' : p.categorie)),
                        DataCell(Text('${p.stock} ${p.unite}', style: TextStyle(fontWeight: FontWeight.bold, color: p.enAlerte ? const Color(0xFFDC2626) : const Color(0xFF0F172A)))),
                        DataCell(Text(fcfa(p.prixAchat))),
                        DataCell(Text(fcfa(p.prixVente))),
                        DataCell(Text(fcfa(p.stock * p.prixAchat), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))),
                        DataCell(Text(fcfa(p.stock * p.prixVente), style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
                        DataCell(Text(fcfa(p.prixVente - p.prixAchat), style: const TextStyle(color: Color(0xFF0F766E)))),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // VUE 3 : STATISTIQUES & ANALYSES DES VENTES
  // =========================================================================
  Widget _buildVueStatistiques(BuildContext context, Repo repo) {
    return FutureBuilder<(List<StatTopProduit>, List<StatCategorie>, StatGrosDetail)>(
      future: Future.wait([
        repo.topProduitsVendus(limit: 10),
        repo.ventesParCategorie(),
        repo.repartitionGrosDetail(),
      ]).then((res) => (
            res[0] as List<StatTopProduit>,
            res[1] as List<StatCategorie>,
            res[2] as StatGrosDetail,
          )),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (topProds, categories, grosDetail) = snap.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Répartition Gros vs Détail
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: Color(0xFF15803D), size: 24),
                        SizedBox(width: 10),
                        Text('Répartition des Ventes : Détail vs Gros', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('VENTES AU DÉTAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                const SizedBox(height: 4),
                                Text(fcfa(grosDetail.caDetail), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                                Text('${grosDetail.qteDetail} unités vendues', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('VENTES EN GROS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                                const SizedBox(height: 4),
                                Text(fcfa(grosDetail.caGros), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
                                Text('${grosDetail.qteGros} unités vendues (${grosDetail.partGrosPct.toStringAsFixed(1)}% du CA)', style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Top 10 des produits les plus vendus
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.leaderboard_rounded, color: Color(0xFFD97706), size: 24),
                        SizedBox(width: 10),
                        Text('Top 10 des Articles les Plus Vendus', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (topProds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Aucune vente enregistrée pour le moment.', style: TextStyle(color: Color(0xFF64748B)))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topProds.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = topProds[i];
                          return ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i < 3 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: i < 3 ? const Color(0xFFB45309) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(item.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('${item.quantite} unité(s) vendue(s)'),
                            trailing: Text(
                              fcfa(item.chiffreAffaires),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF15803D)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Répartition par Catégories
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.category_rounded, color: Color(0xFF7C3AED), size: 24),
                        SizedBox(width: 10),
                        Text('Chiffre d’Affaires par Catégorie', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Aucune donnée de catégorie disponible.', style: TextStyle(color: Color(0xFF64748B)))),
                      )
                    else
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.categorie, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(fcfa(c.chiffreAffaires), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // VUE 4 : PERTES, AVARIES & PRODUITS PÉRIMÉS
  // =========================================================================
  Widget _buildVuePertes(BuildContext context, Repo repo) {
    DateTime? dateDebut;
    final now = DateTime.now();
    switch (_filtrePeriodePertes) {
      case 'jour':
        dateDebut = DateTime(now.year, now.month, now.day);
      case 'semaine':
        dateDebut = now.subtract(const Duration(days: 7));
      case 'mois':
        dateDebut = DateTime(now.year, now.month, 1);
      case 'tout':
        dateDebut = null;
    }

    final dateDebutIso = dateDebut?.toIso8601String();

    return FutureBuilder<(List<PerteStock>, StatsPertes)>(
      future: Future.wait([
        repo.pertesStock(dateDebut: dateDebutIso, motif: _filtreMotifPertes),
        repo.statsPertes(dateDebut: dateDebutIso),
      ]).then((res) => (
            res[0] as List<PerteStock>,
            res[1] as StatsPertes,
          )),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (pertes, stats) = snap.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Entête et boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pertes, Avaries & Produits Périmés',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Marchandises dépréciées, cassées, périmées ou consommées',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pertes.isEmpty ? null : () => _exporterPertesCsv(pertes),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Exporter CSV'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => const DeclarerPerteDialog(),
                        );
                        if (ok == true && mounted) setState(() {});
                      },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Déclarer une perte'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cartes Synthèse Financière des pertes
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final cards = [
                  _StatCard(
                    titre: 'Coût des Pertes (Achat)',
                    valeur: fcfa(stats.totalValeurAchat),
                    detail: 'Valeur nette déduite du bénéfice',
                    icon: Icons.trending_down_rounded,
                    iconColor: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                  _StatCard(
                    titre: 'Manque à Gagner (Vente)',
                    valeur: fcfa(stats.totalValeurVente),
                    detail: 'Chiffre d’affaires théorique perdu',
                    icon: Icons.money_off_rounded,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                  ),
                  _StatCard(
                    titre: 'Articles Sortis',
                    valeur: '${stats.totalQuantite}',
                    detail: '${stats.totalPertes} déclaration(s) enregistrée(s)',
                    icon: Icons.remove_shopping_cart_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      cards[i],
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Filtres : Période et Motif
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Période :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('Ce mois'),
                              selected: _filtrePeriodePertes == 'mois',
                              onSelected: (s) {
                                if (s) setState(() => _filtrePeriodePertes = 'mois');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('7 derniers jours'),
                              selected: _filtrePeriodePertes == 'semaine',
                              onSelected: (s) {
                                if (s) setState(() => _filtrePeriodePertes = 'semaine');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Aujourd’hui'),
                              selected: _filtrePeriodePertes == 'jour',
                              onSelected: (s) {
                                if (s) setState(() => _filtrePeriodePertes = 'jour');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Toutes'),
                              selected: _filtrePeriodePertes == 'tout',
                              onSelected: (s) {
                                if (s) setState(() => _filtrePeriodePertes = 'tout');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Motif :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('Tous'),
                                  selected: _filtreMotifPertes == 'tous',
                                  onSelected: (s) {
                                    if (s) setState(() => _filtreMotifPertes = 'tous');
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('💥 Casse / Avarie'),
                                  selected: _filtreMotifPertes == 'avarie',
                                  onSelected: (s) {
                                    if (s) setState(() => _filtreMotifPertes = 'avarie');
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('⏳ Périmé'),
                                  selected: _filtreMotifPertes == 'perime',
                                  onSelected: (s) {
                                    if (s) setState(() => _filtreMotifPertes = 'perime');
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('🍴 Consommation interne'),
                                  selected: _filtreMotifPertes == 'consommation',
                                  onSelected: (s) {
                                    if (s) setState(() => _filtreMotifPertes = 'consommation');
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('🚨 Vol / Manquant'),
                                  selected: _filtreMotifPertes == 'vol_manquant',
                                  onSelected: (s) {
                                    if (s) setState(() => _filtreMotifPertes = 'vol_manquant');
                                  },
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
            ),
            const SizedBox(height: 16),

            // Liste des Pertes
            if (pertes.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
                    SizedBox(height: 12),
                    Text(
                      'Aucune perte ou avarie enregistrée sur cette période',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vos marchandises sont intactes et aucun produit périmé n’a été déprécié.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pertes.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = pertes[i];
                    DateTime? d;
                    try {
                      d = DateTime.parse(p.date);
                    } catch (_) {}
                    final dateStr = d != null ? DateFormat('dd/MM/yyyy HH:mm').format(d) : p.date;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: _motifCouleurBg(p.motif),
                        foregroundColor: _motifCouleurTexte(p.motif),
                        child: Icon(_motifIcone(p.motif), size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.produitNom,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '- ${fcfa(p.valeurAchat)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _motifCouleurBg(p.motif),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.motifLibelle,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _motifCouleurTexte(p.motif)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${p.quantite} ${p.produitUnite}(s) • Perte CA : ${fcfa(p.valeurVente)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                              const Spacer(),
                              Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          if (p.commentaire.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Motif : ${p.commentaire}${p.auteur.isNotEmpty ? " (par ${p.auteur})" : ""}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Annuler et réintégrer au stock',
                        onPressed: () async {
                          final ok = await confirmer(
                            context,
                            'Voulez-vous annuler cette perte de ${p.quantite} ${p.produitUnite}(s) et réintégrer la quantité au stock de « ${p.produitNom} » ?',
                            oui: 'Réintégrer',
                          );
                          if (ok && context.mounted) {
                            await repo.annulerPerte(p.id!);
                            if (context.mounted) {
                              message(context, '✓ Perte annulée : +${p.quantite} réintégrée(s) au stock');
                              setState(() {});
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _exporterPertesCsv(List<PerteStock> pertes) async {
    final sb = StringBuffer();
    sb.writeln('Date;Article;Quantité;Unité;Motif;Coût Achat (F CFA);Valeur Vente (F CFA);Auteur;Observations');
    for (final p in pertes) {
      sb.writeln(
        '${p.date};"${p.produitNom.replaceAll('"', '""')}";${p.quantite};"${p.produitUnite}";"${p.motifLibelle}";${p.valeurAchat};${p.valeurVente};"${p.auteur}";"${p.commentaire.replaceAll('"', '""')}"',
      );
    }
    final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
    final nomFichier = 'pertes_avaries_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    await exporterFichierRobuste(
      context: context,
      nomFichier: nomFichier,
      bytes: bytes,
      titreDialogue: 'Exporter le registre des pertes et avaries',
    );
  }

  IconData _motifIcone(String m) {
    switch (m) {
      case 'avarie': return Icons.broken_image_rounded;
      case 'perime': return Icons.event_busy_rounded;
      case 'consommation': return Icons.restaurant_rounded;
      case 'vol_manquant': return Icons.report_problem_rounded;
      default: return Icons.delete_outline_rounded;
    }
  }

  Color _motifCouleurBg(String m) {
    switch (m) {
      case 'avarie': return const Color(0xFFFEF2F2);
      case 'perime': return const Color(0xFFFFF1F2);
      case 'consommation': return const Color(0xFFEFF6FF);
      case 'vol_manquant': return const Color(0xFFFAF5FF);
      default: return const Color(0xFFF1F5F9);
    }
  }

  Color _motifCouleurTexte(String m) {
    switch (m) {
      case 'avarie': return const Color(0xFFDC2626);
      case 'perime': return const Color(0xFFE11D48);
      case 'consommation': return const Color(0xFF2563EB);
      case 'vol_manquant': return const Color(0xFF7C3AED);
      default: return const Color(0xFF475569);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String titre;
  final String valeur;
  final String detail;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.titre,
    required this.valeur,
    required this.detail,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valeur,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SauvegardeCard extends StatelessWidget {
  const _SauvegardeCard();

  Future<void> _sauvegarder(BuildContext context) async {
    final repo = context.read<Repo>();
    try {
      final f = await repo.sauvegarderMaintenant();
      if (!context.mounted) return;
      final partageable = Platform.isAndroid || Platform.isIOS;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 10),
              Text('Sauvegarde réussie'),
            ],
          ),
          content: Text(
            'Fichier local de secours sauvegardé avec succès :\n\n${f.path}\n\n'
            'Vous pouvez copier ce fichier sur une clé USB ou l’envoyer pour garder une copie sécurisée.',
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.drive_folder_upload_rounded),
              onPressed: () async {
                Navigator.pop(ctx);
                final bytes = await f.readAsBytes();
                if (context.mounted) {
                  await exporterFichierRobuste(
                    context: context,
                    nomFichier: f.path.split('/').last,
                    bytes: bytes,
                    titreDialogue: 'Choisir le dossier de sauvegarde',
                  );
                }
              },
              label: const Text('Choisir un dossier…'),
            ),
            if (partageable)
              TextButton.icon(
                icon: const Icon(Icons.share_rounded),
                onPressed: () => Share.shareXFiles([XFile(f.path)]),
                label: const Text('Partager…'),
              ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  Future<void> _restaurer(BuildContext context) async {
    final repo = context.read<Repo>();
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['db']);
    final chemin = r?.files.single.path;
    if (chemin == null || !context.mounted) return;
    final ok = await confirmer(
      context,
      'Attention : cette action va remplacer toutes les données actuelles par celles du fichier sélectionné.\n'
      'Une copie de sécurité des données actuelles sera automatiquement générée avant la restauration.',
      oui: 'Restaurer',
    );
    if (!ok) return;
    try {
      await repo.restaurer(File(chemin));
      if (context.mounted) message(context, '✓ Données restaurées avec succès');
    } catch (e) {
      if (context.mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF16A34A), size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sécurité des données & Sauvegardes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Données stockées 100% sur cet appareil (SQLite)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Une sauvegarde automatique est effectuée chaque jour au démarrage du logiciel. '
              'Pour vous prémunir contre une panne de cet ordinateur ou téléphone, réalisez régulièrement un export vers une clé USB.',
              style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _sauvegarder(context),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Sauvegarder maintenant'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restaurer(context),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Restaurer depuis un fichier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
