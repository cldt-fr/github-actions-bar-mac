# ActionsBar

Application macOS de barre des menus qui affiche en direct la progression des workflows GitHub Actions en cours.

- **Dans la barre des menus** : un anneau de progression et le pourcentage (`63%`, ou `2 · 63%` quand plusieurs runs tournent). Au repos, une icône ✓ / ✗ indique le résultat du dernier run.
- **Dans le panneau** : les runs en cours avec le dépôt, la branche, une barre de progression, le temps écoulé, une estimation du temps restant et le détail des jobs avec l'étape en cours. En dessous, les runs récemment terminés. Un clic ouvre le run sur GitHub.
- **Notifications** quand un workflow se termine (un clic ouvre le run).

## Prérequis

- macOS 14 ou plus
- Xcode / Swift 6
- [GitHub CLI](https://cli.github.com) connecté (`gh auth login`), ou un token personnel

## Installation

```sh
make install   # compile, crée ActionsBar.app et l'installe dans /Applications
```

Autres commandes :

```sh
make run       # compile le .app dans build/ et le lance
make build     # build de debug (swift build)
swift run      # lancement rapide sans bundle (pas de notifications)
```

## Fonctionnement

- **Authentification** : le token de `gh auth token` est utilisé par défaut. Un token saisi dans les réglages (stocké dans le Trousseau) est prioritaire.
- **Dépôts suivis** : par défaut les 15 dépôts sur lesquels tu as poussé le plus récemment (perso et organisations), plus ceux ajoutés à la main dans les réglages (`owner/nom`). La liste est rafraîchie toutes les 5 minutes.
- **Rafraîchissement** : toutes les 5 s quand un run est en cours, toutes les 30 s sinon (réglable). Les requêtes utilisent les ETag : les réponses inchangées (304) ne consomment pas le quota de l'API.
- **Progression** : pour chaque job, le ratio d'étapes terminées ; la progression du run est la moyenne de ses jobs. Le temps restant est estimé à partir de la durée du dernier run réussi du même workflow.
