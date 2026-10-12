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
  });
}
