import 'package:flutter_test/flutter_test.dart';
import 'package:stockar/data/models.dart';
import 'package:stockar/ui/facture_service.dart';
import 'package:stockar/ui/helpers.dart';
import 'package:stockar/ui/searchable_dropdown.dart';

void main() {
  group('Marché Togolais & Fonctionnalités 1, 3, 5', () {
    test('Calcul et bilan ClotureCaisse avec Mobile Money Togo (T-Money, Flooz, Wave)', () {
      final cloture = ClotureCaisse(
        date: '12/10/2026',
        dateHeure: '12/10/2026 19:30',
        caissierNom: 'Koffi',
        fondCaisse: 15000,
        totalVentes: 125000,
        nbVentes: 24,
        beneficeEstime: 32000,
        totalEspeces: 65000,
        totalTmoney: 30000,
        totalFlooz: 20000,
        totalWave: 10000,
        especesTheoriques: 80000, // 15000 fond + 65000 espèces
        especesComptees: 80000,
        ecart: 0,
      );

      expect(cloture.totalVentes, 125000);
      expect(cloture.totalTmoney, 30000);
      expect(cloture.totalFlooz, 20000);
      expect(cloture.totalWave, 10000);
      expect(cloture.aEcart, isFalse);
      expect(cloture.estExcedent, isFalse);
      expect(cloture.estDeficit, isFalse);

      final avecEcart = ClotureCaisse(
        date: '12/10/2026',
        dateHeure: '12/10/2026 19:30',
        caissierNom: 'Koffi',
        especesTheoriques: 80000,
        especesComptees: 78500,
        ecart: -1500,
      );
      expect(avecEcart.aEcart, isTrue);
      expect(avecEcart.estDeficit, isTrue);
      expect(avecEcart.ecart, -1500);
    });

    test('Liaison Carton/Détail et Déconditionnement Stock', () {
      final cartonSpaghetti = const Produit(
        id: 10,
        nom: 'Carton Spaghetti Bonita 20x500g',
        prixVente: 11500,
        stock: 5,
        unite: 'carton',
      );

      final paquetSpaghetti = Produit(
        id: 11,
        nom: 'Spaghetti Bonita 500g (Détail)',
        prixVente: 600,
        stock: 0,
        unite: 'paquet',
        produitParentId: cartonSpaghetti.id,
        facteurConversion: 20,
        produitParentNom: cartonSpaghetti.nom,
      );

      expect(paquetSpaghetti.estDeconditionne, isTrue);
      expect(paquetSpaghetti.facteurConversion, 20);
      expect(paquetSpaghetti.produitParentId, 10);
      expect(paquetSpaghetti.produitParentNom, contains('Bonita'));
    });

    test('Paramètres boutique impression thermique et tiroir ESC/POS', () {
      final params80 = ParametresBoutique(
        nomBoutique: 'Épicerie Centrale Lomé',
        largeurTicket: 80,
        ouvrirTiroir: true,
      );
      expect(params80.largeurTicket, 80);
      expect(params80.ouvrirTiroir, isTrue);

      final params58 = ParametresBoutique(
        nomBoutique: 'Boutique Tokoin',
        largeurTicket: 58,
        ouvrirTiroir: false,
      );
      expect(params58.largeurTicket, 58);
      expect(params58.ouvrirTiroir, isFalse);
    });

    test('Fonctionnalité 4 : Modèle PerteStock, motifs et conversion de données', () {
      final perte = PerteStock(
        id: 1,
        produitId: 42,
        produitNom: 'Lait Bonnet Rouge 410g',
        produitUnite: 'boîte',
        quantite: 3,
        valeurAchat: 1800,
        valeurVente: 2250,
        motif: 'avarie',
        commentaire: 'Boîtes cabossées à la livraison',
        date: '2026-10-12T14:00:00.000',
        auteur: 'Directeur',
      );

      expect(perte.motifLibelle, 'Casse / Boîte abîmée');
      expect(perte.quantite, 3);
      expect(perte.valeurAchat, 1800);
      expect(perte.valeurVente, 2250);

      final map = perte.toMap();
      expect(map['produit_id'], 42);
      expect(map['motif'], 'avarie');
      expect(map['valeur_achat'], 1800);

      final reconstructed = PerteStock.fromMap({
        ...map,
        'produit_nom': 'Lait Bonnet Rouge 410g',
        'produit_unite': 'boîte',
      });
      expect(reconstructed.id, 1);
      expect(reconstructed.produitNom, 'Lait Bonnet Rouge 410g');
      expect(reconstructed.motif, 'avarie');
      expect(reconstructed.motifLibelle, 'Casse / Boîte abîmée');
    });

    test('Fonctionnalité 4 : Libellés des motifs de perte adaptés au commerce togolais', () {
      expect(PerteStock.libelleMotif('avarie'), 'Casse / Boîte abîmée');
      expect(PerteStock.libelleMotif('perime'), 'Produit Périmé');
      expect(PerteStock.libelleMotif('consommation'), 'Consommation interne');
      expect(PerteStock.libelleMotif('vol_manquant'), 'Vol / Manquant');
      expect(PerteStock.libelleMotif('inconnu'), 'Autre');
    });

    test('Fonctionnalité 4 : Modèle StatsPertes et agrégations financières', () {
      const stats = StatsPertes(
        totalPertes: 4,
        totalQuantite: 15,
        totalValeurAchat: 9500,
        totalValeurVente: 12200,
        repartitionParMotif: {
          'avarie': 3500,
          'perime': 4000,
          'consommation': 2000,
        },
      );

      expect(stats.totalPertes, 4);
      expect(stats.totalQuantite, 15);
      expect(stats.totalValeurAchat, 9500);
      expect(stats.totalValeurVente, 12200);
      expect(stats.repartitionParMotif['avarie'], 3500);
      expect(stats.repartitionParMotif['perime'], 4000);
      expect(stats.repartitionParMotif['consommation'], 2000);
    });

    test('Module Facture : Conversion des montants en toutes lettres en français', () {
      expect(nombreEnLettres(0), 'zéro');
      expect(nombreEnLettres(1), 'Un');
      expect(nombreEnLettres(15), 'Quinze');
      expect(nombreEnLettres(80), 'Quatre-vingts');
      expect(nombreEnLettres(100), 'Cent');
      expect(nombreEnLettres(1500), 'Mille cinq cents');
      expect(nombreEnLettres(25000), 'Vingt-cinq mille');
      expect(nombreEnLettres(125000), 'Cent vingt-cinq mille');
      expect(nombreEnLettres(1250500), 'Un million deux cent cinquante mille cinq cents');
    });

    test('Module Facture : Coordonnées fiscales NIF, RCCM et boutique Togo', () {
      final p = ParametresBoutique(
        nomBoutique: 'Établissements Kodjo & Fils',
        sousTitre: 'Import - Demi-Gros & Détail',
        adresse: 'Grand Marché d’Adawlato, Lomé - Togo',
        telephone: '+228 90 12 34 56',
        nif: '100012345678',
        rccm: 'TG-LOM-2024-B-0987',
        email: 'kodjo@boutique.tg',
      );

      expect(p.nomBoutique, 'Établissements Kodjo & Fils');
      expect(p.nif, '100012345678');
      expect(p.rccm, 'TG-LOM-2024-B-0987');
      expect(p.email, 'kodjo@boutique.tg');
    });

    test('Module Facture : Génération binaire d’une Facture A4 PDF complète', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final produit1 = const Produit(
        id: 1,
        nom: 'Riz Parfumé Mémé Cassé 25kg',
        prixVente: 18500,
        unite: 'sac',
      );
      final produit2 = const Produit(
        id: 2,
        nom: 'Carton Huile Végétale Mayor 12x1L',
        prixVente: 16000,
        unite: 'carton',
      );

      final lignes = [
        LigneVente(produit: produit1, qte: 2), // 37 000
        LigneVente(produit: produit2, qte: 1), // 16 000
      ];

      final pdfBytes = await FactureService.genererPdfFactureA4(
        venteId: 104,
        lignes: lignes,
        total: 53000,
        montantPaye: 53000,
        clientNom: 'Société Ets Togoville',
        clientTelephone: '+228 91 22 33 44',
        modePaiement: 'tmoney',
        dateVente: '2026-10-12T15:30:00.000',
        caissierNom: 'Afi',
        parametresBoutique: const ParametresBoutique(
          nomBoutique: 'Établissements Kodjo & Fils',
          telephone: '+228 90 00 00 00',
          nif: '100012345678',
        ),
      );

      expect(pdfBytes, isNotEmpty);
      // Vérification signature magique PDF (%PDF-)
      final entete = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(entete, '%PDF-');
    });

    test('Dropdown avec recherche : Filtrage par nom, référence et sous-titre', () {
      const itemTomate = SearchableItem<int>(
        value: 10,
        titre: 'Boîte Tomate Concentrée Gino 70g',
        sousTitre: 'Stock : 48 boîtes • Cat : Conserves',
        reference: '600100200300 Conserves',
      );

      // Recherche par nom
      expect(itemTomate.correspond('gino'), isTrue);
      expect(itemTomate.correspond('TOMATE'), isTrue);

      // Recherche par sous-titre ou catégorie
      expect(itemTomate.correspond('conserves'), isTrue);

      // Recherche par code-barres / référence
      expect(itemTomate.correspond('600100'), isTrue);

      // Recherche sans correspondance
      expect(itemTomate.correspond('spaghetti'), isFalse);
    });
  });
}


