import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'helpers.dart';
import 'ticket_service.dart';

class RapportsPage extends StatelessWidget {
  const RapportsPage({super.key});

  Future<(RapportJour, int, List<Produit>, List<Vente>)> _charger(Repo repo) async {
    final r = await repo.rapportDuJour();
    final c = await repo.totalCredits();
    final a = await repo.produitsEnAlerte();
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day).toIso8601String();
    final v = await repo.ventes(dateDebut: debutJour, limit: 50);
    return (r, c, a, v);
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
                // Encadré Total Encaissé
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

                // Détails des chiffres
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
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => TicketService.imprimerCloture(ctx, cloture),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Imprimer'),
              ),
              OutlinedButton.icon(
                onPressed: () => TicketService.telechargerCloturePdf(ctx, cloture),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Télécharger PDF'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Activité'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => _ouvrirCloture(context, repo),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Clôture du jour'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<(RapportJour, int, List<Produit>, List<Vente>)>(
        future: _charger(repo),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (r, credits, alertes, ventes) = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Ligne des Métriques Clés
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatCard(
                            titre: 'Ventes du jour',
                            valeur: fcfa(r.total),
                            detail: '${r.nbVentes} vente(s) enregistrée(s)',
                            icon: Icons.payments_rounded,
                            iconColor: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFF0FDF4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            titre: 'Bénéfice estimé',
                            valeur: fcfa(r.benefice),
                            detail: 'Prix de vente − Prix d’achat',
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF0F766E),
                            bgColor: const Color(0xFFF0FDFA),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            titre: 'Crédits à recouvrer',
                            valeur: fcfa(credits),
                            detail: 'Total dû par vos clients',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFFFBEB),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _StatCard(
                        titre: 'Ventes du jour',
                        valeur: fcfa(r.total),
                        detail: '${r.nbVentes} vente(s) enregistrée(s)',
                        icon: Icons.payments_rounded,
                        iconColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFF0FDF4),
                      ),
                      const SizedBox(height: 10),
                      _StatCard(
                        titre: 'Bénéfice estimé',
                        valeur: fcfa(r.benefice),
                        detail: 'Prix de vente − Prix d’achat',
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFF0F766E),
                        bgColor: const Color(0xFFF0FDFA),
                      ),
                      const SizedBox(height: 10),
                      _StatCard(
                        titre: 'Crédits à recouvrer',
                        valeur: fcfa(credits),
                        detail: 'Total dû par vos clients',
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Section Stocks en Alerte
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

              // Section Historique des Ventes du Jour
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
                              Text(
                                'à $heureStr',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
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
                                  label: const Text('Imprimer'),
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

              // Section Sauvegarde & Données locales
              const _SauvegardeCard(),
            ],
          );
        },
      ),
    );
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
                fontSize: 24,
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
