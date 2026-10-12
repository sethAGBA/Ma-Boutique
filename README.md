# Ma Boutique — gestion simple pour boutique d'alimentation générale

Application Flutter hors-ligne (SQLite local). Android et Windows.

## Mise en route

```bash
flutter create --org tg.boutique --project-name boutique boutique_app
cd boutique_app
# remplacer lib/ et pubspec.yaml par ceux de ce dossier, puis :
rm -f test/widget_test.dart
flutter pub get
flutter run -d windows     # ou -d android
```

## Ce qui est inclus

- **Caisse** : produits fréquents en raccourcis, recherche, scan code-barres (lecteur USB = clavier), panier, monnaie à rendre, vente à crédit.
- **Produits & stock** : ajout/modification, entrée de stock, correction de stock, alerte de seuil.
- **Clients & crédits** : solde dû par client, enregistrement des paiements.
- **Rapports** : ventes du jour, bénéfice estimé, crédits à recevoir, stock à surveiller.
- **Sauvegarde** : copie automatique quotidienne (30 dernières conservées), sauvegarde manuelle, restauration.

## Choix de conception

- Montants en entiers (FCFA), pas de décimales.
- Le stock ne change que par `mouvements_stock`, dans une transaction avec la vente.
- Le stock peut passer en négatif : on ne bloque jamais le caissier.
- Suppression d'un produit = masquage (l'historique des ventes reste intact).

## Limites actuelles / prochaines étapes

- Quantités entières seulement (pas de vente au poids/au détail).
- Pas encore de ticket imprimé/PDF, ni d'historique détaillé des ventes.
- Pas de gestion de plusieurs utilisateurs / codes d'accès.
# Ma-Boutique
