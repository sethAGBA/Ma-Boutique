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
  final int? produitParentId;
  final int facteurConversion;
  final String? produitParentNom;

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
    this.produitParentId,
    this.facteurConversion = 1,
    this.produitParentNom,
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
        produitParentId: m['produit_parent_id'] as int?,
        facteurConversion: (m['facteur_conversion'] as int?) ?? 1,
        produitParentNom: m['produit_parent_nom'] as String?,
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
        'produit_parent_id': produitParentId,
        'facteur_conversion': facteurConversion,
      };

  bool get enAlerte => stock <= seuilAlerte;
  bool get estDeconditionne => produitParentId != null && facteurConversion > 1;

  Produit copyWith({
    int? id,
    String? nom,
    String? codeBarres,
    String? categorie,
    String? unite,
    int? prixAchat,
    int? prixVente,
    int? prixGros,
    int? stock,
    int? seuilAlerte,
    int? produitParentId,
    int? facteurConversion,
    String? produitParentNom,
  }) {
    return Produit(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      codeBarres: codeBarres ?? this.codeBarres,
      categorie: categorie ?? this.categorie,
      unite: unite ?? this.unite,
      prixAchat: prixAchat ?? this.prixAchat,
      prixVente: prixVente ?? this.prixVente,
      prixGros: prixGros ?? this.prixGros,
      stock: stock ?? this.stock,
      seuilAlerte: seuilAlerte ?? this.seuilAlerte,
      produitParentId: produitParentId ?? this.produitParentId,
      facteurConversion: facteurConversion ?? this.facteurConversion,
      produitParentNom: produitParentNom ?? this.produitParentNom,
    );
  }
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

class ClotureCaisse {
  final int? id;
  final String date;
  final String dateHeure;
  final String caissierNom;
  final int fondCaisse;
  final int totalVentes;
  final int nbVentes;
  final int beneficeEstime;
  final int totalEspeces;
  final int totalTmoney;
  final int totalFlooz;
  final int totalWave;
  final int totalOrangeMoney;
  final int totalMtnMomo;
  final int totalAutres;
  final int totalCredits;
  final int dettesRecouvrees;
  final int depensesEspeces;
  final int especesTheoriques;
  final int especesComptees;
  final int ecart;
  final String observations;

  const ClotureCaisse({
    this.id,
    required this.date,
    required this.dateHeure,
    this.caissierNom = '',
    this.fondCaisse = 0,
    this.totalVentes = 0,
    this.nbVentes = 0,
    this.beneficeEstime = 0,
    this.totalEspeces = 0,
    this.totalTmoney = 0,
    this.totalFlooz = 0,
    this.totalWave = 0,
    this.totalOrangeMoney = 0,
    this.totalMtnMomo = 0,
    this.totalAutres = 0,
    this.totalCredits = 0,
    this.dettesRecouvrees = 0,
    this.depensesEspeces = 0,
    this.especesTheoriques = 0,
    this.especesComptees = 0,
    this.ecart = 0,
    this.observations = '',
  });

  bool get aEcart => ecart != 0;
  bool get estExcedent => ecart > 0;
  bool get estDeficit => ecart < 0;

