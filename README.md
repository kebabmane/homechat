# HomeChat

Self‑hosted chat application built on Rails 8, SQLite, Tailwind, and Hotwire. Perfect for households, teams, or anyone wanting private communication that works completely offline.

## 🏗️ Project Architecture

HomeChat is designed as **three complementary repositories** that work together:

### 🚀 **Core Application** (This Repository)
**Standalone chat server** - Use HomeChat independently as a private chat platform:
- Complete web-based chat interface
- User management and channels
- Real-time messaging with WebSockets
- File sharing and rich media support
- Works completely offline on your local network

### 🏠 **Home Assistant Add-on** ([homechat-addon](https://github.com/kebabmane/homechat-addon))
**Easy deployment** - Install HomeChat directly in Home Assistant:
- One-click installation via Home Assistant Supervisor
- Automatic configuration and API token generation
- Integrated with Home Assistant's security and networking
- Perfect for Home Assistant users who want zero-configuration setup

### 🔌 **Home Assistant Integration** ([homechat-integration](https://github.com/kebabmane/homechat-integration))
**Smart home communication** - Connect your automations to HomeChat:
- Send Home Assistant notifications to chat rooms
- Create interactive bot commands from chat messages
- Rich formatting for device alerts and status updates
- Two-way communication between HA and HomeChat

## 🎯 **Choose Your Deployment**

| **Deployment Option** | **Best For** | **Setup Complexity** | **HA Integration** |
|----------------------|--------------|---------------------|-------------------|
| **Standalone Docker** | Local testing, development | Low | Optional |
| **HA Add-on Only** | HA users wanting private chat | Easy | Optional |
| **Cloud (Kamal)** | Production, teams, public access | Medium | Optional |
| **HA Add-on + Integration** | Smart home automation | Easy | Full featured |

> **💡 HomeChat works great standalone!** You don't need Home Assistant to use HomeChat as your private family/team chat platform.

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

## 🚀 Deployment Options

### Option 1: Standalone Docker (Any User)
Perfect for teams, families, or anyone wanting private chat without Home Assistant:

```bash
# Simple Docker run
docker run -d \
  -p 3000:3000 \
  -v homechat_data:/data \
  -v homechat_storage:/app/storage \
  --name homechat \
  ghcr.io/kebabmane/homechat:latest

# Or with Docker Compose
curl -O https://raw.githubusercontent.com/kebabmane/homechat/main/docker-compose.yml
docker-compose up -d
```

Visit `http://localhost:3000` and sign up - first user becomes admin automatically.

### Option 2: Home Assistant Add-on (HA Users)
Install directly in Home Assistant for integrated deployment:

1. **Add Repository**: Settings > Add-ons > ⋮ > Repositories > Add `https://github.com/kebabmane/homechat-addon`
2. **Install Add-on**: Find "HomeChat" in the add-on store and install
3. **Configure & Start**: Set your preferences and start the add-on
4. **Access**: Available in Home Assistant sidebar or direct URL

### Option 3: Cloud Deployment with Kamal (Production)
Deploy to any cloud provider (AWS, GCP, DigitalOcean, Vultr, Hetzner) with zero-downtime deployments:

```bash
# Quick cloud deployment
git clone https://github.com/kebabmane/homechat.git
cd homechat

# Configure your servers in config/deploy.yml
bin/kamal setup    # Initial deployment
bin/kamal deploy   # Deploy updates
```

**Features:**
- ✅ **Zero-downtime deployments** with health checks
- ✅ **Automatic SSL** certificates via Let's Encrypt  
- ✅ **Multi-server scaling** for high availability
- ✅ **Environment management** (staging/production)
- ✅ **One-command deployments** and rollbacks

See [`KAMAL_DEPLOYMENT.md`](KAMAL_DEPLOYMENT.md) for detailed cloud deployment guide.

### Option 4: Full Smart Home Integration (HA + Automation)
Add the Home Assistant integration for automation features:

1. **Deploy HomeChat** (via add-on, Docker, or Kamal)
2. **Install Integration**: Copy `homechat-integration` to `custom_components/homechat/`
3. **Configure**: Settings > Integrations > Add "HomeChat" integration
4. **Automate**: Use `notify.homechat` service in your automations

See [`INTEGRATION_SETUP.md`](INTEGRATION_SETUP.md) for detailed setup instructions.

### 💾 Data & Backup
- **Database**: SQLite stored in `/data/production.sqlite3`
- **Uploads**: Files stored in `/data/storage/` 
- **Backup**: Regular backups of data volume recommended
- **Portability**: Entire application state in two directories

## 🤖 Home Assistant Integration (Optional)

**Note**: HomeChat works perfectly as a standalone chat platform. The Home Assistant integration is completely optional and adds smart home automation features.

### Integration Features
- **📱 Smart Notifications**: Send HA automation alerts to specific chat rooms
- **🗣️ Interactive Commands**: Control HA devices from chat messages  
- **🎨 Rich Formatting**: Priority levels, device context, timestamps
- **🔄 Two-way Communication**: HomeChat ↔ Home Assistant event flow
- **🎯 Room Targeting**: Route different alerts to appropriate channels

### Integration Example
```yaml
# Home Assistant Automation
automation:
  - alias: "Motion Alert"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door
      to: "on"
    action:
      service: notify.homechat
      data:
        message: "Front door motion detected"
        title: "🚪 Security Alert"
        target: "security"
        data:
          priority: "high"
```

### Repository Links
- **📦 HomeChat Add-on**: [kebabmane/homechat-addon](https://github.com/kebabmane/homechat-addon)
- **🔌 HA Integration**: [kebabmane/homechat-integration](https://github.com/kebabmane/homechat-integration)
- **📖 Setup Guide**: [INTEGRATION_SETUP.md](INTEGRATION_SETUP.md)

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
