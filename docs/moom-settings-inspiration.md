# Réglages et fonctionnalités inspirés de Moom

Référence consultée le 2026-10-14 : [Moom](https://manytricks.com/moom/),
[interface des actions](https://manytricks.com/moom/help/aboutcustom.html),
[actions et dispositions](https://manytricks.com/moom/help/customactions.html).
La capture officielle montre une liste d'actions à gauche et une grande zone
d'édition avec aperçu à droite. Cette observation porte sur la documentation,
pas sur un essai de l'application. Moom est propriétaire ; implémentation PK indépendante.

## Appliqué dans la Dev 74

- **Découverte** : entrée Rooms dans la barre latérale, recherche et menu direct.
- **Modification** : éditeur commun aux réglages et au panneau, brouillon annulable.
- **Aperçu** : cinq dispositions sélectionnables visuellement, recalculées avec les
  fenêtres choisies ; même moteur géométrique que le placement réel.
- **Réutilisation** : dupliquer une room ouvre une nouvelle définition indépendante,
  avec le même ensemble de fenêtres et la même disposition. Elle n'est enregistrée
  qu'après confirmation du formulaire.
- **Récupération** : annuler la dernière suppression tant que la page reste ouverte.

## Suite proposée, pas encore implémentée

| Fonction | Utilité | Préparation nécessaire |
|---|---|---|
| Enregistrer la disposition actuelle | Retrouver un arrangement manuel, au-delà des cinq modèles | Géométries normalisées, migrations et rappel multi-écrans |
| Gabarit pour N fenêtres | Réutiliser une disposition avec d'autres applications | Séparer gabarit et room, inventaire ordonné par usage |
| Import/export | Partager et sauvegarder les projets | Format versionné, conflits d'identifiants et validation des fichiers |
| Chaînes et cycles | Déplacer vers un écran puis redimensionner avec une seule commande | Catalogue d'actions composables, annulation et état par fenêtre |
| Zones de dépôt avec aperçu | Placer une fenêtre dans un gabarit personnalisé | Gabarits libres et raccord au snap existant |

Conserver la barre latérale PK, les langues et les réglages partagés. Pour les
collections plus importantes, une liste de projets et un panneau d'édition
permanent peuvent remplacer les cartes sans changer le format des données.
