# Logiciel de gestion simple pour boutique d'alimentation générale

*Plan de développement : Flutter + SQLite, données locales*

Flutter + SQLite convient très bien pour un logiciel local, rapide et sans dépendance à Internet. Ce document cadre le projet pour qu'il reste vraiment simple d'utilisation.

## 1. Principe directeur : 4 écrans, pas plus au départ

Une boutique d'alimentation générale a besoin de peu, mais de façon très rapide :

1. **Caisse (vente)** : écran principal, ouvert par défaut. Recherche produit par nom ou scan de code-barres, ajout au panier, total, montant reçu, rendu monnaie, validation.
2. **Produits & stock** : liste, ajout/modification, prix d'achat et de vente, quantité, seuil d'alerte.
3. **Clients / crédits** (très utile en boutique) : qui doit combien, enregistrer un paiement.
4. **Rapports** : ventes du jour, produits bientôt en rupture, bénéfice estimé.

Les entrées de stock (réapprovisionnement) peuvent être un simple bouton dans la fiche produit au début.

## 2. Règles d'ergonomie

- Gros boutons, texte lisible, peu de menus.
- Vente en moins de 3 touches pour un produit courant (favoris / produits fréquents en raccourcis).
- Messages en français simple, pas de jargon comptable.
- Fonctionne parfaitement sans réseau, démarrage instantané.
- Confirmation uniquement pour les actions risquées (suppression, annulation de vente).

## 3. Modèle de données SQLite (minimal)

- `produits` : id, nom, code\_barres, categorie, prix\_achat, prix\_vente, stock, seuil\_alerte, unite
- `ventes` : id, date, total, montant\_paye, client\_id (nullable), mode\_paiement
- `lignes_vente` : id, vente\_id, produit\_id, quantite, prix\_unitaire
- `clients` : id, nom, telephone, solde\_credit
- `mouvements_stock` : id, produit\_id, type (entrée / vente / ajustement), quantité, date
- `paiements_credit` : id, client\_id, montant, date

**Astuce :** ne jamais modifier le stock directement. Passer par `mouvements_stock` et mettre à jour le stock dans une **transaction** SQLite avec la vente. Cela évite les incohérences et fournit un historique propre.

## 4. Choix techniques recommandés

- **Packages :** `sqflite` (mobile) ou `sqflite_common_ffi` / `drift` (desktop), `provider` ou `riverpod` pour l'état, `intl` pour les montants et dates, `mobile_scanner` si scan code-barres.
- **Drift** est un bon choix pour du typage fort et des migrations propres.
- **Architecture :** couches simples `data` (SQLite) → `repositories` → `ui`, pour pouvoir évoluer sans tout casser.
- **Migrations :** prévoir le versionnage de la base dès le début (`onUpgrade`).

## 5. Sauvegarde des données (point critique)

Comme tout est local, la perte du téléphone ou du PC entraîne la perte des données. Prévoir :

- Une **sauvegarde manuelle en un bouton** (export du fichier `.db` vers clé USB, dossier, ou partage WhatsApp/Drive).
- Une **sauvegarde automatique** quotidienne dans un dossier local.
- Une **restauration** tout aussi simple.

## 6. Ordre de développement conseillé

1. Base SQLite + produits (CRUD)
2. Écran de caisse + gestion du stock en transaction
3. Ticket / reçu (impression ou PDF)
4. Crédits clients
5. Rapports du jour
6. Sauvegarde / restauration
7. Tests sur une vraie boutique, puis ajustements

Le point le plus important : faire tester le prototype à un vrai commerçant dès l'étape 2, pour voir ce qui est réellement « simple » pour lui.

## 7. Prochaine décision

Choisir la plateforme cible (Android, Windows, ou les deux), ce qui déterminera le choix du package SQLite et la structure du projet.
