import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as pth;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../data/models.dart';
import 'helpers.dart';

class TicketService {
  TicketService._();

  static Future<ParametresBoutique> _recupererParametres() async {
    try {
      final d = await AppDb.instance.db;
      final rows = await d.query('parametres');
      final map = <String, String>{};
      for (final r in rows) {
        map[r['cle'] as String] = r['valeur'] as String;
      }
      return ParametresBoutique(
        nomBoutique: map['nom_boutique'] ?? 'Ma Boutique',
        sousTitre: map['sous_titre'] ?? 'Alimentation Generale',
        telephone: map['telephone'] ?? '',
        adresse: map['adresse'] ?? '',
        messageTicket: map['message_ticket'] ?? 'Merci pour votre confiance !',
        devise: map['devise'] ?? 'F CFA',
        logoPath: map['logo_path'] ?? '',
      );
    } catch (_) {
      return const ParametresBoutique();
    }
  }

  /// Nettoie tous les caractères pour une compatibilité 100% avec les polices thermiques standard (ASCII 32..126).
  /// Évite toute erreur Unicode ou avertissement Helvetica dans dart_pdf.
  static String _propre(String s) {
    var out = s
        // Espaces insécables & typographiques
        .replaceAll(RegExp(r'[\u00A0\u202F\uFEFF\u200B\u1680\u2000-\u200A\u2028\u2029\u205F\u3000]'), ' ')
        // Minuscules accentuées
        .replaceAll(RegExp(r'[éèêëēĕėęě]'), 'e')
        .replaceAll(RegExp(r'[àáâãäåāăą]'), 'a')
        .replaceAll(RegExp(r'[ìíîïĩīĭįı]'), 'i')
        .replaceAll(RegExp(r'[òóôõöøōŏő]'), 'o')
        .replaceAll(RegExp(r'[ùúûüũūŭůűų]'), 'u')
        .replaceAll(RegExp(r'[çćĉċč]'), 'c')
        .replaceAll(RegExp(r'[ñńņň]'), 'n')
        .replaceAll(RegExp(r'[ýÿŷ]'), 'y')
        // Majuscules accentuées
        .replaceAll(RegExp(r'[ÉÈÊËĒĔĖĘĚ]'), 'E')
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅĀĂĄ]'), 'A')
        .replaceAll(RegExp(r'[ÌÍÎÏĨĪĬĮİ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖØŌŎŐ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜŨŪŬŮŰŲ]'), 'U')
        .replaceAll(RegExp(r'[ÇĆĈĊČ]'), 'C')
        .replaceAll(RegExp(r'[ÑŃŅŇ]'), 'N')
        .replaceAll(RegExp(r'[ÝŸŶ]'), 'Y')
        // Ligatures
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE')
        .replaceAll('ß', 'ss')
        // Ponctuations et symboles
        .replaceAll(RegExp(r'[’‘`´]'), "'")
        .replaceAll(RegExp(r'[“”«»„]'), '"')
        .replaceAll(RegExp(r'[–—―]'), '-')
        .replaceAll('…', '...')
        .replaceAll('°', '.')
        .replaceAll('№', 'No.')
        .replaceAll('•', '-')
        .replaceAll('€', 'F');

