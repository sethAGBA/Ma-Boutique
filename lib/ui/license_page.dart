import 'dart:async';
import 'package:flutter/material.dart';

import '../services/license_service.dart';
import 'helpers.dart';

class EcranLicence extends StatefulWidget {
  const EcranLicence({super.key});

  @override
  State<EcranLicence> createState() => _EcranLicenceState();
}

class _EcranLicenceState extends State<EcranLicence> {
  final _keyController = TextEditingController();
  LicenseStatus? _status;
  bool _loading = true;
  bool _showKey = false;
  bool _inputObscured = true;
  Timer? _revealTimer;
  bool _allConsumed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await LicenseService.instance.getStatus();
    final all = await LicenseService.instance.allKeysUsed();
    if (!mounted) return;
    setState(() {
      _status = st;
      _keyController.text = st.key ?? '';
      _loading = false;
      _allConsumed = all;
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _keyController.dispose();
    super.dispose();
  }

  void _armRevealTimeout() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _showKey = false;
          _inputObscured = true;
        });
      }
    });
  }

  Future<bool> _ensureSupAdmin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF15803D)),
            SizedBox(width: 10),
            Text('Accès SupAdmin requis'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veuillez saisir le mot de passe SupAdmin pour afficher la clé de licence secrète :',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe SupAdmin',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onSubmitted: (_) async {
                final valid = await LicenseService.instance.verifySupAdmin(controller.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop(valid);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final valid = await LicenseService.instance.verifySupAdmin(controller.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop(valid);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (ok == true) return true;
    if (mounted) message(context, 'Mot de passe SupAdmin incorrect', erreur: true);
    return false;
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      message(context, 'Veuillez saisir une clé de licence', erreur: true);
      return;
    }
    try {
      await LicenseService.instance.saveLicense(key: key);
      if (mounted) {
        message(context, '✓ Licence activée avec succès !');
        await _load();
      }
    } catch (e) {
      if (mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  Future<void> _clear() async {
    final st = await LicenseService.instance.getStatus();
    if (!mounted) return;
    final controller = TextEditingController();
    String normalize(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez la clé de licence actuelle pour confirmer. La clé restera marquée comme consommée.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Clé de licence actuelle',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              final input = normalize(controller.text);
              final current = normalize(st.key ?? '');
              if (input.isEmpty || input != current) {
                Navigator.of(ctx).pop(false);
                message(ctx, 'Clé de licence incorrecte', erreur: true);
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    await LicenseService.instance.clearLicense();
    if (mounted) {
      message(context, 'Licence retirée');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de la Licence'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildFormCard(),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Chaque licence standard est valable 12 mois à compter de son activation.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final st = _status;
    final hasKey = st?.hasKey ?? false;
    final isTrial = st?.isTrial ?? true;
    final isActive = st?.isActive ?? false;
    final isExpired = st?.isExpired ?? false;
    final isLifetime = st?.isLifetime ?? false;
    final days = st?.daysRemaining ?? 0;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (hasKey && isActive) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = isLifetime ? 'Licence à vie active' : 'Licence commerciale active ($days jour(s) restants)';
      statusIcon = Icons.check_circle_rounded;
    } else if (isTrial && isActive) {
      statusColor = const Color(0xFF2563EB); // Bleu élégant pour l'essai
      statusLabel = 'Période d’essai gratuite : $days jour(s) restant(s) sur 14';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isTrial && isExpired) {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Période d’essai de 14 jours terminée';
      statusIcon = Icons.timer_off_rounded;
    } else {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Licence expirée — renouvellement requis';
      statusIcon = Icons.error_rounded;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('État de la licence', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clé : ${_formatKeyForDisplay(st?.key ?? '', masked: !_showKey)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: _showKey ? 'Masquer' : 'Afficher (SupAdmin)',
                  onPressed: () async {
                    if (!_showKey) {
                      final ok = await _ensureSupAdmin();
                      if (!ok) return;
                    }
                    setState(() => _showKey = !_showKey);
                    if (_showKey) {
                      _armRevealTimeout();
                    } else {
                      _revealTimer?.cancel();
                    }
                  },
                  icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (st?.registeredAt != null)
              Text(
                'Enregistrée le : ${_formatDate(st!.registeredAt!)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            const SizedBox(height: 4),
            Text(
              'Expiration : ${isLifetime ? 'À vie' : (st?.expiry != null ? _formatDate(st!.expiry!) : '—')}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              'Validité restante : ${isLifetime ? 'Illimitée' : (isActive ? '$days jour(s)' : (isExpired ? '0 jour' : '—'))}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            if (_allConsumed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pack complet de licences consommé — Application débloquée définitivement.',
                        style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activer ou Mettre à jour une clé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Saisissez votre clé de licence commerciale ou de test fournie par l’éditeur.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              obscureText: _inputObscured,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Clé de licence (Ex: XXXX-XXXX-XXXX-XXXX)',
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                suffixIcon: IconButton(
                  tooltip: _inputObscured ? 'Afficher (SupAdmin)' : 'Masquer',
                  icon: Icon(_inputObscured ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () async {
                    if (_inputObscured) {
                      final ok = await _ensureSupAdmin();
                      if (!ok) return;
                    }
                    setState(() => _inputObscured = !_inputObscured);
                    if (!_inputObscured) {
                      _armRevealTimeout();
                    } else {
                      _revealTimer?.cancel();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Activer la licence'),
                ),
                const SizedBox(width: 12),
                if (_status?.hasKey == true)
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    label: const Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatKeyForDisplay(String raw, {required bool masked}) {
    if (raw.isEmpty) return '—';
    final grouped = _groupKey(raw);
    if (!masked) return grouped;
    final parts = grouped.split('-');
    if (parts.length <= 2) {
      if (raw.length <= 6) return '••••••';
      return '${raw.substring(0, 3)}••••••${raw.substring(raw.length - 3)}';
    }
    final first = parts.first;
    final last = parts.last;
    final middle = List.generate(parts.length - 2, (_) => '••••');
    return ([first, ...middle, last]).join('-');
  }

  String _groupKey(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
