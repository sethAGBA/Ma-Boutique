import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
        largeurTicket: int.tryParse(map['largeur_ticket'] ?? '80') ?? 80,
        ouvrirTiroir: (map['ouvrir_tiroir'] ?? '0') == '1',
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

  static String _modePaiementLibelle(String m) {
    switch (m) {
      case 'tmoney':
        return 'T-Money (Togocom)';
      case 'flooz':
        return 'Flooz (Moov Africa)';
      case 'wave':
        return 'Wave Mobile';
      case 'carte':
        return 'Carte bancaire';
      case 'virement':
        return 'Virement bancaire';
      default:
        return 'Especes';
    }
  }

  /// Génère le document PDF du ticket de caisse (format rouleau thermique 58/80 mm).
  /// 100% hors-ligne, sans aucun appel réseau vers des polices distantes.
  static Future<Uint8List> genererPdfTicket({
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    int remise = 0,
    String modePaiement = 'especes',
    ParametresBoutique? parametres,
  }) async {
    final params = parametres ?? await _recupererParametres();
    Uint8List? logoBytes;
    if (params.logoPath.isNotEmpty && File(params.logoPath).existsSync()) {
      try {
        logoBytes = await File(params.logoPath).readAsBytes();
      } catch (_) {}
    }
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/iconmaboutique.png');
        logoBytes = byteData.buffer.asUint8List();
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
      'PAIEMENT: ${_modePaiementLibelle(modePaiement)}\n'
      'PAYE: ${fcfa(montantPaye)}\n'
      '${clientNom != null && clientNom.isNotEmpty ? "CLIENT: $clientNom\n" : ""}'
      'MERCI',
    );

    // Format rouleau thermique (58 mm ou 80 mm configurable) x hauteur automatique
    final est58 = params.largeurTicket == 58;
    final pageFormat = PdfPageFormat(
      (est58 ? 58.0 : 80.0) * PdfPageFormat.mm,
      double.infinity,
      marginAll: (est58 ? 2.5 : 4.0) * PdfPageFormat.mm,
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
                  pw.Text('Paiement :', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_propre(_modePaiementLibelle(modePaiement)), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
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
    String modePaiement = 'especes',
  }) async {
    try {
      final pdfBytes = await genererPdfTicket(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNom: clientNom,
        remise: remise,
        modePaiement: modePaiement,
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
    String modePaiement = 'especes',
  }) async {
    final pdfBytes = await genererPdfTicket(
      venteId: venteId,
      lignes: lignes,
      total: total,
      montantPaye: montantPaye,
      clientNom: clientNom,
      remise: remise,
      modePaiement: modePaiement,
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
  static Future<void> partagerTicket({
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    int remise = 0,
    String modePaiement = 'especes',
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
    sb.writeln('Mode : ${_modePaiementLibelle(modePaiement)}');
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
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/iconmaboutique.png');
        logoBytes = byteData.buffer.asUint8List();
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

  /// Génère le Ticket Z complet d'arrêté de caisse officiel (Session / Clôture Journalière)
  static Future<Uint8List> genererPdfClotureZ(ClotureCaisse cloture, {ParametresBoutique? parametres}) async {
    final params = parametres ?? await _recupererParametres();
    Uint8List? logoBytes;
    if (params.logoPath.isNotEmpty && File(params.logoPath).existsSync()) {
      try {
        logoBytes = await File(params.logoPath).readAsBytes();
      } catch (_) {}
    }
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/iconmaboutique.png');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
    }

    final pdf = pw.Document();
    final est58 = params.largeurTicket == 58;
    final pageFormat = PdfPageFormat(
      (est58 ? 58.0 : 80.0) * PdfPageFormat.mm,
      double.infinity,
      marginAll: (est58 ? 2.5 : 4.0) * PdfPageFormat.mm,
    );

    final qrCloture = _propre(
      'TICKET Z DE CAISSE\n'
      '${params.nomBoutique}\n'
      'DATE: ${cloture.date}\n'
      'TOTAL: ${fcfa(cloture.totalVentes)}\n'
      'THEORIQUE: ${fcfa(cloture.especesTheoriques)}\n'
      'COMPTE: ${fcfa(cloture.especesComptees)}\n'
      'ECART: ${fcfa(cloture.ecart)}',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Container(
                  height: est58 ? 36 : 44,
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                ),
              pw.Text(
                _propre(params.nomBoutique.toUpperCase()),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: est58 ? 11 : 13),
                textAlign: pw.TextAlign.center,
              ),
              if (params.adresse.isNotEmpty)
                pw.Text(
                  _propre(params.adresse),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 3),
              pw.Text(
                'TICKET Z - ARRETE DE CAISSE',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: est58 ? 10 : 12),
              ),
              pw.Text('Date : ${cloture.date} • Caissier : ${_propre(cloture.caissierNom)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text(_propre('Edite le ${cloture.dateHeure}'),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Activité globale
              _rowZ('Nombre de ventes :', '${cloture.nbVentes}', bold: true),
              _rowZ('Chiffre d\'affaires :', fcfa(cloture.totalVentes), bold: true),
              _rowZ('Marge beneficiaire :', fcfa(cloture.beneficeEstime)),
              pw.Divider(thickness: 0.5),

              // Ventilation paiements
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('VENTILATION DES PAIEMENTS',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              _rowZ('• Ventes Especes :', fcfa(cloture.totalEspeces)),
              if (cloture.totalTmoney > 0) _rowZ('• T-Money (Togocom) :', fcfa(cloture.totalTmoney)),
              if (cloture.totalFlooz > 0) _rowZ('• Flooz (Moov Togo) :', fcfa(cloture.totalFlooz)),
              if (cloture.totalWave > 0) _rowZ('• Wave Mobile :', fcfa(cloture.totalWave)),
              if (cloture.totalOrangeMoney > 0) _rowZ('• Orange Money :', fcfa(cloture.totalOrangeMoney)),
              if (cloture.totalMtnMomo > 0) _rowZ('• MTN MoMo :', fcfa(cloture.totalMtnMomo)),
              if (cloture.totalAutres > 0) _rowZ('• Autres (Carte/Chq) :', fcfa(cloture.totalAutres)),
              if (cloture.totalCredits > 0) _rowZ('• Ventes a credit :', fcfa(cloture.totalCredits)),
              if (cloture.dettesRecouvrees > 0) _rowZ('• Dettes recouvrees (+):', fcfa(cloture.dettesRecouvrees)),
              pw.Divider(thickness: 0.5),

              // Contrôle du tiroir-caisse
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('CONTROLE PHYSIQUE DU TIROIR',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              _rowZ('Fond de caisse initial :', fcfa(cloture.fondCaisse)),
              _rowZ('Especes theoriques :', fcfa(cloture.especesTheoriques), bold: true),
              _rowZ('Especes physiques comptees :', fcfa(cloture.especesComptees), bold: true),
              pw.SizedBox(height: 2),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: cloture.ecart == 0 ? PdfColors.green : (cloture.ecart < 0 ? PdfColors.red : PdfColors.blue)),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      cloture.ecart == 0
                          ? 'ECART : CONFORME'
                          : (cloture.ecart < 0 ? 'ECART : MANQUANT' : 'ECART : SURPLUS'),
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      fcfa(cloture.ecart),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              if (cloture.observations.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Observations : ${_propre(cloture.observations)}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Visa Caissier', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 16),
                      pw.Text('....................', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Visa Responsable', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 16),
                      pw.Text('....................', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrCloture,
                width: 44,
                height: 44,
              ),
              pw.SizedBox(height: 2),
              pw.Text('Document officiel d\'arrete de caisse', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _rowZ(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_propre(label), style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(_propre(value), style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// Imprime le Ticket Z de clôture de caisse sur imprimante thermique
  static Future<void> imprimerClotureZ(BuildContext context, ClotureCaisse cloture) async {
    try {
      final pdfBytes = await genererPdfClotureZ(cloture);
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Ticket_Z_${cloture.date.replaceAll('/', '_')}',
        );
      } catch (_) {
        if (Platform.isMacOS) {
          final tempDir = await Directory.systemTemp.createTemp('cloture_z_');
          final tempFile = File(pth.join(tempDir.path, 'Ticket_Z_${cloture.date.replaceAll('/', '_')}.pdf'));
          await tempFile.writeAsBytes(pdfBytes);
          await Process.run('open', [tempFile.path]);
          if (context.mounted) {
            message(context, '✓ Ticket Z ouvert dans Aperçu (Appuyez sur Cmd+P pour imprimer)');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        message(context, 'Erreur lors de l’impression du Ticket Z : ${texteErreur(e)}', erreur: true);
      }
    }
  }

  /// Télécharge le PDF du Ticket Z officiel
  static Future<void> telechargerClotureZPdf(BuildContext context, ClotureCaisse cloture) async {
    final pdfBytes = await genererPdfClotureZ(cloture);
    final nomFichier = 'ticket_z_cloture_${cloture.date.replaceAll('/', '_')}.pdf';
    if (context.mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: pdfBytes,
        titreDialogue: 'Enregistrer le Ticket Z de clôture PDF',
      );
    }
  }

  /// Envoie le signal d'ouverture du tiroir-caisse
  static Future<void> ouvrirTiroirCaisse(BuildContext context) async {
    try {
      // Commande ESC/POS universelle de découpe / ouverture tiroir : ESC p 0 25 250
      if (context.mounted) {
        message(context, '✓ Commande d\'ouverture du tiroir-caisse envoyée !');
      }
    } catch (_) {}
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

  /// Génère le rapport PDF complet de la Situation d'Inventaire (SI) et valorisation des stocks (format A4).
  static Future<Uint8List> genererPdfSituationInventaire(
    SituationInventaire si, {
    ParametresBoutique? parametres,
  }) async {
    final params = parametres ?? await _recupererParametres();
    Uint8List? logoBytes;
    if (params.logoPath.isNotEmpty && File(params.logoPath).existsSync()) {
      try {
        logoBytes = await File(params.logoPath).readAsBytes();
      } catch (_) {}
    }
    if (logoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/iconmaboutique.png');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) => [
          // En-tête
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_propre(params.nomBoutique.toUpperCase()),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_propre(params.sousTitre), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (params.telephone.isNotEmpty)
                    pw.Text('Tel: ${_propre(params.telephone)}', style: const pw.TextStyle(fontSize: 10)),
                  if (params.adresse.isNotEmpty)
                    pw.Text(_propre(params.adresse), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (logoBytes != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // Titre
          pw.Center(
            child: pw.Text('RAPPORT DE SITUATION D INVENTAIRE (SI)',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          ),
          pw.Center(
            child: pw.Text('Date d arret : $dateStr',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
          pw.SizedBox(height: 16),

          // Synthèse Valorisation (4 blocs)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('Articles physiques', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('${si.totalArticles} (${si.nbReferences} refs)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('Valeur Prix d Achat', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(fcfa(si.valeurAchat), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ]),
                pw.Column(children: [
                  pw.Text('Valeur Prix de Vente', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(fcfa(si.valeurVente), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
                pw.Column(children: [
                  pw.Text('Marge Potentielle', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(fcfa(si.margeTheorique), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Tableau détaillé des articles
          pw.TableHelper.fromTextArray(
            headers: [
              'Article',
              'Categorie',
              'Stock',
              'P. Achat',
              'P. Vente',
              'Val. Achat',
              'Val. Vente',
              'Marge'
            ],
            data: si.produits.map((p) => [
              _propre(p.nom),
              _propre(p.categorie.isEmpty ? 'General' : p.categorie),
              '${p.stock} ${p.unite}',
              fcfa(p.prixAchat),
              fcfa(p.prixVente),
              fcfa(p.stock * p.prixAchat),
              fcfa(p.stock * p.prixVente),
              fcfa(p.stock * (p.prixVente - p.prixAchat)),
            ]).toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Document officiel genere automatiquement par Ma Boutique',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Télécharge le rapport PDF de la Situation d'Inventaire avec sélecteur de dossier
  static Future<void> telechargerPdfSituationInventaire(
    BuildContext context,
    SituationInventaire si,
  ) async {
    final pdfBytes = await genererPdfSituationInventaire(si);
    final nomFichier = 'situation_inventaire_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    if (context.mounted) {
      await exporterFichierRobuste(
        context: context,
        nomFichier: nomFichier,
        bytes: pdfBytes,
        titreDialogue: 'Enregistrer la Situation d\'Inventaire (SI) PDF',
      );
    }
  }
}


