# Contrat d'API

Base : `{SERVEUR}/api` (ex. `http://192.168.1.10:8000/api`). L'adresse du serveur est fixée dans
l'application mobile à la compilation (`--dart-define-from-file=env.json`), jamais saisie par l'utilisateur.

- Format : JSON. Dates en ISO 8601 UTC avec `Z` (ex. `2026-10-17T10:15:30.000Z`).
- Les routes protégées exigent `Authorization: Bearer <jeton>`.
- Les montants sont des entiers en FCFA (sans décimales).

## Format des erreurs

Toute erreur de l'API est un objet JSON dont le `message` est destiné à l'utilisateur final
(français, explicite) et le `code` est un identifiant stable sur lequel l'application peut s'appuyer.
Les erreurs de validation (`422`) ajoutent le détail par champ dans `errors`.

```json
{ "message": "Adresse e-mail ou mot de passe incorrect.", "code": "invalid_credentials" }
```

| Statut | Codes | Signification |
|---|---|---|
| 401 | `unauthenticated`, `invalid_credentials` | jeton absent ou invalide ; identifiants incorrects |
| 403 | `email_not_verified`, `account_banned`, `admin_not_allowed`, `challenge_denied`, `forbidden_role`, `forbidden`, `invalid_signature`, `demo_mobile_disabled`, `demo_expired`, `demo_emails_disabled` | accès refusé (le message précise la raison, par ex. le motif de suspension) |
| 404 | `not_found`, `challenge_not_found` | ressource ou demande de connexion introuvable |
| 405 | `method_not_allowed` | méthode HTTP non autorisée |
| 409 | `challenge_used` | code de connexion déjà utilisé |
| 410 | `challenge_expired` | code expiré ou remplacé par une demande plus récente |
| 422 | `invalid_code` + erreurs de validation | code incorrect (le message indique le nombre d'essais restants) ; données invalides |
| 429 | `too_many_requests`, `too_many_login_requests`, `challenge_locked` | limitation de débit ; trop de demandes ; trop de codes erronés |
| 500 | `server_error` | erreur interne (aucun détail technique n'est exposé) |

## Authentification de l'application mobile (en deux étapes)

Une connexion exige à la fois le mot de passe **et** un code à 6 chiffres affiché dans l'espace web du
propriétaire du compte (voir [security.md](security.md)).

### `POST /auth/login`

Vérifie les identifiants et crée une demande de connexion. **Aucun jeton n'est émis à cette étape.**

```json
// requête
{ "email": "awa@exemple.com", "password": "…", "device_name": "Ma Caisse (android)" }
// réponse 202
{
  "challenge_id": "6f1c…",
  "expires_at": "2026-10-20T10:25:00+00:00",
  "expires_in": 600,
  "code_length": 6,
  "message": "Pour confirmer cette connexion, ouvrez votre espace web Ma Caisse : un code à 6 chiffres y est affiché. Saisissez-le ici."
}
```

Refus possibles : compte inexistant ou mot de passe faux (`401`), adresse e-mail non confirmée,
compte suspendu, compte administrateur (`403`), quota de demandes horaire dépassé (`429`).

### `POST /auth/login/confirm`

```json
// requête
{ "challenge_id": "6f1c…", "code": "482913" }
// réponse 200
{ "token": "1|abc…", "user": { "name": "Awa", "email": "awa@exemple.com" } }
```

Le code est à usage unique, valable quelques minutes (`MOBILE_LOGIN_CODE_TTL_MINUTES`) et limité en
nombre d'essais (`MOBILE_LOGIN_MAX_ATTEMPTS`) : au-delà, la demande est verrouillée.

### `GET /auth/login/status?challenge_id=…`

```json
{ "status": "pending" }   // pending | approved | denied | expired | locked
```

L'application l'interroge pendant que l'utilisateur saisit le code, afin d'être informée d'une
annulation (« Ce n'est pas moi » dans l'espace web) ou d'une expiration.

### `POST /auth/logout`

Révoque le jeton courant (appareil déconnecté).

## Synchronisation

Les routes `/sync/*` exigent un jeton valide, une adresse e-mail confirmée, un compte non suspendu et
le rôle « commerçant ».

### `POST /sync/push`

L'application envoie ses modifications locales (instantanés complets, suppressions incluses via `deleted_at`).

```json
{
  "operations": [
    { "entity": "product", "id": "uuid", "updated_at": "…Z", "data": { } },
    { "entity": "sale",    "id": "uuid", "updated_at": "…Z", "data": { } }
  ]
}
```

Réponse 200 :

```json
{
  "accepted": ["uuid", "uuid"],
  "rejected": [{ "id": "uuid", "reason": "Le total ne correspond pas aux articles." }]
}
```

Règles serveur :

- **Idempotence** : renvoyer deux fois la même opération ne crée rien en double (upsert sur l'UUID).
- **Dernière écriture gagne** : si la version du serveur a un `updated_at` plus récent, l'opération est ignorée
  mais comptée dans `accepted` (l'application ne doit pas la renvoyer ; elle recevra la version du serveur au
  prochain pull).
- Chaque écriture reçoit un **numéro de révision** propre à l'utilisateur, qui sert de curseur de pull.
- Un `id` déjà utilisé par un autre compte est refusé (`rejected`).
- Pour une vente, le serveur vérifie que `total` = somme de `unit_price × quantity`.
- Une opération invalide n'empêche pas les autres : chacune est traitée dans sa propre transaction.

### `GET /sync/pull?since=<curseur>&limit=<n>`

Sans `since` : tout l'historique. `limit` : 1 à 500 (200 par défaut).

```json
{
  "changes": [ { "entity": "sale", "id": "uuid", "data": { } } ],
  "cursor": "42",
  "has_more": false
}
```

`cursor` est le dernier numéro de révision reçu (texte) ; il reste inchangé s'il n'y a rien de nouveau.
L'application le renvoie dans `since` au prochain pull. Si `has_more` vaut `true`, elle rappelle aussitôt.
Les changements sont triés par révision croissante, toutes entités confondues.

## Formes de `data`

```json
// product
{ "id": "uuid", "name": "Riz (1 kg)", "price": 750,
  "created_at": "…Z", "updated_at": "…Z", "deleted_at": null }

// sale (les articles sont embarqués et remplacés en bloc à chaque mise à jour)
{ "id": "uuid", "total": 1350, "note": null, "sold_at": "…Z",
  "created_at": "…Z", "updated_at": "…Z", "deleted_at": null,
  "items": [
    { "id": "uuid", "product_id": "uuid|null", "product_name": "Savon", "unit_price": 300, "quantity": 2 }
  ] }

// expense
{ "id": "uuid", "category": "Transport", "amount": 1500, "note": null,
  "spent_at": "…Z", "created_at": "…Z", "updated_at": "…Z", "deleted_at": null }
```

`product_id` d'un article n'est pas une clé étrangère côté serveur : le produit peut avoir été supprimé
ou ne pas encore être synchronisé.

## Santé

`GET /ping` → `{ "ok": true, "app": "Ma Caisse API", "time": "…" }` (sans authentification).
