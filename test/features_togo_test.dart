import 'package:flutter_test/flutter_test.dart';
import 'package:stockar/data/models.dart';

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
  });
}

