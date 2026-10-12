import 'dart:io';

import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Accès unique à la base SQLite locale (fichier boutique.db).
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  /// À appeler une fois au démarrage : active SQLite sur Windows/Linux/macOS.
  static Future<void> initFactory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<String> get dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return pth.join(dir.path, 'boutique.db');
  }

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 4,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
      onOpen: (d) async {
        // Migration automatique des PINs par défaut 4 chiffres vers 6 chiffres
        try {
          await d.rawUpdate("UPDATE utilisateurs SET pin = '123456' WHERE pin = '1234' AND role = 'gerant'");
          await d.rawUpdate("UPDATE utilisateurs SET pin = '000000' WHERE pin = '0000' AND role = 'caissier'");
        } catch (_) {}

        // Sécurisation multi-conditionnement si DB existante
        try {
          await d.execute('ALTER TABLE produits ADD COLUMN produit_parent_id INTEGER');
        } catch (_) {}
        try {
          await d.execute('ALTER TABLE produits ADD COLUMN facteur_conversion INTEGER NOT NULL DEFAULT 1');
        } catch (_) {}
        try {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS clotures_caisse(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              date_heure TEXT NOT NULL,
              caissier_nom TEXT NOT NULL DEFAULT '',
              fond_caisse INTEGER NOT NULL DEFAULT 0,
              total_ventes INTEGER NOT NULL DEFAULT 0,
              nb_ventes INTEGER NOT NULL DEFAULT 0,
              benefice_estime INTEGER NOT NULL DEFAULT 0,
              total_especes INTEGER NOT NULL DEFAULT 0,
              total_wave INTEGER NOT NULL DEFAULT 0,
              total_orange_money INTEGER NOT NULL DEFAULT 0,
              total_mtn_momo INTEGER NOT NULL DEFAULT 0,
              total_autres INTEGER NOT NULL DEFAULT 0,
              total_credits INTEGER NOT NULL DEFAULT 0,
              dettes_recouvrees INTEGER NOT NULL DEFAULT 0,
              depenses_especes INTEGER NOT NULL DEFAULT 0,
              especes_theoriques INTEGER NOT NULL DEFAULT 0,
              especes_comptees INTEGER NOT NULL DEFAULT 0,
              ecart INTEGER NOT NULL DEFAULT 0,
              observations TEXT NOT NULL DEFAULT ''
            )''');
        } catch (_) {}

        // Table des pertes, avaries et produits périmés
        try {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS pertes_stock(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              produit_id INTEGER NOT NULL REFERENCES produits(id),
              quantite INTEGER NOT NULL,
              valeur_achat INTEGER NOT NULL DEFAULT 0,
              valeur_vente INTEGER NOT NULL DEFAULT 0,
              motif TEXT NOT NULL,
              commentaire TEXT NOT NULL DEFAULT '',
              date TEXT NOT NULL,
              auteur TEXT NOT NULL DEFAULT ''
            )''');
          await d.execute('CREATE INDEX IF NOT EXISTS idx_pertes_date ON pertes_stock(date)');
        } catch (_) {}
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _create(Database d, int version) async {
    await d.execute('''
      CREATE TABLE produits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        code_barres TEXT,
        categorie TEXT NOT NULL DEFAULT '',
        unite TEXT NOT NULL DEFAULT 'pièce',
        prix_achat INTEGER NOT NULL DEFAULT 0,
        prix_vente INTEGER NOT NULL,
        prix_gros INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        seuil_alerte INTEGER NOT NULL DEFAULT 5,
        actif INTEGER NOT NULL DEFAULT 1,
        produit_parent_id INTEGER REFERENCES produits(id),
        facteur_conversion INTEGER NOT NULL DEFAULT 1
      )''');
    await d.execute('CREATE INDEX idx_produits_code ON produits(code_barres)');
    await d.execute('''
      CREATE TABLE clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL DEFAULT '',
        solde_credit INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE ventes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total INTEGER NOT NULL,
        montant_paye INTEGER NOT NULL,
        client_id INTEGER REFERENCES clients(id),
        mode_paiement TEXT NOT NULL DEFAULT 'especes'
      )''');
    await d.execute('CREATE INDEX idx_ventes_date ON ventes(date)');
    await d.execute('''
      CREATE TABLE lignes_vente(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL REFERENCES ventes(id),
        produit_id INTEGER NOT NULL REFERENCES produits(id),
        quantite INTEGER NOT NULL,
        prix_unitaire INTEGER NOT NULL,
        prix_achat INTEGER NOT NULL DEFAULT 0,
        est_gros INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE mouvements_stock(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produit_id INTEGER NOT NULL REFERENCES produits(id),
        type TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        date TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE paiements_credit(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL REFERENCES clients(id),
        montant INTEGER NOT NULL,
        date TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE utilisateurs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        role TEXT NOT NULL,
        pin TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1
      )''');
    await d.execute('''
      CREATE TABLE parametres(
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE pertes_stock(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produit_id INTEGER NOT NULL REFERENCES produits(id),
        quantite INTEGER NOT NULL,
        valeur_achat INTEGER NOT NULL DEFAULT 0,
        valeur_vente INTEGER NOT NULL DEFAULT 0,
        motif TEXT NOT NULL,
        commentaire TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        auteur TEXT NOT NULL DEFAULT ''
      )''');
    await d.execute('CREATE INDEX idx_pertes_date ON pertes_stock(date)');

    // Utilisateurs par défaut (codes PIN à 6 chiffres)
    await d.insert('utilisateurs', {'nom': 'Gérant', 'role': 'gerant', 'pin': '123456', 'actif': 1});
    await d.insert('utilisateurs', {'nom': 'Caissier', 'role': 'caissier', 'pin': '000000', 'actif': 1});

    // Paramètres par défaut
    await d.insert('parametres', {'cle': 'nom_boutique', 'valeur': 'Alimentation Générale'});
    await d.insert('parametres', {'cle': 'sous_titre', 'valeur': 'Vente en Gros & Détail'});
    await d.insert('parametres', {'cle': 'telephone', 'valeur': ''});
    await d.insert('parametres', {'cle': 'adresse', 'valeur': 'Marché Central'});
    await d.insert('parametres', {'cle': 'message_ticket', 'valeur': 'Merci de votre visite et à bientôt !'});
    await d.insert('parametres', {'cle': 'devise', 'valeur': 'F CFA'});
    await d.insert('parametres', {'cle': 'largeur_ticket', 'valeur': '80'});
    await d.insert('parametres', {'cle': 'ouvrir_tiroir', 'valeur': '0'});
  }

  Future<void> _upgrade(Database d, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Ajout de la colonne prix_gros dans produits si elle n'existe pas encore
      try {
        await d.execute('ALTER TABLE produits ADD COLUMN prix_gros INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}

      // 2. Ajout de la colonne est_gros dans lignes_vente
      try {
        await d.execute('ALTER TABLE lignes_vente ADD COLUMN est_gros INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}

      // 3. Création des tables utilisateurs et parametres
      await d.execute('''
        CREATE TABLE IF NOT EXISTS utilisateurs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          role TEXT NOT NULL,
          pin TEXT NOT NULL,
          actif INTEGER NOT NULL DEFAULT 1
        )''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS parametres(
          cle TEXT PRIMARY KEY,
          valeur TEXT NOT NULL
        )''');

      // Vérifier et insérer les utilisateurs par défaut
      final countRes = await d.rawQuery('SELECT COUNT(*) as c FROM utilisateurs');
      final nbUsers = (countRes.first['c'] as int?) ?? 0;
      if (nbUsers == 0) {
        await d.insert('utilisateurs', {'nom': 'Gérant', 'role': 'gerant', 'pin': '123456', 'actif': 1});
        await d.insert('utilisateurs', {'nom': 'Caissier', 'role': 'caissier', 'pin': '000000', 'actif': 1});
      }

      // Vérifier et insérer les paramètres par défaut
      final defParams = {
        'nom_boutique': 'Alimentation Générale',
        'sous_titre': 'Vente en Gros & Détail',
        'telephone': '',
        'adresse': 'Marché Central',
        'message_ticket': 'Merci de votre visite et à bientôt !',
        'devise': 'F CFA',
      };
      for (final e in defParams.entries) {
        await d.insert('parametres', {'cle': e.key, 'valeur': e.value},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    if (oldVersion < 3) {
      try {
        await d.execute('ALTER TABLE produits ADD COLUMN produit_parent_id INTEGER');
      } catch (_) {}
      try {
        await d.execute('ALTER TABLE produits ADD COLUMN facteur_conversion INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      await d.execute('''
        CREATE TABLE IF NOT EXISTS clotures_caisse(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          date_heure TEXT NOT NULL,
          caissier_nom TEXT NOT NULL DEFAULT '',
          fond_caisse INTEGER NOT NULL DEFAULT 0,
          total_ventes INTEGER NOT NULL DEFAULT 0,
          nb_ventes INTEGER NOT NULL DEFAULT 0,
          benefice_estime INTEGER NOT NULL DEFAULT 0,
          total_especes INTEGER NOT NULL DEFAULT 0,
          total_wave INTEGER NOT NULL DEFAULT 0,
          total_orange_money INTEGER NOT NULL DEFAULT 0,
          total_mtn_momo INTEGER NOT NULL DEFAULT 0,
          total_autres INTEGER NOT NULL DEFAULT 0,
          total_credits INTEGER NOT NULL DEFAULT 0,
          dettes_recouvrees INTEGER NOT NULL DEFAULT 0,
          depenses_especes INTEGER NOT NULL DEFAULT 0,
          especes_theoriques INTEGER NOT NULL DEFAULT 0,
          especes_comptees INTEGER NOT NULL DEFAULT 0,
          ecart INTEGER NOT NULL DEFAULT 0,
          observations TEXT NOT NULL DEFAULT ''
        )''');
      await d.insert('parametres', {'cle': 'largeur_ticket', 'valeur': '80'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await d.insert('parametres', {'cle': 'ouvrir_tiroir', 'valeur': '0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 4) {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS pertes_stock(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          produit_id INTEGER NOT NULL REFERENCES produits(id),
          quantite INTEGER NOT NULL,
          valeur_achat INTEGER NOT NULL DEFAULT 0,
          valeur_vente INTEGER NOT NULL DEFAULT 0,
          motif TEXT NOT NULL,
          commentaire TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL,
          auteur TEXT NOT NULL DEFAULT ''
        )''');
      await d.execute('CREATE INDEX IF NOT EXISTS idx_pertes_date ON pertes_stock(date)');
    }
  }
}