  factory ClotureCaisse.fromMap(Map<String, Object?> m) => ClotureCaisse(
        id: m['id'] as int?,
        date: m['date'] as String,
        dateHeure: m['date_heure'] as String,
        caissierNom: (m['caissier_nom'] as String?) ?? '',
        fondCaisse: (m['fond_caisse'] as int?) ?? 0,
        totalVentes: (m['total_ventes'] as int?) ?? 0,
        nbVentes: (m['nb_ventes'] as int?) ?? 0,
        beneficeEstime: (m['benefice_estime'] as int?) ?? 0,
        totalEspeces: (m['total_especes'] as int?) ?? 0,
        totalTmoney: (m['total_tmoney'] as int?) ?? 0,
        totalFlooz: (m['total_flooz'] as int?) ?? 0,
        totalWave: (m['total_wave'] as int?) ?? 0,
        totalOrangeMoney: (m['total_orange_money'] as int?) ?? 0,
        totalMtnMomo: (m['total_mtn_momo'] as int?) ?? 0,
        totalAutres: (m['total_autres'] as int?) ?? 0,
        totalCredits: (m['total_credits'] as int?) ?? 0,
        dettesRecouvrees: (m['dettes_recouvrees'] as int?) ?? 0,
        depensesEspeces: (m['depenses_especes'] as int?) ?? 0,
        especesTheoriques: (m['especes_theoriques'] as int?) ?? 0,
        especesComptees: (m['especes_comptees'] as int?) ?? 0,
        ecart: (m['ecart'] as int?) ?? 0,
        observations: (m['observations'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'date_heure': dateHeure,
        'caissier_nom': caissierNom,
        'fond_caisse': fondCaisse,
        'total_ventes': totalVentes,
        'nb_ventes': nbVentes,
        'benefice_estime': beneficeEstime,
        'total_especes': totalEspeces,
        'total_tmoney': totalTmoney,
        'total_flooz': totalFlooz,
        'total_wave': totalWave,
        'total_orange_money': totalOrangeMoney,
        'total_mtn_momo': totalMtnMomo,
        'total_autres': totalAutres,
        'total_credits': totalCredits,
        'dettes_recouvrees': dettesRecouvrees,
        'depenses_especes': depensesEspeces,
        'especes_theoriques': especesTheoriques,
        'especes_comptees': especesComptees,
        'ecart': ecart,
        'observations': observations,
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
  final int largeurTicket; // 58 ou 80
  final bool ouvrirTiroir; // ouverture automatique tiroir-caisse

  const ParametresBoutique({
    this.nomBoutique = 'Ma Boutique',
    this.sousTitre = 'Alimentation Générale',
    this.telephone = '',
    this.adresse = '',
    this.messageTicket = 'Merci de votre visite et à bientôt !',
    this.devise = 'F CFA',
    this.logoPath = '',
    this.largeurTicket = 80,
    this.ouvrirTiroir = false,
  });

  ParametresBoutique copyWith({
    String? nomBoutique,
    String? sousTitre,
    String? telephone,
    String? adresse,
    String? messageTicket,
    String? devise,
    String? logoPath,
    int? largeurTicket,
    bool? ouvrirTiroir,
  }) {
    return ParametresBoutique(
      nomBoutique: nomBoutique ?? this.nomBoutique,
      sousTitre: sousTitre ?? this.sousTitre,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      messageTicket: messageTicket ?? this.messageTicket,
      devise: devise ?? this.devise,
      logoPath: logoPath ?? this.logoPath,
      largeurTicket: largeurTicket ?? this.largeurTicket,
      ouvrirTiroir: ouvrirTiroir ?? this.ouvrirTiroir,
    );
  }
}

class SituationInventaire {
  final int nbReferences;
  final int totalArticles;
  final int valeurAchat;
  final int valeurVente;
  final int margeTheorique;
  final List<Produit> produits;

  const SituationInventaire({
    required this.nbReferences,
    required this.totalArticles,
    required this.valeurAchat,
    required this.valeurVente,
    required this.margeTheorique,
    required this.produits,
  });
}

class StatTopProduit {
  final String nom;
  final int quantite;
  final int chiffreAffaires;

  const StatTopProduit({
    required this.nom,
    required this.quantite,
    required this.chiffreAffaires,
  });
}

class StatCategorie {
  final String categorie;
  final int chiffreAffaires;
  final int nbLignes;

  const StatCategorie({
    required this.categorie,
    required this.chiffreAffaires,
    required this.nbLignes,
  });
}

class StatGrosDetail {
  final int caDetail;
  final int qteDetail;
  final int caGros;
  final int qteGros;

  const StatGrosDetail({
    required this.caDetail,
    required this.qteDetail,
    required this.caGros,
    required this.qteGros,
  });

  int get caTotal => caDetail + caGros;
  double get partGrosPct => caTotal > 0 ? (caGros / caTotal) * 100 : 0.0;
}

/// Modèle pour les pertes, avaries, périmés et consommations internes
class PerteStock {
  final int? id;
  final int produitId;
  final String produitNom;
  final String produitUnite;
  final int quantite;
  final int valeurAchat;
  final int valeurVente;
  final String motif; // 'avarie', 'perime', 'consommation', 'vol_manquant', 'autre'
  final String commentaire;
  final String date;
  final String auteur;

  const PerteStock({
    this.id,
    required this.produitId,
    this.produitNom = '',
    this.produitUnite = 'pièce',
    required this.quantite,
    required this.valeurAchat,
    required this.valeurVente,
    required this.motif,
    this.commentaire = '',
    required this.date,
    this.auteur = '',
  });

  static String libelleMotif(String motif) {
    switch (motif) {
      case 'avarie':
        return 'Casse / Boîte abîmée';
      case 'perime':
        return 'Produit Périmé';
      case 'consommation':
        return 'Consommation interne';
      case 'vol_manquant':
        return 'Vol / Manquant';
      default:
        return 'Autre';
    }
  }

  String get motifLibelle => libelleMotif(motif);

  factory PerteStock.fromMap(Map<String, Object?> m) => PerteStock(
        id: m['id'] as int?,
        produitId: m['produit_id'] as int,
        produitNom: (m['produit_nom'] as String?) ?? '',
        produitUnite: (m['produit_unite'] as String?) ?? 'pièce',
        quantite: m['quantite'] as int,
        valeurAchat: (m['valeur_achat'] as int?) ?? 0,
        valeurVente: (m['valeur_vente'] as int?) ?? 0,
        motif: (m['motif'] as String?) ?? 'autre',
        commentaire: (m['commentaire'] as String?) ?? '',
        date: m['date'] as String,
        auteur: (m['auteur'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'produit_id': produitId,
        'quantite': quantite,
        'valeur_achat': valeurAchat,
        'valeur_vente': valeurVente,
        'motif': motif,
        'commentaire': commentaire,
        'date': date,
        'auteur': auteur,
      };
}

class StatsPertes {
  final int totalPertes;
  final int totalQuantite;
  final int totalValeurAchat;
  final int totalValeurVente;
  final Map<String, int> repartitionParMotif;

  const StatsPertes({
    this.totalPertes = 0,
    this.totalQuantite = 0,
    this.totalValeurAchat = 0,
    this.totalValeurVente = 0,
    this.repartitionParMotif = const {},
  });
}


