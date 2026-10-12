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
    
    final whereClauses = ['actif = 1'];
    final whereArgs = <Object?>[];

    if (t.isNotEmpty) {
      whereClauses.add('(nom LIKE ? OR categorie LIKE ? OR code_barres = ?)');
      whereArgs.addAll(['%$t%', '%$t%', t]);
    }
    if (cat.isNotEmpty) {
      whereClauses.add('categorie = ?');
      whereArgs.add(cat);
    }

    final rows = await d.query(
      'produits',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nom COLLATE NOCASE',
    );
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
      SELECT p.* FROM produits p
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
    final rows = await d.query('produits',
        where: 'actif = 1 AND code_barres = ?', whereArgs: [code.trim()], limit: 1);
    return rows.isEmpty ? null : Produit.fromMap(rows.first);
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
        'mode_paiement': reste > 0 ? 'credit' : 'especes',
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
    await batch.commit(noResult: true);
    notifyListeners();
  }
}

