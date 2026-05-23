# Test Gaps & Coverage Report

Generated: 2026-05-11

## Test Suite Summary

- **Total tests:** 576
- **Assertions:** 1689
- **Failures:** 0
- **Errors:** 0
- **Skipped:** 4 (all in `discovery_service_test.rb` due to mDNS/DNSSD unavailability)

## Coverage Overview

- **Overall line coverage:** **69.24%** (2,580 / 3,726 lines)
- **SimpleCov minimum target:** 70.00% (currently failing by 0.76%)

### Coverage by Group

| Group | Coverage | Lines (covered / total) |
|-------|----------|------------------------|
| API V1 Controllers | 63.77% | 755 / 1,184 |
| Services | 77.66% | 365 / 470 |
| Channels | 80.13% | 125 / 156 |

---

## Failing Tests

### Before Fix

| Test | File | Error |
|------|------|-------|
| `test_first_user_should_become_admin` | `test/controllers/users_controller_test.rb:90` | `ActiveRecord::RecordNotFound: Couldn't find Channel with [WHERE "channels"."id" = ?]` |

**Root cause:** `User.destroy_all` in the test cascaded to destroy `created_channels` (via `dependent: :destroy`), which destroyed `channel_memberships`. The `ChannelMembership#broadcast_member_count` `after_commit` callback tried to `channel.reload` after the channel was already deleted in the same transaction.

**Fix applied:** Added `rescue ActiveRecord::RecordNotFound` to `app/models/channel_membership.rb#broadcast_member_count` so that destroyed channels gracefully skip broadcasting.

### After Fix

- `bin/docker-dev bin/rails test` passes with **0 failures, 0 errors**.
- The same fix also resolves the failure when running single-threaded (`PARALLEL_WORKERS=1`) for coverage.

---

## Untested / Under-tested Critical Paths

### API V1 Controllers (`app/controllers/api/v1/`)

| Controller | Coverage | Status | Risk |
|------------|----------|--------|------|
| `csp_reports_controller.rb` | **0.0%** | No tests | Medium — security reporting endpoint |
| `e2ee_controller.rb` | **0.0%** | No tests | High — end-to-end encryption key management |
| `fcm_controller.rb` | **0.0%** | No tests | Medium — push token registration |
| `health_controller.rb` | **0.0%** | No tests | Low — simple health check |
| `metrics_controller.rb` | **0.0%** | No tests | Medium — Prometheus / server metrics |
| `user_keys_controller.rb` | **0.0%** | No tests | High — user E2EE key management |
| `auth_controller.rb` | 66.25% | Partial | Medium — API authentication & token refresh |
| `messages_controller.rb` | 68.33% | Partial | High — core messaging API |
| `link_preview_service.rb` | 48.1% | Partial | Low — external URL fetching |

**Fully covered:** `channels_controller.rb` (87.8%), `bots_controller.rb` (88.9%), `webhooks_controller.rb` (83.9%), `search_controller.rb` (92.9%), `users_controller.rb` (95.0%), `keys_controller.rb` (81.0%), `server_info_controller.rb` (100%), `two_factor_controller.rb` (98.1%).

### Services (`app/services/`)

| Service | Coverage | Status | Risk |
|---------|----------|--------|------|
| `link_preview_service.rb` | **48.1%** | Partial | Low — external URL fetching, error paths untested |
| `discovery_service.rb` | **68.9%** | Partial | Low — LAN discovery; 4 tests skipped due to mDNS |
| `fcm_notification_service.rb` | **74.5%** | Partial | Medium — push notification delivery |
| `message_broadcaster.rb` | **81.3%** | Partial | High — core real-time message broadcasting |
| `e2ee_policy.rb` | **91.7%** | Good | High — E2EE validation logic |
| `bots/dispatcher.rb` | **87.9%** | Good | Medium — bot message dispatch |
| `lite_llm/client.rb` | **96.7%** | Excellent | Medium — LLM API client |

### Channels (`app/channels/`)

| Channel | Coverage | Status | Risk |
|---------|----------|--------|------|
| `chat_channel.rb` | **66.7%** | Partial | High — main real-time chat subscription |
| `presence_channel.rb` | **89.3%** | Good | Medium — online/offline presence |
| `typing_channel.rb` | **100.0%** | Excellent | Low — typing indicators |
| `application_cable/connection.rb` | **84.9%** | Good | High — WebSocket auth & connection setup |
| `application_cable/channel.rb` | **100.0%** | Excellent | Low — base channel class |

---

## Recommendations — Tests to Add Next

### 1. Zero-coverage API controllers (highest priority)

- **`test/controllers/api/v1/csp_reports_controller_test.rb`** — Test CSP report ingestion endpoint.
- **`test/controllers/api/v1/e2ee_controller_test.rb`** — Test key bundle upload, device registration, and rotation endpoints.
- **`test/controllers/api/v1/user_keys_controller_test.rb`** — Test CRUD for user E2EE keys.
- **`test/controllers/api/v1/fcm_controller_test.rb`** — Test FCM token registration and unregistration.
- **`test/controllers/api/v1/metrics_controller_test.rb`** — Test Prometheus metrics endpoint (ensure it renders metrics text without auth if public, or with auth if protected).

### 2. Low-coverage API controllers

- **`test/controllers/api/v1/auth_controller_test.rb`** — Fill gaps around token refresh, expiry handling, and error paths.
- **`test/controllers/api/v1/messages_controller_test.rb`** — Add tests for E2EE message creation, editing, deletion, and search-within-channel edge cases.

### 3. Service layer gaps

- **`test/services/link_preview_service_test.rb`** — Add tests for network timeout, invalid URLs, non-HTML responses, and OpenGraph parsing edge cases.
- **`test/services/fcm_notification_service_test.rb`** — Add tests for FCM delivery failure handling, invalid tokens, and batch send edge cases.
- **`test/services/discovery_service_test.rb`** — Stub/mocks for DNSSD so the 4 skipped tests can run without a real mDNS daemon.

### 4. Channel layer gaps

- **`test/channels/chat_channel_test.rb`** — Add tests for:
  - Subscription rejection when user is banned / not approved.
  - `speak` with `thread_id` (threaded messages).
  - Message edit and delete actions via ActionCable.
  - E2EE payload validation failure paths (missing `device_id`, bad fingerprint).

### 5. Coverage threshold

- Bring overall coverage from **69.24%** to **≥ 70%** by adding the zero-coverage controller tests above. Adding just the 6 fully-untested API controllers (~1,184 lines total) would likely push coverage above the threshold if roughly 50% of their lines are exercised.

---

## Files Modified

- `app/models/channel_membership.rb` — Added `rescue ActiveRecord::RecordNotFound` in `broadcast_member_count` to handle cascade-deleted channels during `User.destroy_all`.
