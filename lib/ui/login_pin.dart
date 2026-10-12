import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repo.dart';
import 'helpers.dart';

/// Écran de connexion obligatoire par code PIN à chaque ouverture de l'application.
class EcranConnexionPin extends StatefulWidget {
  const EcranConnexionPin({super.key});

  @override
  State<EcranConnexionPin> createState() => _EcranConnexionPinState();
}

class _EcranConnexionPinState extends State<EcranConnexionPin> {
  String _pin = '';
  String? _erreur;
  bool _enCours = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _ajouterChiffre(String c) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += c;
      _erreur = null;
    });
    if (_pin.length == 6) {
      _validerAutomatique();
    }
  }

  void _effacer() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _erreur = null;
    });
  }

  void _vider() {
    setState(() {
      _pin = '';
      _erreur = null;
    });
  }

  Future<void> _validerAutomatique() async {
    // Laisse une demi-seconde pour le feedback visuel du dernier point
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) _soumettre();
  }

  Future<void> _soumettre() async {
    if (_pin.length != 6 || _enCours) return;
    setState(() => _enCours = true);

    try {
      final repo = context.read<Repo>();
      final u = await repo.authentifierPin(_pin);
      if (!mounted) return;

      if (u == null) {
        setState(() {
          _erreur = 'Code PIN incorrect';
          _pin = '';
          _enCours = false;
        });
      } else {
        message(context, '✓ Bienvenue, ${u.nom} (${u.role.toUpperCase()})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = texteErreur(e);
          _enCours = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fond sombre & élégant POS
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          final key = event.character;
          if (key != null && RegExp(r'^[0-9]$').hasMatch(key)) {
            _ajouterChiffre(key);
          } else if (event.logicalKey.keyLabel == 'Backspace') {
            _effacer();
          } else if (event.logicalKey.keyLabel == 'Enter') {
            _soumettre();
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 12,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo officiel de la boutique
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/iconmaboutique.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFF15803D),
                              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'MA BOUTIQUE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Alimentation Générale • Vente en Gros & Détail',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),

                      // Indicateur visuel des points PIN (6 chiffres)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          final rempli = i < _pin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rempli ? const Color(0xFF15803D) : const Color(0xFFE2E8F0),
                              border: Border.all(
                                color: rempli ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),

                      if (_erreur != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _erreur!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Pavé numérique tactile & clavier
                      Column(
                        children: [
                          for (final ligne in [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final digit in ligne)
                                    _boutonChiffre(digit),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _boutonAction(Icons.clear_all_rounded, 'C', _vider),
                              _boutonChiffre('0'),
                              _boutonAction(Icons.backspace_outlined, '⌫', _effacer),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Bouton Déverrouiller
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _pin.length == 6 && !_enCours ? _soumettre : null,
                          icon: _enCours
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_open_rounded, size: 20),
                          label: Text(_enCours ? 'Vérification...' : 'Déverrouiller'),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Aide pour les codes par défaut
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Connexion sécurisée par PIN obligatoire',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gérant : 123456  •  Caissier : 000000',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boutonChiffre(String ch) {
    return SizedBox(
      width: 76,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          backgroundColor: const Color(0xFFF8FAFC),
        ),
        onPressed: () => _ajouterChiffre(ch),
        child: Text(
          ch,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _boutonAction(IconData icon, String tooltip, VoidCallback action) {
    return SizedBox(
      width: 76,
      height: 56,
      child: IconButton(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFFF1F5F9),
        ),
        icon: Icon(icon, color: const Color(0xFF475569), size: 22),
        tooltip: tooltip,
        onPressed: action,
      ),
    );
  }
}
