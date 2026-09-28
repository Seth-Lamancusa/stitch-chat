# stitch-chat cloud authentication

Opaque session auth aligned with the Stitch backend. See backend
[`stitch-backend/_docs/auth.md`](../../stitch-backend/_docs/auth.md) for the
server model.

## Model

| Concern | stitch-chat | Vue SPA |
|---------|-------------|---------|
| Login | `POST /v1/auth/password/login` | same |
| Session secret | Body `access_token` (`st_session_{id}.{secret}`) | HttpOnly `stitch_session` cookie |
| Storage | `flutter_secure_storage` (Keychain / Keystore / libsecret / DPAPI) | Browser cookie jar |
| API calls | `Authorization: Bearer …` via `StitchHttpClient` | `withCredentials: true` |

No JWTs. No access/refresh token pair. `POST /v1/auth/sessions/refresh` extends
the **same** opaque token in place (optional).

## Layers

```
ui/auth/LoginViewModel + login modal
        ↓
data/repositories/AuthRepository (StitchAuthRepository)
        ↓
SessionVault  |  AuthApiClient  |  StitchHttpClient (Bearer + 401)
```

- **Local-first:** chat works without cloud sign-in.
- **Identity ⊥ session:** [`LocalIdentityService`](../lib/data/services/local_identity_service.dart)
  keeps a stable offline uid. When `authenticatedOnline`, `currentUserId`
  uses the live cloud subject uid. After the first successful login, that uid
  is persisted (`cloud_user_id.txt`); if the session later fails, `currentUserId`
  still resolves to the stored cloud id so "You" labels and author stamps stay
  canonical. Callers do not change.

## Config

**Default:** `https://api.stitch.fyi` (hardcoded production).

**Dev override:** set `STITCH_API_URL` in the environment or project-root `.env`:

```
STITCH_API_URL=http://localhost:8081
```

Shipped builds need no env var — they hit production. Only developers who want a
local backend set the override.

## Lifecycle

1. Cold start: `AuthRepository.init()` reads the vault; if a token exists,
   validates with `GET /v1/auth/session` (+ `/users/me`). Failure → clear vault → anonymous.
2. Login: mint → write vault → hydrate state.
3. On successful auth (login or restored session):
   [`AuthorIdPromotion`](../lib/data/services/author_id_promotion.dart)
   rewrites any local message `author_id` (and related stitch/recipient
   stamps) still bearing [`LocalIdentityService.localUserId`](../lib/data/services/local_identity_service.dart)
   to the cloud subject uid. Idempotent — later logins only touch leftover
   local stamps (e.g. messages sent while signed out).
4. Reuse Bearer; do not mint per request.
5. On HTTP **401**: `StitchHttpClient` single-flights `handleUnauthorized` → clear vault → anonymous (+ notification).

## Managed sessions (later)

Vault already reserves `stitch_mgr_session_token`. Actor/subject/`delegated` are
on `AuthState` so act-as can plug in without changing the HTTP interceptor.

## Tests

- `test/data/repositories/auth_repository_test.dart` — vault, HTTP Bearer/401, repository hydrate
- `test/ui/auth/login_viewmodel_test.dart` — ViewModel + LocalIdentity cloud seam + authorship promotion hook
- `test/data/repositories/drift_message_repository_test.dart` — `rewriteAuthorId`
- `test/data/services/author_id_promotion_test.dart` — local→cloud promotion gate
