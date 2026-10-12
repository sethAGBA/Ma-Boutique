import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'helpers.dart';
import 'ticket_service.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String _q = '';
  bool _uniquementDettes = false;

  Future<void> _nouveau(BuildContext context) async {
    final repo = context.read<Repo>();
    final c = await showDialog<Client>(context: context, builder: (_) => const _ClientForm());
    if (c != null) {
      await repo.sauverClient(c);
      if (context.mounted) message(context, '✓ Client « ${c.nom} » enregistré');
    }
  }

  Future<void> _paiement(BuildContext context, Client c) async {
    final repo = context.read<Repo>();
    final n = await demanderNombre(
      context,
      titre: 'Règlement de dette : ${c.nom}',
      label: 'Montant versé (F)',
      initial: c.soldeCredit,
    );
    if (n != null && n > 0) {
      await repo.enregistrerPaiement(c.id!, n);
      if (context.mounted) message(context, '✓ Paiement de ${fcfa(n)} enregistré pour ${c.nom}');
    }
  }

  Future<void> _ouvrirFicheClient(BuildContext context, Client c) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FicheClientDialog(client: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Crédits'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _nouveau(context),
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text('Nouveau client'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête : Total des dettes clients à recouvrer
          FutureBuilder<int>(
            future: repo.totalCredits(),
            builder: (context, snap) {
              final totalCredits = snap.data ?? 0;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCA5A5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DES CRÉDITS EN ATTENTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fcfa(totalCredits),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilterChip(
                      selected: _uniquementDettes,
                      label: const Text('Avec arriéré'),
                      avatar: const Icon(Icons.filter_list_rounded, size: 16),
                      onSelected: (v) => setState(() => _uniquementDettes = v),
                      showCheckmark: false,
                    ),
                  ],
                ),
              );
            },
          ),

          // Barre de recherche client
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un client par nom ou téléphone...',
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

          const SizedBox(height: 6),

          // Liste des clients
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: repo.clients(q: _q),
              builder: (context, snap) {
                var liste = snap.data ?? const <Client>[];
                if (_uniquementDettes) {
                  liste = liste.where((c) => c.soldeCredit > 0).toList();
                }

                if (liste.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 54, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            _uniquementDettes
                                ? 'Aucun client avec une dette en cours !'
                                : (_q.isEmpty ? 'Aucun client enregistré.' : 'Aucun client ne correspond à « $_q ».'),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          if (_q.isEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () => _nouveau(context),
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Ajouter un client'),
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
                    final c = liste[i];
                    final aUneDette = c.soldeCredit > 0;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _ouvrirFicheClient(context, c),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: aUneDette ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    c.nom.isNotEmpty ? c.nom[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: aUneDette ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Nom et Téléphone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.nom,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.telephone.isEmpty ? 'Toucher pour voir l’historique' : c.telephone,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),

                              // Statut crédit / Dette
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: aUneDette ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: aUneDette ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      aUneDette ? 'Doit ${fcfa(c.soldeCredit)}' : 'À jour',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: aUneDette ? const Color(0xFFDC2626) : const Color(0xFF166534),
                                      ),
                                    ),
                                    Text(
                                      aUneDette ? 'Crédit en cours' : 'Solde 0 F',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: aUneDette ? const Color(0xFFDC2626) : const Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Action paiement
                              if (aUneDette)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    backgroundColor: theme.colorScheme.primary,
                                  ),
                                  icon: const Icon(Icons.payments_rounded, size: 16),
                                  label: const Text('Régler', style: TextStyle(fontSize: 13)),
                                  onPressed: () => _paiement(context, c),
                                )
                              else
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FicheClientDialog extends StatelessWidget {
  final Client client;
  const _FicheClientDialog({required this.client});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final theme = Theme.of(context);
    final aUneDette = client.soldeCredit > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: aUneDette ? const Color(0xFFFEE2E2) : theme.colorScheme.primaryContainer,
            child: Text(
              client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: aUneDette ? const Color(0xFFDC2626) : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                if (client.telephone.isNotEmpty)
                  Text(client.telephone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
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
              // Solde actuel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: aUneDette ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: aUneDette ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      aUneDette ? 'Dette actuelle :' : 'Statut :',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: aUneDette ? const Color(0xFF991B1B) : const Color(0xFF166534),
                      ),
                    ),
                    Text(
                      aUneDette ? fcfa(client.soldeCredit) : 'À jour (0 F)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: aUneDette ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Historique des règlements / paiements',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 6),

              FutureBuilder<List<PaiementCredit>>(
                future: repo.paiementsClient(client.id!),
                builder: (context, snap) {
                  final paiements = snap.data ?? const <PaiementCredit>[];
                  if (paiements.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Aucun paiement antérieur enregistré.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paiements.take(10).length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = paiements[i];
                        DateTime? dt;
                        try {
                          dt = DateTime.parse(p.date);
                        } catch (_) {}
                        final dateStr = dt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(dt) : p.date;

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 18),
                          title: Text('Versement de ${fcfa(p.montant)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(dateStr, style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Partager le relevé'),
          onPressed: () async {
            final paiements = await repo.paiementsClient(client.id!);
            await TicketService.partagerReleveClient(
              client: client,
              paiements: paiements,
            );
          },
        ),
        if (aUneDette)
          FilledButton.icon(
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('Enregistrer un versement'),
            onPressed: () async {
              Navigator.pop(context);
              final n = await demanderNombre(
                context,
                titre: 'Règlement de dette : ${client.nom}',
                label: 'Montant versé (F)',
                initial: client.soldeCredit,
              );
              if (n != null && n > 0 && context.mounted) {
                await repo.enregistrerPaiement(client.id!, n);
                if (context.mounted) message(context, '✓ Paiement de ${fcfa(n)} enregistré');
              }
            },
          ),
      ],
    );
  }
}

class _ClientForm extends StatefulWidget {
  const _ClientForm();

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  bool _erreur = false;

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    super.dispose();
  }

  void _enregistrer() {
    if (_nom.text.trim().isEmpty) {
      setState(() => _erreur = true);
      return;
    }
    Navigator.pop(context, Client(nom: _nom.text.trim(), telephone: _tel.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau client', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nom,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nom complet du client *',
                hintText: 'Ex: M. Koffi, Mme Adjoa...',
                prefixIcon: const Icon(Icons.person_rounded),
                errorText: _erreur ? 'Veuillez renseigner le nom' : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone (facultatif)',
                hintText: 'Ex: 90 00 00 00',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              onSubmitted: (_) => _enregistrer(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
      ],
    );
  }
}
