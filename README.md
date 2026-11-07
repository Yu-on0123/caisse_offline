# Ma Caisse — suivi des ventes et dépenses, offline-first

Application Flutter (Android, iOS, web) pour petits commerçants : enregistrer ventes et dépenses
**sans connexion**, puis synchroniser avec le serveur dès que le réseau revient.
Les comptes se créent sur l'**espace web** du backend ; l'application s'y connecte avec les mêmes identifiants,
après une confirmation par code (voir « Connexion au compte »).

## Fonctionnalités

- Vente en quelques appuis depuis un catalogue de produits, ou montant libre
- Dépenses par catégorie
- Tableau de bord : ventes, dépenses, bénéfice estimé (jour / semaine / mois), graphique des 7 derniers jours
- Indicateur de synchronisation (hors ligne, en attente, synchronisé, erreur)
- Fonctionne entièrement en local ; la synchronisation démarre à la connexion au compte
- Lien vers l'espace web dans les réglages (créer un compte, consulter ses données, confirmer une connexion)

## Configuration : variables d'environnement

Les adresses du serveur et de l'espace web sont **fixées à la compilation**, jamais saisies par l'utilisateur.
Copiez `env.example.json` en `env.json` et adaptez-le :

```json
{
  "API_URL": "http://127.0.0.1:8000",
  "WEB_URL": "http://127.0.0.1:8000"
}
```

| Variable | Rôle |
|---|---|
| `API_URL` | racine du serveur, **sans `/api`** (ajouté automatiquement) |
| `WEB_URL` | adresse de l'espace web ouverte par le lien des réglages ; par défaut, la valeur de `API_URL` |

Utilisation :

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

| Où tourne l'application | Valeur de `API_URL` |
|---|---|
| Navigateur (Chrome) ou ordinateur | `http://127.0.0.1:8000` (valeur par défaut) |
| Émulateur Android Studio | `http://10.0.2.2:8000` (valeur par défaut) |
| Émulateur Genymotion | adresse du PC sur le réseau de l'émulateur, ex. `http://192.168.113.2:8000` |
| Téléphone sur le même Wi-Fi que le PC | `http://<IP du PC>:8000` |
| Production | `https://votre-domaine` |

- **Android Studio / IntelliJ** : Run › Edit Configurations › *Additional run args* → `--dart-define-from-file=env.json`.
- **VS Code** : dans `.vscode/launch.json`, `"args": ["--dart-define-from-file=env.json"]`.
- Un changement d'adresse demande un **redémarrage complet** (pas de hot reload).
- Sur le web, l'origine de l'application doit être autorisée par `CORS_ALLOWED_ORIGINS` dans le `.env` du backend.

## Lancer le projet

```bash
flutter pub get
dart run tool/patch_android.dart      # permissions réseau, ouverture de liens (à relancer après un `flutter create`)
flutter run --dart-define-from-file=env.json
```

Si le dossier `android/` n'existe pas encore : `flutter create --platforms=android --project-name caisse_offline .`
puis `dart run tool/patch_android.dart`.

Support web : `sqflite_common_ffi_web` est configuré dans `lib/main.dart` ; les fichiers `web/sqflite_sw.js` et
`web/sqlite3.wasm` se régénèrent avec `dart run sqflite_common_ffi_web:setup`. Sur le web, les données sont
conservées dans le navigateur.

Tests : `flutter test`.

## Connexion au compte

La connexion se fait en deux étapes, pour qu'un mot de passe volé ne suffise pas à connecter un autre téléphone :

1. Dans **Réglages**, saisir l'e-mail et le mot de passe du compte (créé sur l'espace web, adresse e-mail confirmée).
2. Un **code à 6 chiffres** s'affiche dans l'espace web du compte, avec le nom de l'appareil et un bouton
   « Ce n'est pas moi ». Le saisir dans l'application pour confirmer la connexion.

Le code expire au bout de quelques minutes et le nombre d'essais est limité. Si la demande est annulée depuis
l'espace web, l'application en est informée et abandonne la connexion. Détails et schéma :
`docs/api-contract.md` et la documentation du backend.

## Serveur de démonstration

Lorsque le backend est déployé en **mode démonstration** (`DEMO_MODE=true`), la connexion de l'application mobile
est volontairement refusée pour ses comptes fictifs : l'application reste alors pleinement utilisable en
**mode local, hors ligne**, sans compte. Pour essayer la synchronisation complète, utilisez votre propre
installation du backend (voir le README du backend et `docs/demo.md`).

## Principe offline-first

L'application **lit et écrit toujours dans SQLite**, jamais directement sur le serveur.

```
UI ──► Repositories ──► SQLite (source de vérité locale)
                          │
                          └─► table outbox (modifications à envoyer)
                                     │
                          SyncService │ push → serveur
                                     │ pull ← serveur ──► ChangeApplier ──► SQLite
```

| Sujet | Choix | Raison |
|---|---|---|
| Identifiants | UUID v4 générés par l'application | créer des données hors ligne sans collision |
| Écriture | donnée + entrée `outbox` dans **la même transaction** | jamais de donnée sans trace à synchroniser |
| Suppression | logique (`deleted_at`) | pouvoir la propager aux autres appareils |
| Envoi | par lots, idempotent | un envoi interrompu peut être rejoué sans doublon |
| Conflits | la dernière écriture gagne (`updated_at`) | simple, prévisible, documenté |
| Curseur de pull | fourni par le serveur (révision par utilisateur) | insensible aux horloges de téléphones décalées |
| Ventes | articles embarqués dans la vente | une vente est synchronisée de façon atomique |
| Déclencheurs | retour réseau, 2 s après une écriture, toutes les 2 min, bouton manuel | réactif sans surcharger |

Contrat d'API : [`docs/api-contract.md`](docs/api-contract.md).

## Limites et pistes

- Conflits : « dernière écriture gagne » au niveau de l'entité entière.
- Les horodatages `updated_at` viennent de l'horloge de l'appareil.
- Synchronisation seulement application ouverte (pas de tâche de fond).
- Pas de multi-boutiques ni de gestion de stock.
