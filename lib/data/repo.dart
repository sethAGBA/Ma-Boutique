import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'catalogue_africain.dart';
import 'db.dart';
import 'models.dart';

/// Toutes les opérations sur les données. Notifie l'interface après chaque écriture.
class Repo extends ChangeNotifier {
  final AppDb _adb = AppDb.instance;
  Future<Database> get _d => _adb.db;

  String get _maintenant => DateTime.now().toIso8601String();

  Utilisateur? _utilisateurActif;
  Utilisateur? get utilisateurActif => _utilisateurActif;
  bool get estConnecte => _utilisateurActif != null;
  bool get estGerant => _utilisateurActif?.estGerant ?? false;

  // ---------------------------------------------------------------- Produits

  Future<List<Produit>> produits({String q = '', String? categorie}) async {
    final d = await _d;
    final t = q.trim();
    final cat = categorie?.trim() ?? '';
    
    final whereClauses = ['p.actif = 1'];
    final whereArgs = <Object?>[];

    if (t.isNotEmpty) {
      whereClauses.add('(p.nom LIKE ? OR p.categorie LIKE ? OR p.code_barres = ?)');
      whereArgs.addAll(['%$t%', '%$t%', t]);
    }
    if (cat.isNotEmpty) {
      whereClauses.add('p.categorie = ?');
      whereArgs.add(cat);
    }

    final whereSql = whereClauses.join(' AND ');
    final rows = await d.rawQuery('''
      SELECT p.*, parent.nom AS produit_parent_nom
      FROM produits p
      LEFT JOIN produits parent ON parent.id = p.produit_parent_id
      WHERE $whereSql
      ORDER BY p.nom COLLATE NOCASE
    ''', whereArgs.isEmpty ? null : whereArgs);
    return rows.map(Produit.fromMap).toList();
  }

  Future<List<String>> categories() async {
    final d = await _d;
    final rows = await d.rawQuery(
      "SELECT DISTINCT categorie FROM produits WHERE actif = 1 AND categorie != '' ORDER BY categorie COLLATE NOCASE",
    );
    return rows.map((r) => r['categorie'] as String).toList();
  }

  /// Produits les plus vendus ces 30 derniers jours (raccourcis de la caisse).
  Future<List<Produit>> produitsFrequents({int limit = 18}) async {
    final d = await _d;
    final depuis = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final rows = await d.rawQuery('''
      SELECT p.*, parent.nom AS produit_parent_nom FROM produits p
      LEFT JOIN produits parent ON parent.id = p.produit_parent_id
      LEFT JOIN (
        SELECT l.produit_id AS pid, SUM(l.quantite) AS q
        FROM lignes_vente l JOIN ventes v ON v.id = l.vente_id
        WHERE v.date >= ? GROUP BY l.produit_id
      ) s ON s.pid = p.id
      WHERE p.actif = 1
      ORDER BY COALESCE(s.q, 0) DESC, p.nom COLLATE NOCASE
      LIMIT ?''', [depuis, limit]);
    return rows.map(Produit.fromMap).toList();
  }

  Future<Produit?> parCodeBarres(String code) async {
    if (code.trim().isEmpty) return null;
    final d = await _d;
    final rows = await d.rawQuery('''
      SELECT p.*, parent.nom AS produit_parent_nom
      FROM produits p
      LEFT JOIN produits parent ON parent.id = p.produit_parent_id
      WHERE p.actif = 1 AND p.code_barres = ?
      LIMIT 1
    ''', [code.trim()]);
    return rows.isEmpty ? null : Produit.fromMap(rows.first);
  }

  /// Déconditionnement : ouvre un ou plusieurs cartons/sacs d'un produit parent pour alimenter le stock détail.
  Future<void> deconditionnerProduit({
    required int produitDetailId,
    int nbCartons = 1,
  }) async {
    if (nbCartons <= 0) return;
    final d = await _d;
    final now = _maintenant;

    await d.transaction((txn) async {
      // 1. Récupérer le produit détail
      final detailRows = await txn.query('produits', where: 'id = ?', whereArgs: [produitDetailId]);
      if (detailRows.isEmpty) throw Exception('Produit détail introuvable');
      final detail = Produit.fromMap(detailRows.first);

      if (detail.produitParentId == null || detail.facteurConversion <= 0) {
        throw Exception('Ce produit n\'a aucun carton parent associé');
      }

      // 2. Récupérer le produit parent (carton/sac)
      final parentRows = await txn.query('produits', where: 'id = ?', whereArgs: [detail.produitParentId]);
      if (parentRows.isEmpty) throw Exception('Produit carton/parent introuvable');
      final parent = Produit.fromMap(parentRows.first);

      if (parent.stock < nbCartons) {
        throw Exception('Stock de carton insuffisant (${parent.stock} carton(s) en réserve, requis: $nbCartons)');
      }

      final unitesAjoutees = nbCartons * detail.facteurConversion;

      // 3. Décrémenter le stock parent
      await txn.rawUpdate(
        'UPDATE produits SET stock = stock - ? WHERE id = ?',
        [nbCartons, parent.id],
      );
      await txn.insert('mouvements_stock', {
        'produit_id': parent.id,
        'type': 'deconditionnement',
        'quantite': -nbCartons,
        'date': now,
      });

      // 4. Incrémenter le stock détail
      await txn.rawUpdate(
        'UPDATE produits SET stock = stock + ? WHERE id = ?',
        [unitesAjoutees, detail.id],
      );
      await txn.insert('mouvements_stock', {
        'produit_id': detail.id,
        'type': 'deconditionnement',
        'quantite': unitesAjoutees,
        'date': now,
      });
    });

    notifyListeners();
  }

  Future<List<Produit>> produitsEnAlerte() async {
    final d = await _d;
    final rows = await d.query('produits',
        where: 'actif = 1 AND stock <= seuil_alerte', orderBy: 'stock ASC', limit: 50);
    return rows.map(Produit.fromMap).toList();
  }

