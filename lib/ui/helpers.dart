import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';

final NumberFormat _nf = NumberFormat.decimalPattern('fr_FR');

/// Sauvegarde un fichier (PDF, CSV) de manière robuste sous macOS/Desktop.
/// Tente la boîte de dialogue système si disponible, sinon bascule sur le dossier Documents/Exports_Boutique garanti et révèle le fichier dans le Finder.
Future<String?> exporterFichierRobuste({
  required BuildContext context,
  required String nomFichier,
  required Uint8List bytes,
  String? titreDialogue,
}) async {
  try {
    // 1. Tenter la boîte de dialogue native "Enregistrer sous" (permet de choisir le dossier et nom)
    try {
      final chemin = await FilePicker.platform.saveFile(
        dialogTitle: titreDialogue ?? 'Choisir le dossier de sauvegarde',
        fileName: nomFichier,
        bytes: bytes,
      );
      if (chemin != null) {
        final f = File(chemin);
        if (!await f.exists() || await f.length() == 0) {
          await f.writeAsBytes(bytes);
        }
        if (Platform.isMacOS) {
          await Process.run('open', ['-R', chemin]);
        }
        if (context.mounted) {
          message(context, '✓ Fichier enregistré avec succès :\n$chemin');
        }
        return chemin;
      } else {
        // L'utilisateur a cliqué sur "Annuler"
        if (context.mounted) {
          message(context, 'Exportation annulée.');
        }
        return null;
      }
    } catch (_) {
      // 2. Si saveFile a une restriction, proposer le sélecteur de dossier
      try {
        final dossierChoisi = await FilePicker.platform.getDirectoryPath(
          dialogTitle: titreDialogue ?? 'Choisir le dossier de destination',
        );
        if (dossierChoisi != null) {
          final chemin = pth.join(dossierChoisi, nomFichier);
          final f = File(chemin);
          await f.writeAsBytes(bytes);
          if (Platform.isMacOS) {
            await Process.run('open', ['-R', chemin]);
          }
          if (context.mounted) {
            message(context, '✓ Fichier enregistré avec succès :\n$chemin');
          }
          return chemin;
        } else {
          if (context.mounted) {
            message(context, 'Exportation annulée.');
          }
          return null;
        }
      } catch (_) {}
    }

    // 3. Repli garanti dans Documents/Exports_Boutique
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(pth.join(docsDir.path, 'Exports_Boutique'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(pth.join(exportDir.path, nomFichier));
    await file.writeAsBytes(bytes);

    if (Platform.isMacOS) {
      await Process.run('open', ['-R', file.path]);
    }

    if (context.mounted) {
      message(context, '✓ Fichier exporté avec succès et révélé dans le Finder :\n${file.path}');
    }
    return file.path;
  } catch (e) {
    if (context.mounted) {
      message(context, 'Erreur lors de l’enregistrement : ${texteErreur(e)}', erreur: true);
    }
    return null;
  }
}


/// 12500 -> "12 500 F"
String fcfa(int n) => '${_nf.format(n)} F';

/// Lit un nombre entier saisi par l'utilisateur (accepte les espaces).
int toInt(String s) => int.tryParse(s.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '')) ?? 0;

String texteErreur(Object e) => e.toString().replaceFirst('Exception: ', '');

void message(BuildContext c, String texte, {bool erreur = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Text(
        texte,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: erreur ? Theme.of(c).colorScheme.error : const Color(0xFF1E293B),
    ));
}

Future<bool> confirmer(BuildContext c, String texte, {String oui = 'Confirmer'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text(
        texte,
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(oui)),
      ],
    ),
  );
  return r ?? false;
}

Future<int?> demanderNombre(
  BuildContext c, {
  required String titre,
  required String label,
  int? initial,
}) {
  return showDialog<int>(
    context: c,
    builder: (_) => _NombreDialog(titre: titre, label: label, initial: initial),
  );
}

class _NombreDialog extends StatefulWidget {
  final String titre;
  final String label;
  final int? initial;
  const _NombreDialog({required this.titre, required this.label, this.initial});

  @override
  State<_NombreDialog> createState() => _NombreDialogState();
}

class _NombreDialogState extends State<_NombreDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial == null ? '' : '${widget.initial}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _valider() => Navigator.pop(context, toInt(_c.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: 'F',
        ),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _valider, child: const Text('Valider')),
      ],
    );
  }
}
