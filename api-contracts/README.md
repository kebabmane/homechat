# HomeChat API Contracts

This directory contains the canonical OpenAPI specification for the HomeChat REST API. It serves as the single source of truth for backend-to-mobile contract compatibility.

## Files

- `openapi.yaml` — Canonical OpenAPI 3.0 specification (YAML)
- `openapi.json` — JSON equivalent, generated from `openapi.yaml`

## Why This Exists

The mobile apps (Android and iOS) previously maintained hand-written DTOs that could drift from the Rails backend. This pipeline ensures:

1. **One source of truth**: The OpenAPI spec documents every endpoint, request, and response.
2. **Generated DTOs**: Kotlin and Swift data classes are generated from the spec.
3. **CI enforcement**: Pull requests that touch API controllers trigger validation checks.

## Regenerating the OpenAPI Spec

> **Current Status**: RSwag is installed (`rswag-api`, `rswag-ui`, `rswag-specs`) but there are no RSwag spec files yet. The spec is manually maintained from the controller code.

### Option A: Automatic (when RSwag specs are added)

When RSwag request specs are written under `homechat/spec/requests/api/v1/`, run:

```bash
cd /Users/rhysevans/Projects/homeChat/homechat
bin/docker-dev bin/rails rswag:specs:swaggerize
```

Then copy the generated `swagger/v1/swagger.json` (or `swagger.yaml`) to:

```bash
cp swagger/v1/swagger.yaml api-contracts/openapi.yaml
```

### Option B: Manual (current approach)

Since there are no RSwag specs yet, update `api-contracts/openapi.yaml` manually when:

- Controllers under `homechat/app/controllers/api/v1/` change
- Request/response shapes change
- New endpoints are added

After editing `openapi.yaml`, regenerate `openapi.json`:

```bash
cd /Users/rhysevans/Projects/homeChat/homechat
python3 << 'EOF'
import yaml, json
with open('api-contracts/openapi.yaml') as f:
    spec = yaml.safe_load(f)
with open('api-contracts/openapi.json', 'w') as f:
    json.dump(spec, f, indent=2)
EOF
```

## Regenerating Mobile DTOs

Use the provided script to generate Kotlin and Swift models from the spec:

```bash
cd /Users/rhysevans/Projects/homeChat/homechat
./scripts/generate-mobile-dtos.sh
```

### Platform-specific generation

```bash
# Android only
./scripts/generate-mobile-dtos.sh --android

# iOS only
./scripts/generate-mobile-dtos.sh --ios

# Validate spec first, then generate both
./scripts/generate-mobile-dtos.sh --validate
```

### Output locations

- **Android**: `homechat-android/app/src/main/java/com/homechat/android/data/remote/generated/`
- **iOS**: `homechat-ios/HomeChatIOS/Core/Models/Generated/`

## Handling Breaking API Changes

### 1. Identify the impact

Check which mobile clients consume the changed fields or endpoints.

### E2EE contract notes

E2EE request/response schemas must stay aligned across web, iOS, Android, and macOS:

- Device keys are raw 32-byte Base64 public keys: X25519 for encryption and Ed25519 for signing.
- Key-share responses include `key_epoch`, `recipient_key_fingerprint`, sender device identity, and signature metadata.
- Encrypted private/DM messages carry encrypted content, content HMAC, sender device id, sender key fingerprint, and E2EE version.
- Bots, webhooks, and Home Assistant integrations are not E2EE clients unless their contracts explicitly add device-key publication, key-share handling, local encryption, and signed sender metadata.

### 2. Update the spec first

Always edit `api-contracts/openapi.yaml` **before** modifying controllers (or in the same PR). This makes the contract change visible to reviewers.

### 3. Versioning strategy

- The spec `info.version` should reflect the API version (`1.0.0` currently).
- For breaking changes, increment the version and document the migration path here.

### 4. Coordinate mobile updates

- Run `./scripts/generate-mobile-dtos.sh` to regenerate DTOs.
- Update mobile networking code to use the new generated models (future refactor).
- Currently, the generated DTOs live alongside hand-written ones and are **not** yet wired into the app code.

### 5. CI enforcement

The `api-contract-check.yml` workflow runs on PRs that modify:

- `homechat/app/controllers/api/v1/**`
- `homechat/app/models/**`
- `homechat/config/routes.rb`
- `api-contracts/**`

It validates the spec and runs a smoke-test generation to ensure the spec is parseable.

## Gaps & TODOs

- [ ] Add RSwag request specs under `homechat/spec/requests/api/v1/` to enable automatic spec generation.
- [ ] Wire generated Kotlin DTOs into `homechat-android` networking layer.
- [ ] Wire generated Swift models into `homechat-ios` networking layer.
- [ ] Add schema validation tests that compare controller responses against the spec.
- [ ] Consider adding `swagger-ui` route for browser-based API exploration.

## Endpoints Currently Documented

| Tag | Endpoints |
|-----|-----------|
| Health | `GET /health` |
| Server | `GET /server_info` |
| Metrics | `GET /metrics/health`, `GET /metrics` |
| Authentication | `POST /signin`, `POST /signin/verify_2fa`, `POST /signup`, `DELETE /signout`, `POST /auth/refresh`, `GET /auth/sessions`, `DELETE /auth/sessions/:id` |
| Users | `GET /me`, `PATCH /me`, `POST /me/change_password`, `DELETE /me/avatar` |
| Two-Factor Authentication | `GET /2fa/status`, `POST /2fa/setup`, `POST /2fa/verify`, `POST /2fa/disable`, `GET /2fa/backup_codes`, `POST /2fa/regenerate_backup_codes` |
| Push Notifications | `PUT /fcm_token` |
| Messages | `GET /messages`, `POST /messages`, `DELETE /messages/:id` |
| Search | `GET /search`, `GET /users/search` |
| Channels | `GET /channels`, `POST /channels`, `POST /channels/:id/messages`, `POST /channels/:id/media`, `POST /channels/:id/join`, `DELETE /channels/:id/leave`, `GET /channels/:id/members`, `POST /channels/:id/mark_as_read` |
| Direct Messages | `GET /dm/channels`, `POST /users/:id/messages`, `POST /dm/start` |
| Bots | `GET /bots`, `POST /bots`, `GET /bots/:id`, `PATCH /bots/:id`, `DELETE /bots/:id`, `GET /bots/:id/status`, `POST /bots/:id/activate`, `POST /bots/:id/deactivate` |
| Webhooks | `POST /webhooks/:webhook_id` |
| E2EE | `PUT /me/e2ee_key`, `GET /users/:id/e2ee_key`, `GET /channels/:id/e2ee_keys`, `POST /channels/:id/key_shares`, `GET /channels/:id/key_shares/me`, `POST /channels/:id/rotate_key`, `GET /channels/:id/key_rotation_status`, `POST /channels/:id/acknowledge_rotation` |