  Future<void> sauverProduit(Produit p, {int stockInitial = 0}) async {
    final d = await _d;
    if (p.id == null) {
      await d.transaction((txn) async {
        final id = await txn.insert('produits', {...p.toMap(), 'stock': stockInitial});
        if (stockInitial != 0) {
          await txn.insert('mouvements_stock', {
            'produit_id': id,
            'type': 'entree',
            'quantite': stockInitial,
            'date': _maintenant,
          });
        }
      });
    } else {
      await d.update('produits', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    }
    notifyListeners();
  }

  /// Suppression "douce" : le produit disparaît des listes mais l'historique reste.
  Future<void> supprimerProduit(int id) async {
    final d = await _d;
    await d.update('produits', {'actif': 0}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> entreeStock(int produitId, int quantite) async {
    if (quantite <= 0) return;
    final d = await _d;
    await d.transaction((txn) async {
      await txn.rawUpdate('UPDATE produits SET stock = stock + ? WHERE id = ?', [quantite, produitId]);
      await txn.insert('mouvements_stock', {
        'produit_id': produitId,
        'type': 'entree',
        'quantite': quantite,
        'date': _maintenant,
      });
    });
    notifyListeners();
  }

  /// Corrige le stock pour qu'il corresponde au comptage réel.
  Future<void> ajusterStock(int produitId, int nouveauStock) async {
    final d = await _d;
    await d.transaction((txn) async {
      final r = await txn.query('produits', columns: ['stock'], where: 'id = ?', whereArgs: [produitId]);
      if (r.isEmpty) return;
      final diff = nouveauStock - (r.first['stock'] as int);
      if (diff == 0) return;
      await txn.update('produits', {'stock': nouveauStock}, where: 'id = ?', whereArgs: [produitId]);
      await txn.insert('mouvements_stock', {
        'produit_id': produitId,
        'type': 'ajustement',
        'quantite': diff,
        'date': _maintenant,
      });
    });
    notifyListeners();
  }

  // ------------------------------------------------------------------ Ventes

  /// Enregistre une vente en une seule transaction (ventes + lignes + stock + crédit).
  /// Le stock peut devenir négatif : on ne bloque jamais le caissier.
  Future<int> enregistrerVente(
    List<LigneVente> lignes, {
    required int montantPaye,
    int? clientId,
    int remise = 0,
    String modePaiement = 'especes',
  }) async {
    if (lignes.isEmpty) throw Exception('Le panier est vide.');
    final sousTotal = lignes.fold<int>(0, (s, l) => s + l.total);
    final total = (sousTotal - remise) > 0 ? (sousTotal - remise) : 0;
    final paye = montantPaye > total ? total : montantPaye;
    final reste = total - paye;
    if (reste > 0 && clientId == null) {
      throw Exception('Choisissez un client pour enregistrer le reste à crédit.');
    }
    final d = await _d;
    final now = _maintenant;
    final venteId = await d.transaction<int>((txn) async {
      final id = await txn.insert('ventes', {
        'date': now,
        'total': total,
        'montant_paye': paye,
        'client_id': reste > 0 ? clientId : null,
        'mode_paiement': reste > 0 ? 'credit' : modePaiement,
      });
      for (final l in lignes) {
        await txn.insert('lignes_vente', {
          'vente_id': id,
          'produit_id': l.produit.id,
          'quantite': l.qte,
          'prix_unitaire': l.prixUnitaire,
          'prix_achat': l.produit.prixAchat,
          'est_gros': l.estGros ? 1 : 0,
        });
        await txn.rawUpdate('UPDATE produits SET stock = stock - ? WHERE id = ?', [l.qte, l.produit.id]);
        await txn.insert('mouvements_stock', {
          'produit_id': l.produit.id,
          'type': 'vente',
          'quantite': -l.qte,
          'date': now,
        });
      }
      if (reste > 0) {
        await txn.rawUpdate(
            'UPDATE clients SET solde_credit = solde_credit + ? WHERE id = ?', [reste, clientId]);
      }
      return id;
    });
    notifyListeners();
    return venteId;
  }

  /// Historique des ventes avec les lignes d'articles et le nom du client.
  Future<List<Vente>> ventes({String? dateDebut, int limit = 50}) async {
    final d = await _d;
    String sql = '''
      SELECT v.*, c.nom AS client_nom
      FROM ventes v
      LEFT JOIN clients c ON c.id = v.client_id
    ''';
    List<Object?> args = [];
    if (dateDebut != null) {
      sql += ' WHERE v.date >= ?';
      args.add(dateDebut);
    }
    sql += ' ORDER BY v.date DESC LIMIT ?';
    args.add(limit);

    final rows = await d.rawQuery(sql, args);
    final liste = <Vente>[];

    for (final r in rows) {
      final vid = r['id'] as int;
      final lignesRows = await d.rawQuery('''
        SELECT l.*, p.nom AS p_nom, p.code_barres AS p_code, p.categorie AS p_cat, p.unite AS p_unite, p.stock AS p_stock, p.seuil_alerte AS p_seuil
        FROM lignes_vente l
        JOIN produits p ON p.id = l.produit_id
        WHERE l.vente_id = ?
      ''', [vid]);

      final lignes = lignesRows.map((lr) {
        final prod = Produit(
          id: lr['produit_id'] as int,
          nom: lr['p_nom'] as String,
          codeBarres: (lr['p_code'] as String?) ?? '',
          categorie: (lr['p_cat'] as String?) ?? '',
          unite: (lr['p_unite'] as String?) ?? 'pièce',
          prixAchat: lr['prix_achat'] as int,
          prixVente: lr['prix_unitaire'] as int,
          stock: lr['p_stock'] as int,
          seuilAlerte: lr['p_seuil'] as int,
        );
        final estGros = ((lr['est_gros'] as int?) ?? 0) == 1;
        return LigneVente(
          produit: prod,
          qte: lr['quantite'] as int,
          estGros: estGros,
          prixPersonnalise: lr['prix_unitaire'] as int,
        );
      }).toList();

      liste.add(Vente(
        id: vid,
        date: r['date'] as String,
        total: r['total'] as int,
        montantPaye: r['montant_paye'] as int,
        clientId: r['client_id'] as int?,
        clientNom: r['client_nom'] as String?,
        modePaiement: r['mode_paiement'] as String,
        lignes: lignes,
      ));
    }
    return liste;
  }

  /// Récupère une vente par son identifiant avec toutes ses lignes de produits.
  Future<Vente?> venteParId(int id) async {
    final d = await _d;
    final rows = await d.rawQuery('''
      SELECT v.*, c.nom AS client_nom
      FROM ventes v
      LEFT JOIN clients c ON c.id = v.client_id
      WHERE v.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final lignesRows = await d.rawQuery('''
      SELECT l.*, p.nom AS p_nom, p.code_barres AS p_code, p.categorie AS p_cat, p.unite AS p_unite, p.stock AS p_stock, p.seuil_alerte AS p_seuil
      FROM lignes_vente l
      JOIN produits p ON p.id = l.produit_id
      WHERE l.vente_id = ?
    ''', [id]);
    final lignes = lignesRows.map((lr) {
      final prod = Produit(
        id: lr['produit_id'] as int,
        nom: lr['p_nom'] as String,
        codeBarres: (lr['p_code'] as String?) ?? '',
        categorie: (lr['p_cat'] as String?) ?? '',
        unite: (lr['p_unite'] as String?) ?? 'pièce',
        prixAchat: lr['prix_achat'] as int,
        prixVente: lr['prix_unitaire'] as int,
        stock: lr['p_stock'] as int,
        seuilAlerte: lr['p_seuil'] as int,
      );
      final estGros = ((lr['est_gros'] as int?) ?? 0) == 1;
      return LigneVente(
        produit: prod,
        qte: lr['quantite'] as int,
        estGros: estGros,
        prixPersonnalise: lr['prix_unitaire'] as int,
      );
    }).toList();
    return Vente(
      id: id,
      date: r['date'] as String,
      total: r['total'] as int,
      montantPaye: r['montant_paye'] as int,
      clientId: r['client_id'] as int?,
      clientNom: r['client_nom'] as String?,
      modePaiement: (r['mode_paiement'] as String?) ?? 'especes',
      lignes: lignes,
    );
  }

  /// Annule une vente : remet le stock en place et annule la dette client si crédit.
  Future<void> annulerVente(int venteId) async {
    final d = await _d;
    final now = _maintenant;
    await d.transaction((txn) async {
      final vRows = await txn.query('ventes', where: 'id = ?', whereArgs: [venteId], limit: 1);
      if (vRows.isEmpty) return;
      final v = vRows.first;
      final total = v['total'] as int;
      final paye = v['montant_paye'] as int;
      final clientId = v['client_id'] as int?;
      final reste = total - paye;

      // Restituer le stock
      final lignes = await txn.query('lignes_vente', where: 'vente_id = ?', whereArgs: [venteId]);
      for (final l in lignes) {
        final pid = l['produit_id'] as int;
        final qte = l['quantite'] as int;
        await txn.rawUpdate('UPDATE produits SET stock = stock + ? WHERE id = ?', [qte, pid]);
        await txn.insert('mouvements_stock', {
          'produit_id': pid,
          'type': 'annulation_vente',
          'quantite': qte,
          'date': now,
        });
      }

      // Annuler le crédit si le client avait une dette sur cette vente
      if (reste > 0 && clientId != null) {
        await txn.rawUpdate(
          'UPDATE clients SET solde_credit = MAX(0, solde_credit - ?) WHERE id = ?',
          [reste, clientId],
        );
      }

      // Supprimer les lignes et la vente
      await txn.delete('lignes_vente', where: 'vente_id = ?', whereArgs: [venteId]);
      await txn.delete('ventes', where: 'id = ?', whereArgs: [venteId]);
    });
    notifyListeners();
  }

  // ----------------------------------------------------------------- Clients

  Future<List<Client>> clients({String q = ''}) async {
    final d = await _d;
    final t = q.trim();
    if (t.isEmpty) {
      final rows = await d.query('clients', orderBy: 'solde_credit DESC, nom COLLATE NOCASE');
      return rows.map(Client.fromMap).toList();
    }
    final rows = await d.query(
      'clients',
      where: 'nom LIKE ? OR telephone LIKE ?',
      whereArgs: ['%$t%', '%$t%'],
      orderBy: 'solde_credit DESC, nom COLLATE NOCASE',
    );
    return rows.map(Client.fromMap).toList();
  }

  Future<void> sauverClient(Client c) async {
    final d = await _d;
    final m = {'nom': c.nom, 'telephone': c.telephone};
    if (c.id == null) {
      await d.insert('clients', m);
    } else {
      await d.update('clients', m, where: 'id = ?', whereArgs: [c.id]);
    }
    notifyListeners();
  }

  Future<void> enregistrerPaiement(int clientId, int montant) async {
    if (montant <= 0) return;
    final d = await _d;
    await d.transaction((txn) async {
      await txn.insert('paiements_credit', {
        'client_id': clientId,
        'montant': montant,
        'date': _maintenant,
      });
      await txn.rawUpdate(
          'UPDATE clients SET solde_credit = MAX(0, solde_credit - ?) WHERE id = ?', [montant, clientId]);
    });
    notifyListeners();
  }

  Future<List<PaiementCredit>> paiementsClient(int clientId) async {
    final d = await _d;
    final rows = await d.query(
      'paiements_credit',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC',
    );
    return rows.map(PaiementCredit.fromMap).toList();
  }

  Future<List<Vente>> ventesClient(int clientId) async {
    final d = await _d;
    final rows = await d.query(
      'ventes',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC',
    );
    return rows.map((r) => Vente(
      id: r['id'] as int,
      date: r['date'] as String,
      total: r['total'] as int,
      montantPaye: r['montant_paye'] as int,
      clientId: r['client_id'] as int?,
      modePaiement: r['mode_paiement'] as String,
    )).toList();
  }

  // ---------------------------------------------------------------- Rapports

  Future<RapportJour> rapportDuJour() async {
    final d = await _d;
    final n = DateTime.now();
    final debut = DateTime(n.year, n.month, n.day).toIso8601String();
    final v = await d.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS t FROM ventes WHERE date >= ?', [debut]);
    final b = await d.rawQuery('''
      SELECT COALESCE(SUM((l.prix_unitaire - l.prix_achat) * l.quantite), 0) AS b
      FROM lignes_vente l JOIN ventes v ON v.id = l.vente_id WHERE v.date >= ?''', [debut]);
    return RapportJour(
      nbVentes: v.first['n'] as int,
      total: v.first['t'] as int,
      benefice: b.first['b'] as int,
    );
  }

  Future<int> totalCredits() async {
    final d = await _d;
    final r = await d.rawQuery('SELECT COALESCE(SUM(solde_credit), 0) AS t FROM clients');
    return r.first['t'] as int;
  }

  /// Clôture de caisse du jour : total des ventes, marge, espèces et crédits.
  Future<ClotureJour> clotureDuJour([DateTime? dateRef]) async {
    final d = await _d;
    final n = dateRef ?? DateTime.now();
    final debut = DateTime(n.year, n.month, n.day).toIso8601String();
    final fin = DateTime(n.year, n.month, n.day, 23, 59, 59).toIso8601String();

    final vRows = await d.rawQuery('''
      SELECT 
        COUNT(*) AS nb,
        COALESCE(SUM(total), 0) AS total,
        COALESCE(SUM(CASE WHEN montant_paye >= total THEN total ELSE montant_paye END), 0) AS especes,
        COALESCE(SUM(CASE WHEN total > montant_paye THEN total - montant_paye ELSE 0 END), 0) AS credits
      FROM ventes
      WHERE date >= ? AND date <= ?
    ''', [debut, fin]);

    final bRows = await d.rawQuery('''
      SELECT COALESCE(SUM((l.prix_unitaire - l.prix_achat) * l.quantite), 0) AS b
      FROM lignes_vente l
      JOIN ventes v ON v.id = l.vente_id
      WHERE v.date >= ? AND v.date <= ?
    ''', [debut, fin]);

    final pRows = await d.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) AS recouv
      FROM paiements_credit
      WHERE date >= ? AND date <= ?
    ''', [debut, fin]);

    final nb = vRows.first['nb'] as int;
    final total = vRows.first['total'] as int;
    final especes = vRows.first['especes'] as int;
    final credits = vRows.first['credits'] as int;
    final benefice = bRows.first['b'] as int;
    final dettesRecouvrees = pRows.first['recouv'] as int;

    return ClotureJour(
      date: DateFormat('dd/MM/yyyy').format(n),
      nbVentes: nb,
      totalVentes: total,
      benefice: benefice,
      especesVentes: especes,
      nouveauxCredits: credits,
      dettesRecouvrees: dettesRecouvrees,
    );
  }

  /// Fond de caisse initial du jour (monnaie de départ)
  Future<int> getFondCaisseDuJour([DateTime? dateRef]) async {
    final d = await _d;
    final n = dateRef ?? DateTime.now();
    final cle = 'fond_caisse_${DateFormat('yyyy-MM-dd').format(n)}';
    final rows = await d.query('parametres', where: 'cle = ?', whereArgs: [cle]);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['valeur'] as String) ?? 0;
  }

  /// Définit le fond de caisse du jour
  Future<void> setFondCaisseDuJour(int montant, [DateTime? dateRef]) async {
    final d = await _d;
    final n = dateRef ?? DateTime.now();
    final cle = 'fond_caisse_${DateFormat('yyyy-MM-dd').format(n)}';
    await d.insert('parametres', {'cle': cle, 'valeur': montant.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  /// Calcule en temps réel le bilan de clôture de caisse (Ticket Z) avec ventilation des paiements
  Future<ClotureCaisse> calculerBilanCloture({
    int? fondCaisse,
    DateTime? dateRef,
    String? caissierNom,
    int? especesComptees,
    String observations = '',
  }) async {
    final d = await _d;
    final n = dateRef ?? DateTime.now();
    final debut = DateTime(n.year, n.month, n.day).toIso8601String();
    final fin = DateTime(n.year, n.month, n.day, 23, 59, 59).toIso8601String();
    final dateStr = DateFormat('dd/MM/yyyy').format(n);
    final dateHeureStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final fond = fondCaisse ?? await getFondCaisseDuJour(n);

    // Ventes ventilées par mode de paiement
    final vRows = await d.rawQuery('''
      SELECT 
        COUNT(*) AS nb,
        COALESCE(SUM(total), 0) AS total,
        COALESCE(SUM(CASE WHEN mode_paiement = 'especes' THEN (CASE WHEN montant_paye >= total THEN total ELSE montant_paye END) ELSE 0 END), 0) AS esp,
        COALESCE(SUM(CASE WHEN mode_paiement = 'tmoney' THEN montant_paye ELSE 0 END), 0) AS tmoney,
        COALESCE(SUM(CASE WHEN mode_paiement = 'flooz' THEN montant_paye ELSE 0 END), 0) AS flooz,
        COALESCE(SUM(CASE WHEN mode_paiement = 'wave' THEN montant_paye ELSE 0 END), 0) AS wave,
        COALESCE(SUM(CASE WHEN mode_paiement = 'orange_money' THEN montant_paye ELSE 0 END), 0) AS om,
        COALESCE(SUM(CASE WHEN mode_paiement = 'mtn_momo' THEN montant_paye ELSE 0 END), 0) AS mtn,
        COALESCE(SUM(CASE WHEN mode_paiement IN ('carte', 'virement', 'cheque') THEN montant_paye ELSE 0 END), 0) AS autres,
        COALESCE(SUM(CASE WHEN total > montant_paye THEN total - montant_paye ELSE 0 END), 0) AS credits
      FROM ventes
      WHERE date >= ? AND date <= ?
    ''', [debut, fin]);

    // Bénéfice estimé
    final bRows = await d.rawQuery('''
      SELECT COALESCE(SUM((l.prix_unitaire - l.prix_achat) * l.quantite), 0) AS b
      FROM lignes_vente l
      JOIN ventes v ON v.id = l.vente_id
      WHERE v.date >= ? AND v.date <= ?
    ''', [debut, fin]);

    // Dettes recouvrées en espèces
    final pRows = await d.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) AS recouv
      FROM paiements_credit
      WHERE date >= ? AND date <= ?
    ''', [debut, fin]);

    final nb = (vRows.first['nb'] as int?) ?? 0;
    final total = (vRows.first['total'] as int?) ?? 0;
    final esp = (vRows.first['esp'] as int?) ?? 0;
    final tmoney = (vRows.first['tmoney'] as int?) ?? 0;
    final flooz = (vRows.first['flooz'] as int?) ?? 0;
    final wave = (vRows.first['wave'] as int?) ?? 0;
    final om = (vRows.first['om'] as int?) ?? 0;
    final mtn = (vRows.first['mtn'] as int?) ?? 0;
    final autres = (vRows.first['autres'] as int?) ?? 0;
    final credits = (vRows.first['credits'] as int?) ?? 0;
    final benefice = (bRows.first['b'] as int?) ?? 0;
    final dettesRecouvrees = (pRows.first['recouv'] as int?) ?? 0;

    final espTheoriques = fond + esp + dettesRecouvrees;
    final comptees = especesComptees ?? espTheoriques;
    final ecart = comptees - espTheoriques;

    return ClotureCaisse(
      date: dateStr,
      dateHeure: dateHeureStr,
      caissierNom: caissierNom ?? 'Caisse Principale',
      fondCaisse: fond,
      totalVentes: total,
      nbVentes: nb,
      beneficeEstime: benefice,
      totalEspeces: esp,
      totalTmoney: tmoney,
      totalFlooz: flooz,
      totalWave: wave,
      totalOrangeMoney: om,
      totalMtnMomo: mtn,
      totalAutres: autres,
      totalCredits: credits,
      dettesRecouvrees: dettesRecouvrees,
      depensesEspeces: 0,
      especesTheoriques: espTheoriques,
      especesComptees: comptees,
      ecart: ecart,
      observations: observations,
    );
  }

  /// Enregistre définitivement une clôture Z dans l'historique
  Future<int> enregistrerCloture(ClotureCaisse c) async {
    final d = await _d;
    final id = await d.insert('clotures_caisse', c.toMap());
    notifyListeners();
    return id;
  }

  /// Historique des clôtures Z de caisse passées
  Future<List<ClotureCaisse>> historiqueClotures({int limit = 50}) async {
    final d = await _d;
    final rows = await d.query(
      'clotures_caisse',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(ClotureCaisse.fromMap).toList();
  }

  /// Situation d'Inventaire (SI) & Valorisation globale du stock
  Future<SituationInventaire> situationInventaire() async {
    final d = await _d;
    final stats = await d.rawQuery('''
      SELECT 
        COUNT(*) as nb_refs,
        COALESCE(SUM(stock), 0) as total_articles,
        COALESCE(SUM(stock * prix_achat), 0) as val_achat,
        COALESCE(SUM(stock * prix_vente), 0) as val_vente,
        COALESCE(SUM(stock * (prix_vente - prix_achat)), 0) as marge
      FROM produits
      WHERE actif = 1
    ''');
    final prods = await produits();
    final first = stats.first;
    return SituationInventaire(
      nbReferences: first['nb_refs'] as int,
      totalArticles: first['total_articles'] as int,
      valeurAchat: first['val_achat'] as int,
      valeurVente: first['val_vente'] as int,
      margeTheorique: first['marge'] as int,
      produits: prods,
    );
  }

  /// Top articles les plus vendus
  Future<List<StatTopProduit>> topProduitsVendus({int limit = 10}) async {
    final d = await _d;
    final rows = await d.rawQuery('''
      SELECT 
        p.nom,
        SUM(l.quantite) as qte,
        SUM(l.quantite * l.prix_unitaire) as ca
      FROM lignes_vente l
      JOIN produits p ON p.id = l.produit_id
      GROUP BY p.id
      ORDER BY ca DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => StatTopProduit(
      nom: r['nom'] as String,
      quantite: (r['qte'] as num?)?.toInt() ?? 0,
      chiffreAffaires: (r['ca'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  /// Ventes ventilées par catégorie
  Future<List<StatCategorie>> ventesParCategorie() async {
    final d = await _d;
    final rows = await d.rawQuery('''
      SELECT 
        COALESCE(NULLIF(p.categorie, ''), 'Autres') as cat,
        SUM(l.quantite * l.prix_unitaire) as ca,
        COUNT(l.id) as nb
      FROM lignes_vente l
      JOIN produits p ON p.id = l.produit_id
      GROUP BY cat
      ORDER BY ca DESC
    ''');
    return rows.map((r) => StatCategorie(
      categorie: r['cat'] as String,
      chiffreAffaires: (r['ca'] as num?)?.toInt() ?? 0,
      nbLignes: (r['nb'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  /// Répartition des ventes Gros vs Détail
  Future<StatGrosDetail> repartitionGrosDetail() async {
    final d = await _d;
    final rows = await d.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN est_gros = 0 THEN quantite * prix_unitaire ELSE 0 END), 0) as ca_detail,
        COALESCE(SUM(CASE WHEN est_gros = 0 THEN quantite ELSE 0 END), 0) as qte_detail,
        COALESCE(SUM(CASE WHEN est_gros = 1 THEN quantite * prix_unitaire ELSE 0 END), 0) as ca_gros,
        COALESCE(SUM(CASE WHEN est_gros = 1 THEN quantite ELSE 0 END), 0) as qte_gros
      FROM lignes_vente
    ''');
    final first = rows.first;
    return StatGrosDetail(
      caDetail: first['ca_detail'] as int,
      qteDetail: first['qte_detail'] as int,
      caGros: first['ca_gros'] as int,
      qteGros: first['qte_gros'] as int,
    );
  }

  // ------------------------------------------------------------- Import/Export

  /// Exporte tous les produits du catalogue au format CSV standard (séparateur point-virgule pour Excel).
  Future<String> exportProduitsCsv() async {
    final prods = await produits();
    final sb = StringBuffer();
    sb.writeln('Nom;Categorie;Code-barres;Unite;Prix achat;Prix vente;Stock;Seuil alerte');
    for (final p in prods) {
      final nom = p.nom.replaceAll(';', ',');
      final cat = p.categorie.replaceAll(';', ',');
      final code = p.codeBarres.replaceAll(';', ',');
      final unite = p.unite.replaceAll(';', ',');
      sb.writeln('$nom;$cat;$code;$unite;${p.prixAchat};${p.prixVente};${p.stock};${p.seuilAlerte}');
    }
    return sb.toString();
  }

  /// Importe ou met à jour des produits depuis un fichier CSV (détection automatique de séparateurs ; et ,).
  Future<int> importProduitsCsv(String csvContent) async {
    final lignes = csvContent.split(RegExp(r'\r?\n'));
    int count = 0;
    if (lignes.isEmpty) return 0;

    for (int i = 0; i < lignes.length; i++) {
      final ligne = lignes[i].trim();
      if (ligne.isEmpty) continue;

      final sep = ligne.contains(';') ? ';' : ',';
      final cols = ligne.split(sep).map((c) => c.replaceAll('"', '').trim()).toList();
      if (cols.isEmpty) continue;

      if (i == 0 && (cols[0].toLowerCase().contains('nom') || cols[0].toLowerCase().contains('designation'))) {
        continue;
      }

      final nom = cols[0];
      if (nom.isEmpty) continue;

      final cat = cols.length > 1 ? cols[1] : '';
      final code = cols.length > 2 ? cols[2] : '';
      final unite = cols.length > 3 && cols[3].isNotEmpty ? cols[3] : 'pièce';
      final pAchat = cols.length > 4 ? int.tryParse(cols[4].replaceAll(' ', '')) ?? 0 : 0;
      final pVente = cols.length > 5 ? int.tryParse(cols[5].replaceAll(' ', '')) ?? 0 : 0;
      final stock = cols.length > 6 ? int.tryParse(cols[6].replaceAll(' ', '')) ?? 0 : 0;
      final seuil = cols.length > 7 ? int.tryParse(cols[7].replaceAll(' ', '')) ?? 5 : 5;

      if (pVente <= 0 && pAchat <= 0) continue;

      final existants = await produits(q: code.isNotEmpty ? code : nom);
      final existant = existants.cast<Produit?>().firstWhere(
            (p) => (code.isNotEmpty && p?.codeBarres == code) || p?.nom.toLowerCase() == nom.toLowerCase(),
            orElse: () => null,
          );

      if (existant != null) {
        await sauverProduit(Produit(
          id: existant.id,
          nom: nom,
          categorie: cat.isNotEmpty ? cat : existant.categorie,
          codeBarres: code.isNotEmpty ? code : existant.codeBarres,
          unite: unite,
          prixAchat: pAchat > 0 ? pAchat : existant.prixAchat,
          prixVente: pVente > 0 ? pVente : existant.prixVente,
          stock: existant.stock,
          seuilAlerte: seuil,
        ));
      } else {
        await sauverProduit(
          Produit(
            nom: nom,
            categorie: cat,
            codeBarres: code,
            unite: unite,
            prixAchat: pAchat,
            prixVente: pVente,
            stock: stock,
            seuilAlerte: seuil,
          ),
          stockInitial: stock,
        );
      }
      count++;
    }
    notifyListeners();
    return count;
  }


  // -------------------------------------------------------------- Sauvegarde

  Future<Directory> _dossierSauvegardes() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(pth.join(base.path, 'sauvegardes_boutique'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> sauvegarderMaintenant() async {
    await _d; // s'assure que le fichier existe
    final src = File(await _adb.dbPath);
    final dir = await _dossierSauvegardes();
    final nom = 'boutique_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
    final dest = await src.copy(pth.join(dir.path, nom));
    await _nettoyer(dir);
    return dest;
  }

  /// Une copie automatique par jour, au premier lancement de la journée.
  Future<void> sauvegardeAutoQuotidienne() async {
    await _d;
    final dir = await _dossierSauvegardes();
    final jour = DateFormat('yyyyMMdd').format(DateTime.now());
    final existe = dir.listSync().any((f) => pth.basename(f.path).startsWith('boutique_$jour'));
    if (!existe) await sauvegarderMaintenant();
  }

  /// Garde les 30 sauvegardes les plus récentes.
  Future<void> _nettoyer(Directory dir) async {
    final fichiers = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in fichiers.skip(30)) {
      await f.delete();
    }
  }

  /// Remplace les données actuelles par celles d'un fichier de sauvegarde.
  /// Une copie de sécurité des données actuelles est faite avant.
  Future<void> restaurer(File source) async {
    final test = await openDatabase(source.path, readOnly: true);
    try {
      final ok = await test.rawQuery("SELECT name FROM sqlite_master WHERE name = 'produits'");
      if (ok.isEmpty) throw Exception("Ce fichier n'est pas une sauvegarde de la boutique.");
    } finally {
      await test.close();
    }
    await sauvegarderMaintenant();
    await _adb.close();
    final cible = File(await _adb.dbPath);
    if (await cible.exists()) await cible.delete();
    await source.copy(cible.path);
    await _adb.db; // rouvre la base
    notifyListeners();
  }

  // --------------------------------------------------- Catalogue Africain
  /// Initialise la base avec les 55+ produits africains si la base est vide.
  Future<void> initialiserApplication() async {
    final d = await _d;
    final count = Sqflite.firstIntValue(
      await d.rawQuery('SELECT COUNT(*) FROM produits WHERE actif = 1'),
    ) ?? 0;
    if (count == 0) {
      await chargerCatalogueAfricain(ecraser: false);
    }
  }

  /// Charge les 300+ articles types d'alimentations générales africaines.
  /// Si [ecraser] est vrai, remplace les stocks et prix par les valeurs modèles.
  Future<int> chargerCatalogueAfricain({bool ecraser = false}) async {
    final d = await _d;
    int ajoutes = 0;

    await d.transaction((txn) async {
      for (final a in articlesAlimentationAfricaine) {
        final existants = await txn.query(
          'produits',
          where: a.codeBarres.isNotEmpty
              ? 'nom = ? OR code_barres = ?'
              : 'nom = ?',
          whereArgs: a.codeBarres.isNotEmpty ? [a.nom, a.codeBarres] : [a.nom],
        );

        if (existants.isEmpty) {
          final pid = await txn.insert('produits', {
            'nom': a.nom,
            'categorie': a.categorie,
            'code_barres': a.codeBarres.isEmpty ? null : a.codeBarres,
            'unite': a.unite,
            'prix_achat': a.prixAchat,
            'prix_vente': a.prixVente,
            'prix_gros': a.prixGros,
            'stock': a.stockInitial,
            'seuil_alerte': a.seuilAlerte,
            'actif': 1,
          });

          if (a.stockInitial > 0) {
            await txn.insert('mouvements_stock', {
              'produit_id': pid,
              'type': 'entree',
              'quantite': a.stockInitial,
              'date': _maintenant,
            });
          }
          ajoutes++;
        } else if (ecraser) {
          final pid = existants.first['id'] as int;
          await txn.update(
            'produits',
            {
              'categorie': a.categorie,
              'unite': a.unite,
              'prix_achat': a.prixAchat,
              'prix_vente': a.prixVente,
              'prix_gros': a.prixGros,
              'stock': a.stockInitial,
              'seuil_alerte': a.seuilAlerte,
              'actif': 1,
            },
            where: 'id = ?',
            whereArgs: [pid],
          );
          ajoutes++;
        }
      }
    });

    notifyListeners();
    return ajoutes;
  }

  // ------------------------------------------------- Utilisateurs & Sécurité
  Future<List<Utilisateur>> utilisateurs() async {
    final d = await _d;
    final rows = await d.query('utilisateurs', where: 'actif = 1', orderBy: 'id ASC');
    return rows.map(Utilisateur.fromMap).toList();
  }

  Future<Utilisateur?> authentifierPin(String pin) async {
    final d = await _d;
    final pinPropre = pin.trim();
    var rows = await d.query('utilisateurs',
        where: 'actif = 1 AND pin = ?', whereArgs: [pinPropre], limit: 1);

    // Fallback de transition si l'utilisateur saisit 123456 ou 000000 alors que la base avait encore 1234 ou 0000
    if (rows.isEmpty && pinPropre == '123456') {
      rows = await d.query('utilisateurs',
          where: "actif = 1 AND pin = '1234' AND role = 'gerant'", limit: 1);
      if (rows.isNotEmpty) {
        await d.rawUpdate("UPDATE utilisateurs SET pin = '123456' WHERE id = ?", [rows.first['id']]);
      }
    } else if (rows.isEmpty && pinPropre == '000000') {
      rows = await d.query('utilisateurs',
          where: "actif = 1 AND pin = '0000' AND role = 'caissier'", limit: 1);
      if (rows.isNotEmpty) {
        await d.rawUpdate("UPDATE utilisateurs SET pin = '000000' WHERE id = ?", [rows.first['id']]);
      }
    }

    if (rows.isEmpty) return null;
    final u = Utilisateur.fromMap(rows.first);
    _utilisateurActif = u;
    notifyListeners();
    return u;
  }

  void changerUtilisateurActif(Utilisateur? u) {
    _utilisateurActif = u;
    notifyListeners();
  }

  void deconnecter() {
    _utilisateurActif = null;
    notifyListeners();
  }

  Future<bool> changerPin(int userId, String nouveauPin) async {
    final p = nouveauPin.trim();
    if (p.length != 6) return false;
    final d = await _d;
    await d.update(
      'utilisateurs',
      {'pin': p},
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (_utilisateurActif?.id == userId) {
      final rows = await d.query('utilisateurs', where: 'id = ?', whereArgs: [userId]);
      if (rows.isNotEmpty) _utilisateurActif = Utilisateur.fromMap(rows.first);
    }
    notifyListeners();
    return true;
  }

  Future<void> sauverUtilisateur(Utilisateur u) async {
    final d = await _d;
    if (u.id <= 0) {
      await d.insert('utilisateurs', u.toMap());
    } else {
      await d.update('utilisateurs', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
    }
    notifyListeners();
  }

  // ---------------------------------------------------- Paramètres Boutique
  Future<ParametresBoutique> chargerParametres() async {
    final d = await _d;
    final rows = await d.query('parametres');
    final map = <String, String>{};
    for (final r in rows) {
      map[r['cle'] as String] = r['valeur'] as String;
    }
    return ParametresBoutique(
      nomBoutique: map['nom_boutique'] ?? 'Alimentation Générale',
      sousTitre: map['sous_titre'] ?? 'Vente en Gros & Détail',
      telephone: map['telephone'] ?? '',
      adresse: map['adresse'] ?? 'Marché Central',
      messageTicket: map['message_ticket'] ?? 'Merci de votre visite et à bientôt !',
      devise: map['devise'] ?? 'F CFA',
      logoPath: map['logo_path'] ?? '',
      largeurTicket: int.tryParse(map['largeur_ticket'] ?? '80') ?? 80,
      ouvrirTiroir: (map['ouvrir_tiroir'] ?? '0') == '1',
      nif: map['nif'] ?? '',
      rccm: map['rccm'] ?? '',
      email: map['email'] ?? '',
    );
  }

  Future<void> sauverParametres(ParametresBoutique p) async {
    final d = await _d;
    final batch = d.batch();
    batch.insert('parametres', {'cle': 'nom_boutique', 'valeur': p.nomBoutique},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'sous_titre', 'valeur': p.sousTitre},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'telephone', 'valeur': p.telephone},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'adresse', 'valeur': p.adresse},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'message_ticket', 'valeur': p.messageTicket},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'devise', 'valeur': p.devise},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'logo_path', 'valeur': p.logoPath},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'largeur_ticket', 'valeur': p.largeurTicket.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'ouvrir_tiroir', 'valeur': p.ouvrirTiroir ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'nif', 'valeur': p.nif},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'rccm', 'valeur': p.rccm},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('parametres', {'cle': 'email', 'valeur': p.email},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
    notifyListeners();
  }

  // ----------------------------------------------------------- Pertes & Avaries

  /// Enregistre une perte / avarie / produit périmé ou consommation interne.
  /// Déduit immédiatement le stock dans une transaction atomique et enregistre le mouvement.
  Future<int> enregistrerPerte({
    required int produitId,
    required int quantite,
    required String motif, // 'avarie', 'perime', 'consommation', 'vol_manquant', 'autre'
    String commentaire = '',
    String? auteur,
  }) async {
    if (quantite <= 0) throw Exception('La quantité doit être supérieure à 0.');
    final d = await _d;

    return await d.transaction((txn) async {
      // 1. Récupération du produit pour calculer le coût financier
      final pRows = await txn.query('produits', where: 'id = ?', whereArgs: [produitId]);
      if (pRows.isEmpty) throw Exception('Produit introuvable.');
      final prod = Produit.fromMap(pRows.first);

      final dateStr = DateTime.now().toIso8601String();
      final nomAuteur = auteur ?? utilisateurActif?.nom ?? 'Gérant';
      final valAchat = quantite * prod.prixAchat;
      final valVente = quantite * prod.prixVente;

      // 2. Enregistrement de la perte
      final perteId = await txn.insert('pertes_stock', {
        'produit_id': produitId,
        'quantite': quantite,
        'valeur_achat': valAchat,
        'valeur_vente': valVente,
        'motif': motif,
        'commentaire': commentaire.trim(),
        'date': dateStr,
        'auteur': nomAuteur,
      });

      // 3. Déduction du stock physique
      await txn.rawUpdate(
        'UPDATE produits SET stock = stock - ? WHERE id = ?',
        [quantite, produitId],
      );

      // 4. Mouvement de stock pour traçabilité
      await txn.insert('mouvements_stock', {
        'produit_id': produitId,
        'type': 'perte_$motif',
        'quantite': -quantite,
        'date': dateStr,
      });

      return perteId;
    }).then((id) {
      notifyListeners();
      return id;
    });
  }

  /// Liste chronologique des pertes avec détails du produit
  Future<List<PerteStock>> pertesStock({
    String? dateDebut,
    String? dateFin,
    String? motif,
    int limit = 100,
  }) async {
    final d = await _d;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (dateDebut != null) {
      whereClauses.add('p.date >= ?');
      whereArgs.add(dateDebut);
    }
    if (dateFin != null) {
      whereClauses.add('p.date <= ?');
      whereArgs.add(dateFin);
    }
    if (motif != null && motif.isNotEmpty && motif != 'tous') {
      whereClauses.add('p.motif = ?');
      whereArgs.add(motif);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final rows = await d.rawQuery('''
      SELECT 
        p.*, 
        prod.nom AS produit_nom,
        prod.unite AS produit_unite
      FROM pertes_stock p
      JOIN produits prod ON prod.id = p.produit_id
      $whereSql
      ORDER BY p.date DESC
      LIMIT ?
    ''', [...whereArgs, limit]);

    return rows.map(PerteStock.fromMap).toList();
  }

  /// Statistiques des pertes (coût d'achat total, valeur de vente perdue, par motif)
  Future<StatsPertes> statsPertes({String? dateDebut, String? dateFin}) async {
    final d = await _d;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (dateDebut != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(dateDebut);
    }
    if (dateFin != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(dateFin);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final rows = await d.rawQuery('''
      SELECT 
        COUNT(*) AS total_nb,
        COALESCE(SUM(quantite), 0) AS total_qte,
        COALESCE(SUM(valeur_achat), 0) AS total_val_achat,
        COALESCE(SUM(valeur_vente), 0) AS total_val_vente
      FROM pertes_stock
      $whereSql
    ''', whereArgs);

    final motifsRows = await d.rawQuery('''
      SELECT 
        motif, 
        COALESCE(SUM(valeur_achat), 0) AS val_achat
      FROM pertes_stock
      $whereSql
      GROUP BY motif
    ''', whereArgs);

    final mapMotifs = <String, int>{};
    for (final r in motifsRows) {
      final m = r['motif'] as String? ?? 'autre';
      final v = (r['val_achat'] as int?) ?? 0;
      mapMotifs[m] = v;
    }

    final first = rows.first;
    return StatsPertes(
      totalPertes: (first['total_nb'] as int?) ?? 0,
      totalQuantite: (first['total_qte'] as int?) ?? 0,
      totalValeurAchat: (first['total_val_achat'] as int?) ?? 0,
      totalValeurVente: (first['total_val_vente'] as int?) ?? 0,
      repartitionParMotif: mapMotifs,
    );
  }

  /// Annulation d'une perte (réintègre la quantité au stock)
  Future<void> annulerPerte(int perteId) async {
    final d = await _d;
    await d.transaction((txn) async {
      final rows = await txn.query('pertes_stock', where: 'id = ?', whereArgs: [perteId]);
      if (rows.isEmpty) return;
      final p = PerteStock.fromMap(rows.first);

      // Réintégrer le stock
      await txn.rawUpdate(
        'UPDATE produits SET stock = stock + ? WHERE id = ?',
        [p.quantite, p.produitId],
      );

      // Mouvement d'annulation
      await txn.insert('mouvements_stock', {
        'produit_id': p.produitId,
        'type': 'annulation_perte',
        'quantite': p.quantite,
        'date': DateTime.now().toIso8601String(),
      });

      // Supprimer l'enregistrement de perte
      await txn.delete('pertes_stock', where: 'id = ?', whereArgs: [perteId]);
    });
    notifyListeners();
  }
}

