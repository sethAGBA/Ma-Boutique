import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../services/license_service.dart';
import 'helpers.dart';
import 'license_page.dart';
import 'ticket_service.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  final _cleForm = GlobalKey<FormState>();
  late final TextEditingController _nomBoutique;
  late final TextEditingController _sousTitre;
  late final TextEditingController _telephone;
  late final TextEditingController _adresse;
  late final TextEditingController _messageTicket;
  late final TextEditingController _devise;
  late final TextEditingController _nif;
  late final TextEditingController _rccm;
  late final TextEditingController _email;

  String _logoPath = '';
  int _largeurTicket = 80;
  bool _ouvrirTiroir = false;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _nomBoutique = TextEditingController();
    _sousTitre = TextEditingController();
    _telephone = TextEditingController();
    _adresse = TextEditingController();
    _messageTicket = TextEditingController();
    _devise = TextEditingController();
    _nif = TextEditingController();
    _rccm = TextEditingController();
    _email = TextEditingController();
    _charger();
  }

  @override
  void dispose() {
    _nomBoutique.dispose();
    _sousTitre.dispose();
    _telephone.dispose();
    _adresse.dispose();
    _messageTicket.dispose();
    _devise.dispose();
    _nif.dispose();
    _rccm.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final repo = context.read<Repo>();
    final p = await repo.chargerParametres();
    if (mounted) {
      setState(() {
        _nomBoutique.text = p.nomBoutique;
        _sousTitre.text = p.sousTitre;
        _telephone.text = p.telephone;
        _adresse.text = p.adresse;
        _messageTicket.text = p.messageTicket;
        _devise.text = p.devise;
        _nif.text = p.nif;
        _rccm.text = p.rccm;
        _email.text = p.email;
        _logoPath = p.logoPath;
        _largeurTicket = p.largeurTicket;
        _ouvrirTiroir = p.ouvrirTiroir;
        _charge = true;
      });
    }
  }

  Future<void> _choisirLogo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        dialogTitle: 'Choisir le logo de la boutique',
      );
      if (res == null || res.files.single.path == null) return;

      final src = File(res.files.single.path!);
      final docs = await getApplicationDocumentsDirectory();
      final ext = pth.extension(src.path).toLowerCase();
      final dest = File(pth.join(docs.path, 'logo_boutique$ext'));
      await src.copy(dest.path);

      setState(() => _logoPath = dest.path);
      await _enregistrerBoutique();
      if (mounted) message(context, '✓ Logo de la boutique enregistré avec succès');
    } catch (e) {
      if (mounted) message(context, 'Erreur lors du choix du logo : ${texteErreur(e)}', erreur: true);
    }
  }

  Future<void> _supprimerLogo() async {
    setState(() => _logoPath = '');
    await _enregistrerBoutique();
    if (mounted) message(context, '✓ Logo retiré');
  }

  Future<void> _enregistrerBoutique() async {
    if (!_cleForm.currentState!.validate()) return;
    final repo = context.read<Repo>();
    final p = ParametresBoutique(
      nomBoutique: _nomBoutique.text.trim(),
      sousTitre: _sousTitre.text.trim(),
      telephone: _telephone.text.trim(),
      adresse: _adresse.text.trim(),
      messageTicket: _messageTicket.text.trim(),
      devise: _devise.text.trim().isEmpty ? 'F CFA' : _devise.text.trim(),
      logoPath: _logoPath,
      largeurTicket: _largeurTicket,
      ouvrirTiroir: _ouvrirTiroir,
      nif: _nif.text.trim(),
      rccm: _rccm.text.trim(),
      email: _email.text.trim(),
    );
    await repo.sauverParametres(p);
    if (mounted) message(context, '✓ Coordonnées et configuration d’impression enregistrées');
  }

  Future<void> _changerPin(Utilisateur user) async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Modifier le code PIN : ${user.nom}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Définissez un nouveau code secret à 6 chiffres pour ${user.nom}.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Nouveau code PIN (6 chiffres)',
                hintText: 'Ex: 123456',
                prefixIcon: Icon(Icons.password_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider')),
        ],
      ),
    );

    if (ok == true && codeCtrl.text.trim().length == 6 && mounted) {
      await context.read<Repo>().changerPin(user.id, codeCtrl.text.trim());
      if (mounted) message(context, '✓ Code PIN de ${user.nom} mis à jour avec succès');
    } else if (ok == true && mounted) {
      message(context, 'Le code PIN doit comporter exactement 6 chiffres', erreur: true);
    }
  }

  Future<void> _rechargerCatalogue(bool ecraser) async {
    final ok = await confirmer(
      context,
      ecraser
          ? 'Cette action va réinitialiser les 300+ articles types du catalogue avec leurs prix d’achat, vente et gros conseillés.\nContinuer ?'
          : 'Ajouter les 300+ articles d’alimentation générale africaine (Riz, Tomates, Laits, Pâtes, Sardines, Savons...) manquants au catalogue actuel ?',
      oui: ecraser ? 'Réinitialiser' : 'Ajouter les articles',
    );
    if (!ok || !mounted) return;

    final repo = context.read<Repo>();
    final ajoutes = await repo.chargerCatalogueAfricain(ecraser: ecraser);
    if (mounted) {
      message(context, '✓ $ajoutes article(s) du catalogue africain traité(s) avec succès !');
    }
  }

  Future<void> _exporterSauvegardeLocale() async {
    final repo = context.read<Repo>();
    final fichier = await repo.sauvegarderMaintenant();
    final bytes = await fichier.readAsBytes();
    if (mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: 'sauvegarde_boutique_${fichier.path.split('/').last}',
        bytes: bytes,
        titreDialogue: 'Choisir le dossier de sauvegarde de la base de données',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();
    final userActif = repo.utilisateurActif;
    final theme = Theme.of(context);

    if (!_charge) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Paramètres & Sécurité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Statut utilisateur et verrouillage
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Chip(
                  avatar: Icon(
                    userActif?.estGerant == true ? Icons.verified_user_rounded : Icons.person_rounded,
                    size: 16,
                    color: userActif?.estGerant == true ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                  label: Text(
                    userActif != null ? '${userActif.nom} (${userActif.role.toUpperCase()})' : 'Non connecté',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  backgroundColor: userActif?.estGerant == true ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.read<Repo>().deconnecter(),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('Verrouiller la session'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Coordonnées de la boutique
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _cleForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.storefront_rounded, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Informations de la Boutique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text('Ces informations figurent sur les tickets et factures imprimés', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Section Logo personnalisé
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: _logoPath.isNotEmpty && File(_logoPath).existsSync()
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Image.file(File(_logoPath), fit: BoxFit.contain),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Image.asset(
                                            'assets/iconmaboutique.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => const Icon(
                                              Icons.storefront_rounded,
                                              size: 32,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _logoPath.isNotEmpty
                                            ? 'Logo personnalisé actif'
                                            : 'Logo officiel « Ma Boutique » (Par défaut)',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _logoPath.isNotEmpty
                                            ? 'Ce logo personnalisé est imprimé en haut de vos tickets et clôtures de caisse.'
                                            : 'Ce logo officiel figure automatiquement sur tous vos reçus et clôtures de caisse.',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          FilledButton.tonalIcon(
                                            onPressed: _choisirLogo,
                                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                                            label: Text(_logoPath.isNotEmpty ? 'Remplacer le logo' : 'Choisir un autre logo'),
                                          ),
                                          if (_logoPath.isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: _supprimerLogo,
                                              icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF15803D)),
                                              label: const Text('Rétablir logo officiel', style: TextStyle(color: Color(0xFF15803D))),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nomBoutique,
                                  decoration: const InputDecoration(labelText: 'Nom de la boutique *'),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _sousTitre,
                                  decoration: const InputDecoration(labelText: 'Sous-titre / Spécialité'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _telephone,
                                  decoration: const InputDecoration(
                                    labelText: 'Numéro Téléphone / WhatsApp',
                                    hintText: 'Ex: +221 77 000 00 00',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _adresse,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse / Emplacement',
                                    hintText: 'Ex: Marché Central, Allée 3',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _messageTicket,
                                  decoration: const InputDecoration(labelText: 'Message de remerciement au pied du ticket / facture'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _devise,
                                  decoration: const InputDecoration(labelText: 'Devise monétaire'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nif,
                                  decoration: const InputDecoration(
                                    labelText: 'NIF (Identifiant Fiscal Togo / OTR)',
                                    hintText: 'Ex: 100012345678',
                                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _rccm,
                                  decoration: const InputDecoration(
                                    labelText: 'RCCM (Registre du Commerce)',
                                    hintText: 'Ex: TG-LOM-2024-B-0123',
                                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email officiel (optionnel)',
                                    hintText: 'contact@boutique.tg',
                                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _enregistrerBoutique,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Enregistrer les coordonnées'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Configuration Imprimante Ticket & Tiroir-Caisse
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.print_rounded, color: Color(0xFF4338CA)),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Imprimante Ticket & Tiroir-Caisse (ESC/POS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text('Compatibilité 58 mm et 80 mm (Xprinter, Epson, Bluetooth/USB)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Format du rouleau :', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment<int>(value: 58, label: Text('58 mm (Compact)'), icon: Icon(Icons.receipt_long_rounded)),
                                ButtonSegment<int>(value: 80, label: Text('80 mm (Standard)'), icon: Icon(Icons.receipt_rounded)),
                              ],
                              selected: {_largeurTicket},
                              onSelectionChanged: (val) {
                                setState(() => _largeurTicket = val.first);
                                _enregistrerBoutique();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ouvrir automatiquement le tiroir-caisse lors d’un encaissement en espèces'),
                          subtitle: const Text('Envoie l’impulsion électrique ESC/POS au tiroir connecté à l’imprimante'),
                          value: _ouvrirTiroir,
                          onChanged: (val) {
                            setState(() => _ouvrirTiroir = val);
                            _enregistrerBoutique();
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => TicketService.ouvrirTiroirCaisse(context),
                              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                              label: const Text('Tester l’ouverture tiroir'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final dummyLignes = [
                                  LigneVente(
                                    produit: const Produit(nom: 'Article de Test', prixVente: 1000),
                                    qte: 1,
                                  ),
                                ];
                                await TicketService.imprimerTicket(
                                  context: context,
                                  venteId: 9999,
                                  lignes: dummyLignes,
                                  total: 1000,
                                  montantPaye: 1000,
                                );
                              },
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('Imprimer un ticket test'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Gestion des utilisateurs & Codes PIN
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.security_rounded, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Comptes & Sécurité (Codes PIN)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text('Connexion sécurisée par code secret à 4 chiffres', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Utilisateur>>(
                          future: repo.utilisateurs(),
                          builder: (context, snapshot) {
                            final users = snapshot.data ?? [];
                            if (users.isEmpty) return const Text('Aucun utilisateur configuré.');
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: users.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final u = users[idx];
                                final estGerant = u.estGerant;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: estGerant ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                    foregroundColor: estGerant ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                    child: Icon(estGerant ? Icons.admin_panel_settings_rounded : Icons.badge_rounded),
                                  ),
                                  title: Text(u.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    estGerant
                                        ? 'Rôle : Gérant (Accès complet à la caisse, stocks, marges et réglages)'
                                        : 'Rôle : Caissier (Accès vente POS et encaissement)',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.key_rounded, size: 16),
                                        label: const Text('Changer code PIN'),
                                        onPressed: () => _changerPin(u),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Codes PIN par défaut : Gérant = 123456  •  Caissier = 000000. '
                                  'Pensez à les personnaliser pour protéger les marges bénéficiaires.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Catalogue Africain Pré-rempli (300+ articles)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_grocery_store_rounded, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Catalogue Alimentation Générale Africaine (300+ Articles)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text('Plus de 300 articles modèles avec prix d’achat, vente détail et prix de gros en F CFA', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Contient tous les essentiels réels : Riz 50kg/25kg/5kg/1kg (Dinor, Thaï, Champion), Tomates (Gino, Salsa, Pommy, boîtes 70g à 2.2kg, sachets), Laits (Bonnet Rouge, Nido, Cowbell, concentré sucré & évaporé), Pâtes & Couscous (Bonita, Garden, Madina, Panzani), Huiles (5L, 1L, 20L, Palme rouge), Sardines (Lucina, Titus), Chocolat Milo (Grand & Petit), Sucres Carreaux, Savons (Le Cygne, Blanco, Medicated, Kira, Flash, Belair), Voltic, Javel, etc.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _rechargerCatalogue(false),
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                              label: const Text('Compléter avec les 300+ articles types'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _rechargerCatalogue(true),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Réinitialiser avec les prix modèles'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Export & Sauvegarde avec choix de dossier
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_zip_rounded, color: Color(0xFF4338CA)),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sauvegarde Complète des Données', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text('Exportez une copie de sécurité vers une clé USB ou un dossier de votre choix', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _exporterSauvegardeLocale,
                          icon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
                          label: const Text('Choisir un dossier et exporter la sauvegarde SQLite'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 5. Gestion de la Licence Logicielle
                FutureBuilder<LicenseStatus>(
                  future: LicenseService.instance.getStatus(),
                  builder: (context, snap) {
                    final st = snap.data;
                    final isActive = st?.isActive ?? false;
                    final isExpired = st?.isExpired ?? false;
                    final isLifetime = st?.isLifetime ?? false;
                    final days = st?.daysRemaining ?? 0;

                    final Color statusColor = isActive
                        ? const Color(0xFF16A34A)
                        : (isExpired ? const Color(0xFFDC2626) : const Color(0xFFEA580C));

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isActive ? Icons.verified_rounded : Icons.vpn_key_rounded,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Licence Commerciale du Logiciel',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        isActive
                                            ? (st?.hasKey == true
                                                ? (isLifetime ? 'Licence à vie active' : 'Licence commerciale active ($days jour(s) restants)')
                                                : 'Essai gratuit : $days jour(s) restant(s) sur 14')
                                            : (st?.hasKey == true
                                                ? 'Licence expirée — renouvellement requis'
                                                : 'Période d’essai de 14 jours terminée'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const EcranLicence()),
                                    );
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                                  label: const Text('Gérer la licence'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
