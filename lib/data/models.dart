class Produit {
  final int? id;
  final String nom;
  final String codeBarres;
  final String categorie;
  final String unite;
  final int prixAchat;
  final int prixVente;
  final int prixGros;
  final int stock;
  final int seuilAlerte;

  const Produit({
    this.id,
    required this.nom,
    this.codeBarres = '',
    this.categorie = '',
    this.unite = 'pièce',
    this.prixAchat = 0,
    required this.prixVente,
    this.prixGros = 0,
    this.stock = 0,
    this.seuilAlerte = 5,
  });

  factory Produit.fromMap(Map<String, Object?> m) => Produit(
        id: m['id'] as int,
        nom: m['nom'] as String,
        codeBarres: (m['code_barres'] as String?) ?? '',
        categorie: (m['categorie'] as String?) ?? '',
        unite: (m['unite'] as String?) ?? 'pièce',
        prixAchat: (m['prix_achat'] as int?) ?? 0,
        prixVente: m['prix_vente'] as int,
        prixGros: (m['prix_gros'] as int?) ?? 0,
        stock: (m['stock'] as int?) ?? 0,
        seuilAlerte: (m['seuil_alerte'] as int?) ?? 5,
      );

  /// Le stock n'est volontairement pas inclus : il ne change que par mouvements.
  Map<String, Object?> toMap() => {
        'nom': nom,
        'code_barres': codeBarres.isEmpty ? null : codeBarres,
        'categorie': categorie,
        'unite': unite,
        'prix_achat': prixAchat,
        'prix_vente': prixVente,
        'prix_gros': prixGros,
        'seuil_alerte': seuilAlerte,
      };

  bool get enAlerte => stock <= seuilAlerte;
}

class Client {
  final int? id;
  final String nom;
  final String telephone;
  final int soldeCredit;

  const Client({this.id, required this.nom, this.telephone = '', this.soldeCredit = 0});

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int,
        nom: m['nom'] as String,
        telephone: (m['telephone'] as String?) ?? '',
        soldeCredit: m['solde_credit'] as int,
      );
}

class LigneVente {
  final Produit produit;
  int qte;
  bool estGros;
  int? prixPersonnalise;

  LigneVente({
    required this.produit,
    this.qte = 1,
    this.estGros = false,
    this.prixPersonnalise,
  });

  int get prixUnitaire {
    if (prixPersonnalise != null) return prixPersonnalise!;
    if (estGros && produit.prixGros > 0) return produit.prixGros;
    return produit.prixVente;
  }

  int get total => qte * prixUnitaire;
}

class Vente {
  final int id;
  final String date;
  final int total;
  final int montantPaye;
  final int? clientId;
  final String? clientNom;
  final String modePaiement;
  final List<LigneVente> lignes;

  const Vente({
    required this.id,
    required this.date,
    required this.total,
    required this.montantPaye,
    this.clientId,
    this.clientNom,
    required this.modePaiement,
    this.lignes = const [],
  });

  int get rendu => montantPaye > total ? montantPaye - total : 0;
  int get resteCredit => total > montantPaye ? total - montantPaye : 0;
}

class PaiementCredit {
  final int id;
  final int clientId;
  final int montant;
  final String date;

  const PaiementCredit({
    required this.id,
    required this.clientId,
    required this.montant,
    required this.date,
  });

  factory PaiementCredit.fromMap(Map<String, Object?> m) => PaiementCredit(
        id: m['id'] as int,
        clientId: m['client_id'] as int,
        montant: m['montant'] as int,
        date: m['date'] as String,
      );
}

class RapportJour {
  final int nbVentes;
  final int total;
  final int benefice;
  const RapportJour({required this.nbVentes, required this.total, required this.benefice});
}

class ClotureJour {
  final String date;
  final int nbVentes;
  final int totalVentes;
  final int benefice;
  final int especesVentes;
  final int nouveauxCredits;
  final int dettesRecouvrees;

  const ClotureJour({
    required this.date,
    required this.nbVentes,
    required this.totalVentes,
    required this.benefice,
    required this.especesVentes,
    required this.nouveauxCredits,
    required this.dettesRecouvrees,
  });

  /// Total d'argent liquide réel entré en caisse aujourd'hui
  int get totalLiquideCaisse => especesVentes + dettesRecouvrees;
}

class Utilisateur {
  final int id;
  final String nom;
  final String role; // 'gerant' ou 'caissier'
  final String pin;
  final bool actif;

  const Utilisateur({
    required this.id,
    required this.nom,
    required this.role,
    required this.pin,
    this.actif = true,
  });

  bool get estGerant => role == 'gerant';

  factory Utilisateur.fromMap(Map<String, Object?> m) => Utilisateur(
        id: m['id'] as int,
        nom: m['nom'] as String,
        role: (m['role'] as String?) ?? 'caissier',
        pin: (m['pin'] as String?) ?? '0000',
        actif: ((m['actif'] as int?) ?? 1) == 1,
      );

  Map<String, Object?> toMap() => {
        'nom': nom,
        'role': role,
        'pin': pin,
        'actif': actif ? 1 : 0,
      };
}

class ParametresBoutique {
  final String nomBoutique;
  final String sousTitre;
  final String telephone;
  final String adresse;
  final String messageTicket;
  final String devise;
  final String logoPath;

  const ParametresBoutique({
    this.nomBoutique = 'Ma Boutique',
    this.sousTitre = 'Alimentation Générale',
    this.telephone = '',
    this.adresse = '',
    this.messageTicket = 'Merci de votre visite et à bientôt !',
    this.devise = 'F CFA',
    this.logoPath = '',
  });

  ParametresBoutique copyWith({
    String? nomBoutique,
    String? sousTitre,
    String? telephone,
    String? adresse,
    String? messageTicket,
    String? devise,
    String? logoPath,
  }) {
    return ParametresBoutique(
      nomBoutique: nomBoutique ?? this.nomBoutique,
      sousTitre: sousTitre ?? this.sousTitre,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      messageTicket: messageTicket ?? this.messageTicket,
      devise: devise ?? this.devise,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}


