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

/// Service officiel de génération, impression et partage des Factures commerciales et Proforma au format standard A4.
class FactureService {
  FactureService._();

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
        sousTitre: map['sous_titre'] ?? 'Alimentation Générale',
        telephone: map['telephone'] ?? '',
        adresse: map['adresse'] ?? 'Lomé, Togo',
        messageTicket: map['message_ticket'] ?? 'Merci de votre confiance !',
        devise: map['devise'] ?? 'F CFA',
        logoPath: map['logo_path'] ?? '',
        largeurTicket: int.tryParse(map['largeur_ticket'] ?? '80') ?? 80,
        ouvrirTiroir: (map['ouvrir_tiroir'] ?? '0') == '1',
        nif: map['nif'] ?? '',
        rccm: map['rccm'] ?? '',
        email: map['email'] ?? '',
      );
    } catch (_) {
      return const ParametresBoutique();
    }
  }

  /// Nettoie tous les caractères pour une compatibilité 100% avec les polices standards Helvetica de PDF.
  static String _propre(String s) {
    var out = s
        .replaceAll(RegExp(r'[\u00A0\u202F\uFEFF\u200B\u1680\u2000-\u200A\u2028\u2029\u205F\u3000]'), ' ')
        .replaceAll(RegExp(r'[éèêëēĕėęě]'), 'e')
        .replaceAll(RegExp(r'[àáâãäåāăą]'), 'a')
        .replaceAll(RegExp(r'[ìíîïĩīĭįı]'), 'i')
        .replaceAll(RegExp(r'[òóôõöøōŏő]'), 'o')
        .replaceAll(RegExp(r'[ùúûüũūŭůűų]'), 'u')
        .replaceAll(RegExp(r'[çćĉċč]'), 'c')
        .replaceAll(RegExp(r'[ñńņň]'), 'n')
        .replaceAll(RegExp(r'[ýÿŷ]'), 'y')
        .replaceAll(RegExp(r'[ÉÈÊËĒĔĖĘĚ]'), 'E')
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅĀĂĄ]'), 'A')
        .replaceAll(RegExp(r'[ÌÍÎÏĨĪĬĮİ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖØŌŎŐ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜŨŪŬŮŰŲ]'), 'U')
        .replaceAll(RegExp(r'[ÇĆĈĊČ]'), 'C')
        .replaceAll(RegExp(r'[ÑŃŅŇ]'), 'N')
        .replaceAll(RegExp(r'[ÝŸŶ]'), 'Y')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[’‘`´]'), "'")
        .replaceAll(RegExp(r'[“”«»„]'), '"')
        .replaceAll(RegExp(r'[–—―]'), '-')
        .replaceAll('…', '...')
        .replaceAll('°', '.')
        .replaceAll('№', 'No.')
        .replaceAll('•', '-')
        .replaceAll('€', 'F');

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
      case 'cheque':
        return 'Chèque bancaire';
      case 'credit':
        return 'Vente à Crédit';
      default:
        return 'Espèces (Comptant)';
    }
  }

  /// Génère le document PDF de la Facture au format A4 haute fidélité.
  static Future<Uint8List> genererPdfFactureA4({
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    String? clientTelephone,
    String? clientAdresse,
    int remise = 0,
    String modePaiement = 'especes',
    String? dateVente,
    String? caissierNom,
    bool estProforma = false,
    String? observations,
    ParametresBoutique? parametresBoutique,
  }) async {
    final params = parametresBoutique ?? await _recupererParametres();
    final doc = pw.Document();

    DateTime dt;
    try {
      dt = dateVente != null ? DateTime.parse(dateVente) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    final refFacture = '${estProforma ? "PROF" : "FACT"}-${DateFormat('yyyyMMdd').format(dt)}-${venteId.toString().padLeft(4, '0')}';

    final totalNet = total;
    final sousTotalBrut = totalNet + remise;
    final resteCredit = totalNet > montantPaye ? totalNet - montantPaye : 0;
    final rendu = montantPaye > totalNet ? montantPaye - totalNet : 0;

    // Tentative de chargement du logo de la boutique
    pw.MemoryImage? logoImage;
    if (params.logoPath.isNotEmpty) {
      final f = File(params.logoPath);
      if (f.existsSync()) {
        try {
          logoImage = pw.MemoryImage(f.readAsBytesSync());
        } catch (_) {}
      }
    }

    final montantLettres = nombreEnLettres(totalNet);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // =======================================================
              // EN-TÊTE : LOGO + INFOS BOUTIQUE + BLOC FACTURE
              // =======================================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Colonne Boutique
                  pw.Expanded(
                    flex: 6,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 60,
                            height: 60,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 50,
                            height: 50,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green700,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              params.nomBoutique.isNotEmpty ? params.nomBoutique[0].toUpperCase() : 'B',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                _propre(params.nomBoutique.toUpperCase()),
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey900,
                                ),
                              ),
                              if (params.sousTitre.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _propre(params.sousTitre),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                                ),
                              ],
                              if (params.adresse.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _propre(params.adresse),
                                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                ),
                              ],
                              if (params.telephone.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  _propre('Tel: ${params.telephone}'),
                                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                ),
                              ],
                              if (params.nif.isNotEmpty || params.rccm.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _propre('${params.nif.isNotEmpty ? "NIF: ${params.nif}" : ""}${params.nif.isNotEmpty && params.rccm.isNotEmpty ? " • " : ""}${params.rccm.isNotEmpty ? "RCCM: ${params.rccm}" : ""}'),
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                                ),
                              ],
                              if (params.email.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  _propre('Email: ${params.email}'),
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Colonne Numéro et Date
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: estProforma ? PdfColors.blue50 : PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(
                          color: estProforma ? PdfColors.blue300 : PdfColors.grey300,
                          width: 1,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            estProforma ? 'FACTURE PROFORMA' : 'FACTURE DE VENTE',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: estProforma ? PdfColors.blue800 : PdfColors.green900,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            refFacture,
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _propre('Date : $dateStr'),
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                          if (caissierNom != null && caissierNom.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _propre('Emis par : $caissierNom'),
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ],
                          pw.SizedBox(height: 4),
                          // Badge état de paiement
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: estProforma
                                  ? PdfColors.blue200
                                  : (resteCredit > 0
                                      ? (montantPaye == 0 ? PdfColors.red100 : PdfColors.amber100)
                                      : PdfColors.green100),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              estProforma
                                  ? 'DEVIS / NON PAYE'
                                  : (resteCredit > 0
                                      ? (montantPaye == 0 ? 'A CREDIT' : 'ACOMPTE VERSE')
                                      : 'PAYE COMPTANT'),
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: estProforma
                                    ? PdfColors.blue900
                                    : (resteCredit > 0
                                        ? (montantPaye == 0 ? PdfColors.red800 : PdfColors.amber900)
                                        : PdfColors.green800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // =======================================================
              // BLOC INFORMATIONS CLIENT
              // =======================================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FACTURE A :',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _propre(clientNom != null && clientNom.isNotEmpty ? clientNom : 'Client au comptant'),
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                          ),
                          if (clientTelephone != null && clientTelephone.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _propre('Tel : $clientTelephone'),
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                          ],
                          if (clientAdresse != null && clientAdresse.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _propre('Adresse : $clientAdresse'),
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'REGLEMENT :',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _modePaiementLibelle(modePaiement),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Devise : ${params.devise}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // =======================================================
              // TABLEAU DES ARTICLES / LIGNES DE VENTE
              // =======================================================
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(26), // N°
                  1: pw.FlexColumnWidth(5),  // Désignation
                  2: pw.FlexColumnWidth(1.8), // Conditionnement
                  3: pw.FixedColumnWidth(42), // Qté
                  4: pw.FlexColumnWidth(2.2), // P.U.
                  5: pw.FlexColumnWidth(2.5), // Total
                },
                children: [
                  // En-tête du tableau
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th('#', align: pw.TextAlign.center),
                      _th('DESIGNATION DE L’ARTICLE'),
                      _th('UNITE', align: pw.TextAlign.center),
                      _th('QTE', align: pw.TextAlign.center),
                      _th('P.U. (F CFA)', align: pw.TextAlign.right),
                      _th('TOTAL (F CFA)', align: pw.TextAlign.right),
                    ],
                  ),
                  // Lignes des articles
                  for (int i = 0; i < lignes.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i % 2 == 1 ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        _td('${i + 1}', align: pw.TextAlign.center),
                        _td('${_propre(lignes[i].produit.nom)}${lignes[i].estGros ? " [Vente en Gros]" : ""}'),
                        _td(_propre(lignes[i].produit.unite), align: pw.TextAlign.center),
                        _td('${lignes[i].qte}', align: pw.TextAlign.center, bold: true),
                        _td(_propre(_formaterNombre(lignes[i].prixUnitaire)), align: pw.TextAlign.right),
                        _td(_propre(_formaterNombre(lignes[i].total)), align: pw.TextAlign.right, bold: true),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 12),

              // =======================================================
              // BAS DE FACTURE : MONTANT EN LETTRES + TOTAUX
              // =======================================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Colonne Gauche : Montant en toutes lettres & Notes
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'ARRETEE LA PRESENTE FACTURE A LA SOMME DE :',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                _propre('$montantLettres Francs CFA.'),
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (observations != null && observations.isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            _propre('Observation : $observations'),
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                        pw.SizedBox(height: 8),
                        pw.Text(
                          _propre('Les marchandises vendues ne sont ni reprises ni echangees.\nToute reclamation doit etre effectuee dans un delai de 24h.'),
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 16),

                  // Colonne Droite : Synthèse des Montants
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          if (remise > 0) ...[
                            _ligneTotal('Sous-total Brut', '${_formaterNombre(sousTotalBrut)} F'),
                            pw.SizedBox(height: 2),
                            _ligneTotal('Remise accordee', '- ${_formaterNombre(remise)} F', couleur: PdfColors.red700),
                            pw.SizedBox(height: 2),
                          ],
                          // Net à Payer (Mise en avant)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.green50,
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'NET A PAYER :',
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                                ),
                                pw.Text(
                                  '${_formaterNombre(totalNet)} F CFA',
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _ligneTotal('Montant Verse', '${_formaterNombre(montantPaye)} F'),
                          if (rendu > 0) ...[
                            pw.SizedBox(height: 2),
                            _ligneTotal('Monnaie Rendue', '${_formaterNombre(rendu)} F', couleur: PdfColors.blue700),
                          ],
                          if (resteCredit > 0) ...[
                            pw.SizedBox(height: 2),
                            _ligneTotal('Reste a Payer', '${_formaterNombre(resteCredit)} F', couleur: PdfColors.red700, bold: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // =======================================================
              // CADRES DE SIGNATURE ET CACHET
              // =======================================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    width: 220,
                    height: 70,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bon pour accord / Le Client :',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                        ),
                        pw.Spacer(),
                        pw.Text('(Signature)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 220,
                    height: 70,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pour la Direction / Le Vendeur :',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                        ),
                        pw.Spacer(),
                        pw.Text('(Signature et Cachet)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // =======================================================
              // PIED DE PAGE
              // =======================================================
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.Center(
                child: pw.Text(
                  _propre('${params.messageTicket} - ${params.nomBoutique} • Logiciel Ma Boutique Togo'),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _th(String titre, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        _propre(titre),
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _td(String texte, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        _propre(texte),
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _ligneTotal(String label, String valeur, {PdfColor? couleur, bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          _propre(label),
          style: pw.TextStyle(fontSize: 8, color: couleur ?? PdfColors.grey700, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
        pw.Text(
          _propre(valeur),
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: couleur ?? PdfColors.grey900),
        ),
      ],
    );
  }

  static String _formaterNombre(int n) {
    final s = n.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(' ');
      sb.write(s[i]);
    }
    return sb.toString();
  }

  /// Ouvre l'impression directe A4 via le gestionnaire d'impression du système (avec fallback sur macOS / bureau).
  static Future<void> imprimerFactureA4({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    String? clientTelephone,
    String? clientAdresse,
    int remise = 0,
    String modePaiement = 'especes',
    String? dateVente,
    String? caissierNom,
    bool estProforma = false,
  }) async {
    try {
      final pdfBytes = await genererPdfFactureA4(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        clientAdresse: clientAdresse,
        remise: remise,
        modePaiement: modePaiement,
        dateVente: dateVente,
        caissierNom: caissierNom,
        estProforma: estProforma,
      );

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: '${estProforma ? "Proforma" : "Facture"}_$venteId',
        );
      } catch (e) {
        if (Platform.isMacOS) {
          final tempDir = await Directory.systemTemp.createTemp('facture_');
          final tempFile = File(pth.join(tempDir.path, '${estProforma ? "proforma" : "facture"}_$venteId.pdf'));
          await tempFile.writeAsBytes(pdfBytes);
          await Process.run('open', [tempFile.path]);
          if (context.mounted) {
            message(context, '✓ Facture ouverte dans Aperçu (Appuyez sur Cmd+P pour imprimer)');
          }
          return;
        }
        rethrow;
      }
    } catch (e) {
      if (context.mounted) {
        message(context, 'Impression de la facture : ${texteErreur(e)}', erreur: true);
      }
    }
  }

  /// Télécharge la Facture PDF dans le dossier choisi par l'utilisateur.
  static Future<void> telechargerFactureA4({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    String? clientTelephone,
    String? clientAdresse,
    int remise = 0,
    String modePaiement = 'especes',
    String? dateVente,
    String? caissierNom,
    bool estProforma = false,
  }) async {
    try {
      final pdfBytes = await genererPdfFactureA4(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        clientAdresse: clientAdresse,
        remise: remise,
        modePaiement: modePaiement,
        dateVente: dateVente,
        caissierNom: caissierNom,
        estProforma: estProforma,
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nomFichier = '${estProforma ? "proforma" : "facture"}_${venteId}_$dateStr.pdf';

      if (context.mounted) {
        await exporterFichierRobuste(
          context: context,
          nomFichier: nomFichier,
          bytes: pdfBytes,
          titreDialogue: 'Enregistrer la facture PDF',
        );
      }
    } catch (e) {
      if (context.mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  /// Partage la Facture PDF via WhatsApp, Email ou messagerie.
  static Future<void> partagerFactureA4({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    String? clientTelephone,
    String? clientAdresse,
    int remise = 0,
    String modePaiement = 'especes',
    String? dateVente,
    String? caissierNom,
    bool estProforma = false,
  }) async {
    try {
      final pdfBytes = await genererPdfFactureA4(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        clientAdresse: clientAdresse,
        remise: remise,
        modePaiement: modePaiement,
        dateVente: dateVente,
        caissierNom: caissierNom,
        estProforma: estProforma,
      );

      final tempDir = await Directory.systemTemp.createTemp('facture_share_');
      final tempFile = File(pth.join(tempDir.path, '${estProforma ? "proforma" : "facture"}_$venteId.pdf'));
      await tempFile.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: '${estProforma ? "Facture Proforma" : "Facture"} N° #$venteId - ${clientNom ?? "Client"} (${fcfa(total)})',
      );
    } catch (e) {
      if (context.mounted) message(context, texteErreur(e), erreur: true);
    }
  }

  /// Ouvre la boîte de dialogue de gestion et d'édition rapide de Facture A4.
  static Future<void> afficherDialogueFacture({
    required BuildContext context,
    required int venteId,
    required List<LigneVente> lignes,
    required int total,
    required int montantPaye,
    String? clientNom,
    String? clientTelephone,
    int remise = 0,
    String modePaiement = 'especes',
    String? dateVente,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _DialogueFactureA4(
        venteId: venteId,
        lignes: lignes,
        total: total,
        montantPaye: montantPaye,
        clientNomInitial: clientNom,
        clientTelephoneInitial: clientTelephone,
        remise: remise,
        modePaiement: modePaiement,
        dateVente: dateVente,
      ),
    );
  }
}

class _DialogueFactureA4 extends StatefulWidget {
  final int venteId;
  final List<LigneVente> lignes;
  final int total;
  final int montantPaye;
  final String? clientNomInitial;
  final String? clientTelephoneInitial;
  final int remise;
  final String modePaiement;
  final String? dateVente;

  const _DialogueFactureA4({
    required this.venteId,
    required this.lignes,
    required this.total,
    required this.montantPaye,
    this.clientNomInitial,
    this.clientTelephoneInitial,
    required this.remise,
    required this.modePaiement,
    this.dateVente,
  });

  @override
  State<_DialogueFactureA4> createState() => _DialogueFactureA4State();
}

class _DialogueFactureA4State extends State<_DialogueFactureA4> {
  late final TextEditingController _nomCtrl = TextEditingController(text: widget.clientNomInitial ?? '');
  late final TextEditingController _telCtrl = TextEditingController(text: widget.clientTelephoneInitial ?? '');
  late final TextEditingController _obsCtrl = TextEditingController();
  bool _estProforma = false;
  bool _enCours = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _estProforma ? 'Facture Proforma A4' : 'Facture Commerciale A4',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Text(
                'Vente N° #${widget.venteId} • ${fcfa(widget.total)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Choix du type de facture
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.receipt_rounded, size: 16),
                      label: Text('Facture Commerciale'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.description_outlined, size: 16),
                      label: Text('Facture Proforma'),
                    ),
                  ],
                  selected: {_estProforma},
                  onSelectionChanged: (Set<bool> sel) {
                    setState(() => _estProforma = sel.first);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Renseignements client
              const Text('Destinataire de la facture :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du client ou de l’entreprise',
                  hintText: 'Ex: Ets Amouzou, M. Koffi...',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  hintText: 'Ex: +228 90 00 00 00',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observation / Note (optionnel)',
                  hintText: 'Ex: Bon pour livraison, Commande N°...',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 14),

              // Résumé articles
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${widget.lignes.length} article(s) facturé(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Total : ${fcfa(widget.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            OutlinedButton.icon(
              onPressed: _enCours ? null : () => _partager(),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Partager'),
            ),
            OutlinedButton.icon(
              onPressed: _enCours ? null : () => _telecharger(),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('PDF'),
            ),
            FilledButton.icon(
              onPressed: _enCours ? null : () => _imprimer(),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Imprimer A4'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _imprimer() async {
    setState(() => _enCours = true);
    try {
      await FactureService.imprimerFactureA4(
        context: context,
        venteId: widget.venteId,
        lignes: widget.lignes,
        total: widget.total,
        montantPaye: widget.montantPaye,
        clientNom: _nomCtrl.text.trim(),
        clientTelephone: _telCtrl.text.trim(),
        remise: widget.remise,
        modePaiement: widget.modePaiement,
        dateVente: widget.dateVente,
        estProforma: _estProforma,
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _telecharger() async {
    setState(() => _enCours = true);
    try {
      await FactureService.telechargerFactureA4(
        context: context,
        venteId: widget.venteId,
        lignes: widget.lignes,
        total: widget.total,
        montantPaye: widget.montantPaye,
        clientNom: _nomCtrl.text.trim(),
        clientTelephone: _telCtrl.text.trim(),
        remise: widget.remise,
        modePaiement: widget.modePaiement,
        dateVente: widget.dateVente,
        estProforma: _estProforma,
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _partager() async {
    setState(() => _enCours = true);
    try {
      await FactureService.partagerFactureA4(
        context: context,
        venteId: widget.venteId,
        lignes: widget.lignes,
        total: widget.total,
        montantPaye: widget.montantPaye,
        clientNom: _nomCtrl.text.trim(),
        clientTelephone: _telCtrl.text.trim(),
        remise: widget.remise,
        modePaiement: widget.modePaiement,
        dateVente: widget.dateVente,
        estProforma: _estProforma,
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}
