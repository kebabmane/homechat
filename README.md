# HomeChat

Self‑hosted chat for Home Assistant households. Built on Rails 8, SQLite, Tailwind, and Hotwire.

## Offline‑First (No Internet)

HomeChat is designed to run on a LAN with zero Internet connectivity.

- No external CDNs or fonts; JS is served via Importmap and the app assets.
- Database‑backed ActionCable (Solid Cable) — no Redis required.
- PWA enabled (manifest + service worker) to cache app shell assets for resiliency.
- Optional outbound integrations (push, bots) can be enabled later; they are off by default.

## Quick Start (Dev)

1) Install Ruby 3.3 and Bundler, then:

```
bin/setup --skip-server
bin/dev    # runs Rails + Tailwind watcher
```

Visit http://localhost:3000. First user to sign up is promoted to admin automatically.

## Tests

```
bin/rails db:prepare
bin/rails test       # unit + integration + system (JS)
```

## Configuration

- **Server Settings** (Admin): `/admin/settings`
  - Site name
  - Allow sign‑ups (disable to lock down)
- **Integration Settings** (Admin): `/admin/integrations`
  - API token management for Home Assistant
  - Bot configuration and webhook URLs
  - Connection testing and monitoring
- **User Settings**: `/settings`
  - Username, password
  - Enter‑to‑send (local device preference)

## Deployment

HomeChat runs well in isolated environments (VPS, Raspberry Pi, home server).

- Build Docker images on a machine with Internet access, then run offline.
- Expose only port 3000 inside your LAN; DNS not required.
- Back up SQLite DB and storage volumes regularly.

## Home Assistant Integration

HomeChat includes a **complete Home Assistant integration** for two-way communication:

### Features
- **Send notifications** from HA automations to HomeChat
- **Interactive bot commands** - control HA from chat messages
- **Multiple message types** - alerts, device updates, automation reports
- **Room targeting** - send messages to specific channels
- **Rich formatting** - priority levels, timestamps, device context

### Quick Setup
1. **Deploy HomeChat** via Home Assistant addon or Docker
2. **Enable integration** in addon configuration or `/admin/integrations`
3. **Install HA integration** in `custom_components/homechat/`
4. **Configure connection** with auto-generated API token

See [`INTEGRATION_SETUP.md`](../INTEGRATION_SETUP.md) for detailed instructions.

### ⚠️ Security Trade-offs (Current Implementation)

**Current API model prioritizes simplicity for home use:**
- ✅ **Easy setup** - single API token for all functionality
- ⚠️ **Broad access** - token can post to any channel/room
- ⚠️ **System-level permissions** - no granular channel restrictions

**Appropriate for:** Home deployments on trusted networks where convenience > granular security.

**Future enhancements planned:** Channel-scoped tokens, role-based permissions, audit logging.

## Roadmap

- ✅ **Home Assistant Integration** - Two-way communication with HA
- ✅ **Direct messages, media uploads, and bot APIs**  
- ✅ **Rich text and mentions**
- 🔄 **Enhanced security** - Channel-scoped API tokens, granular permissions
- 📅 **Mobile push notifications** (optional; opt‑in with FCM/APNs keys)
- 📅 **Advanced HA features** - entity control, state sync, voice commands