    // Garde strictement les caractères ASCII imprimables (32 à 126) et sauts de ligne
    return out.replaceAll(RegExp(r'[^\x20-\x7E\n\r]'), '');
  }

  /// Génère le document PDF du ticket de caisse (format rouleau thermique 80 mm).
  /// 100% hors-ligne, sans aucun appel réseau vers des polices distantes.
  static Future<Uint8List> genererPdfTicket({
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    int remise = 0,
    ParametresBoutique? parametres,
  }) async {
    final params = parametres ?? await _recupererParametres();
    Uint8List? logoBytes;
    if (params.logoPath.isNotEmpty && File(params.logoPath).existsSync()) {
      try {
        logoBytes = await File(params.logoPath).readAsBytes();
      } catch (_) {}
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final rendu = montantPaye >= total ? montantPaye - total : 0;
    final resteCredit = total > montantPaye ? total - montantPaye : 0;

    // Données pour le QR Code de vérification
    final qrData = _propre(
      'TICKET #$venteId\n'
      '${params.nomBoutique}\n'
      'DATE: $dateStr\n'
      'TOTAL: ${fcfa(total)}\n'
      'PAYE: ${fcfa(montantPaye)}\n'
      '${clientNom != null && clientNom.isNotEmpty ? "CLIENT: $clientNom\n" : ""}'
      'MERCI',
    );

    // Format rouleau thermique 80 mm x hauteur automatique
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo de la boutique
              if (logoBytes != null)
                pw.Container(
                  height: 44,
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                ),

              // Entête boutique personnalisée
              pw.Text(
                _propre(params.nomBoutique.toUpperCase()),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              if (params.sousTitre.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  _propre(params.sousTitre),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (params.adresse.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  _propre(params.adresse),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (params.telephone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  _propre('Tel: ${params.telephone}'),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                'Ticket N. #$venteId',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
              pw.Text(
                _propre(dateStr),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (clientNom != null && clientNom.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  _propre('Client : $clientNom'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
              ],
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Liste des articles
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Article (Qte)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),

              for (final l in lignes)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          _propre('${l.produit.nom}${l.estGros ? " [Gros]" : ""} (x${l.qte})'),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Text(
                        _propre(fcfa(l.total)),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Récapitulatif
              if (remise > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sous-total :', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(_propre(fcfa(total + remise)), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Remise accordee :', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(_propre('- ${fcfa(remise)}'), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 2),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_propre(fcfa(total)), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Recu :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(montantPaye)), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (rendu > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Monnaie rendue :', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(_propre(fcfa(rendu)), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              if (resteCredit > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reste a credit :', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(_propre(fcfa(resteCredit)), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Code QR sur le reçu
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 50,
                height: 50,
              ),
              pw.SizedBox(height: 4),

              if (params.messageTicket.isNotEmpty)
                pw.Text(
                  _propre(params.messageTicket),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Ouvre la boîte de dialogue d'impression native ou bascule sur Aperçu si le plugin natif attend un redémarrage.
  static Future<void> imprimerTicket({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    int remise = 0,
  }) async {
    try {
      final pdfBytes = await genererPdfTicket(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNom: clientNom,
        remise: remise,
      );

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Ticket_$venteId',
        );
      } catch (e) {
        // Fallback bureau macOS sans passer par le plugin natif :
        if (Platform.isMacOS) {
          final tempDir = await Directory.systemTemp.createTemp('ticket_');
          final tempFile = File(pth.join(tempDir.path, 'ticket_boutique_$venteId.pdf'));
          await tempFile.writeAsBytes(pdfBytes);
          await Process.run('open', [tempFile.path]);
          if (context.mounted) {
            message(context, '✓ Ticket ouvert dans Aperçu (Appuyez sur Cmd+P pour imprimer)');
          }
          return;
        }
        rethrow;
      }
    } catch (e) {
      if (context.mounted) {
        message(
          context,
          'Pour l’impression directe intégrée, relancez « flutter run -d macos » une fois dans le terminal.',
          erreur: true,
        );
      }
    }
  }

  /// Permet à l'utilisateur de choisir le dossier de destination et télécharge le ticket PDF.
  /// Intègre un fallback automatique garanti vers Documents avec révélation dans Finder.
  static Future<void> telechargerPdf({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    int remise = 0,
  }) async {
    final pdfBytes = await genererPdfTicket(
      venteId: venteId,
      lignes: lignes,
      total: total,
      montantPaye: montantPaye,
      clientNom: clientNom,
      remise: remise,
    );
    final nomFichier = 'ticket_boutique_$venteId.pdf';
    if (context.mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: pdfBytes,
        titreDialogue: 'Choisir le dossier où enregistrer le ticket PDF',
      );
    }
  }

  /// Partage le ticket par WhatsApp / message / email.
  /// Partage le ticket par WhatsApp / message / email.
  static Future<void> partagerTicket({
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    int remise = 0,
    ParametresBoutique? parametres,
  }) async {
    final params = parametres ?? await _recupererParametres();
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final sb = StringBuffer();
    sb.writeln('🏪 ${_propre(params.nomBoutique.toUpperCase())}');
    if (params.sousTitre.isNotEmpty) sb.writeln(_propre(params.sousTitre));
    if (params.adresse.isNotEmpty) sb.writeln('Adresse : ${_propre(params.adresse)}');
    if (params.telephone.isNotEmpty) sb.writeln('Tel : ${_propre(params.telephone)}');
    sb.writeln('Ticket de caisse N° #$venteId');
    sb.writeln('Date : $dateStr');
    sb.writeln('--------------------------------');
    for (final l in lignes) {
      sb.writeln('${l.qte}x ${l.produit.nom}${l.estGros ? " [Gros]" : ""} : ${fcfa(l.total)}');
    }
    sb.writeln('--------------------------------');
    if (remise > 0) {
      sb.writeln('Sous-total : ${fcfa(total + remise)}');
      sb.writeln('Remise accordée : -${fcfa(remise)}');
    }
    sb.writeln('TOTAL : ${fcfa(total)}');
    sb.writeln('Montant reçu : ${fcfa(montantPaye)}');
    if (montantPaye >= total) {
      sb.writeln('Monnaie rendue : ${fcfa(montantPaye - total)}');
    } else {
      sb.writeln('Reste à crédit : ${fcfa(total - montantPaye)}');
    }
    sb.writeln('--------------------------------');
    sb.writeln(_propre(params.messageTicket));

    await Share.share(sb.toString(), subject: 'Ticket de caisse #$venteId');
  }

  // ----------------------------------------------------------- Clôture de Caisse

  /// Génère le ticket thermique 80 mm de clôture de caisse de la journée (Z de caisse).
  static Future<Uint8List> genererPdfCloture(ClotureJour cloture, {ParametresBoutique? parametres}) async {
    final params = parametres ?? await _recupererParametres();
    Uint8List? logoBytes;
    if (params.logoPath.isNotEmpty && File(params.logoPath).existsSync()) {
      try {
        logoBytes = await File(params.logoPath).readAsBytes();
      } catch (_) {}
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // QR Code pour la clôture
    final qrCloture = _propre(
      'CLOTURE CAISSE\n'
      '${params.nomBoutique}\n'
      'DATE: ${cloture.date}\n'
      'VENTES: ${cloture.nbVentes}\n'
      'TOTAL: ${fcfa(cloture.totalVentes)}\n'
      'LIQUIDE: ${fcfa(cloture.totalLiquideCaisse)}',
    );

    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              if (logoBytes != null)
                pw.Container(
                  height: 44,
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                ),

              // Entête boutique
              pw.Text(
                _propre(params.nomBoutique.toUpperCase()),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              if (params.adresse.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  _propre(params.adresse),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 3),
              pw.Text(
                'CLOTURE JOURNALIERE (Z)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
              pw.Text(
                'Date : ${cloture.date}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                _propre('Edite le $dateStr'),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Activité
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nombre de ventes :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('${cloture.nbVentes}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Chiffre d affaires :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(cloture.totalVentes)), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Benefice estime :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(cloture.benefice)), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Détail des encaissements
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('DETAIL DES ENCAISSEMENTS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Especes sur ventes :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(cloture.especesVentes)), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Dettes recouvrees :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(cloture.dettesRecouvrees)), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nouveaux credits accordes :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(fcfa(cloture.nouveauxCredits)), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Total en caisse
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('LIQUIDE REEL EN CAISSE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_propre(fcfa(cloture.totalLiquideCaisse)), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Code QR sur la clôture
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrCloture,
                width: 50,
                height: 50,
              ),
              pw.SizedBox(height: 4),
              pw.Text('Arrete de caisse conforme', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Imprime le ticket de clôture du jour sur imprimante thermique ou ouvre Aperçu.
  static Future<void> imprimerCloture(BuildContext context, ClotureJour cloture) async {
    try {
      final pdfBytes = await genererPdfCloture(cloture);
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Cloture_${cloture.date.replaceAll('/', '_')}',
        );
      } catch (_) {
        if (Platform.isMacOS) {
          final tempDir = await Directory.systemTemp.createTemp('cloture_');
          final tempFile = File(pth.join(tempDir.path, 'cloture_${cloture.date.replaceAll('/', '_')}.pdf'));
          await tempFile.writeAsBytes(pdfBytes);
          await Process.run('open', [tempFile.path]);
          if (context.mounted) {
            message(context, '✓ Clôture ouverte dans Aperçu (Appuyez sur Cmd+P pour imprimer)');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        message(context, 'Erreur lors de l’impression : ${texteErreur(e)}', erreur: true);
      }
    }
  }

  /// Télécharge le PDF du ticket de clôture de caisse du jour.
  static Future<void> telechargerCloturePdf(BuildContext context, ClotureJour cloture) async {
    final pdfBytes = await genererPdfCloture(cloture);
    final nomFichier = 'cloture_caisse_${cloture.date.replaceAll('/', '_')}.pdf';
    if (context.mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: pdfBytes,
        titreDialogue: 'Enregistrer la clôture de caisse PDF',
      );
    }
  }

  /// Partage le relevé de compte d'un client par message ou WhatsApp.
  static Future<void> partagerReleveClient({
    required Client client,
    required List<PaiementCredit> paiements,
    ParametresBoutique? parametres,
  }) async {
    final params = parametres ?? await _recupererParametres();
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final sb = StringBuffer();
    sb.writeln('🏪 ${_propre(params.nomBoutique.toUpperCase())} - Relevé de compte client');
    if (params.telephone.isNotEmpty) sb.writeln('Contact : ${_propre(params.telephone)}');
    sb.writeln('Client : ${client.nom}');
    if (client.telephone.isNotEmpty) sb.writeln('Téléphone client : ${client.telephone}');
    sb.writeln('Date : $dateStr');
    sb.writeln('--------------------------------');
    sb.writeln('SOLDE ACTUEL DÛ : ${fcfa(client.soldeCredit)}');
    sb.writeln('--------------------------------');
    if (paiements.isNotEmpty) {
      sb.writeln('Derniers règlements reçus :');
      for (final p in paiements.take(5)) {
        DateTime? dt;
        try {
          dt = DateTime.parse(p.date);
        } catch (_) {}
        final dStr = dt != null ? DateFormat('dd/MM/yyyy').format(dt) : p.date;
        sb.writeln('• $dStr : versement de ${fcfa(p.montant)}');
      }
      sb.writeln('--------------------------------');
    }
    sb.writeln(_propre(params.messageTicket));
    await Share.share(sb.toString(), subject: 'Relevé de compte - ${client.nom}');
  }
}


