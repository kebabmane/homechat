# HomeChat

[![Build Status](https://github.com/kebabmane/homechat/workflows/CI/badge.svg)](https://github.com/kebabmane/homechat/actions)
[![Ruby](https://img.shields.io/badge/ruby-4.0+-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-8.1-red.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Self-hosted, offline-first chat for households and teams. Built with Rails 8, SQLite, and Hotwire.

HomeChat is a private chat platform that works completely offline on your local network. No cloud dependencies, no subscriptions, no data leaving your home. Perfect for families, teams, or anyone wanting secure, private communication.

## Features

| Feature | Description |
|---------|-------------|
| **Offline-First** | Works on LAN without internet. No external CDNs, fonts, or dependencies. |
| **Real-Time** | Instant messaging via WebSockets (ActionCable with Solid Cable). |
| **Mobile Ready** | Native iOS and Android apps with offline sync. PWA support for browsers. |
| **AI Assistants** | LLM-powered bots via LiteLLM (supports Ollama, OpenAI, and more). |
| **Smart Home** | Two-way Home Assistant integration for automation notifications. |
| **File Sharing** | Image uploads, attachments, and rich media support. |
| **Security** | 2FA, API tokens, rate limiting, audit logging, account lockout. |

## Quick Start

### Option 1: Docker (Recommended)

```bash
docker run -d \
  -p 3000:3000 \
  -v homechat_data:/data \
  -v homechat_storage:/app/storage \
  --name homechat \
  ghcr.io/kebabmane/homechat:latest
```

Visit `http://localhost:3000` — first user to sign up becomes admin.

### Option 2: Home Assistant Add-on

1. Add repository: `https://github.com/kebabmane/homechat-addon`
2. Install "HomeChat" from the add-on store
3. Start and access from the HA sidebar

See the [HomeChat Add-on](https://github.com/kebabmane/homechat-addon) repository for details.

### Option 3: Development

```bash
git clone https://github.com/kebabmane/homechat.git
cd homechat
bin/setup --skip-server
bin/dev
```

Visit `http://localhost:3000`

## Deployment Options

| Option | Best For | Complexity | Features |
|--------|----------|------------|----------|
| **Docker** | Local/dev use, small teams | Low | Full features |
| **HA Add-on** | Home Assistant users | Easy | HA integration |
| **Kamal** | Production, cloud hosting | Medium | SSL, scaling, zero-downtime |

See [Deployment Guide](docs/deployment/) for detailed instructions.

## Documentation

| Section | Description |
|---------|-------------|
| [Getting Started](docs/getting-started/) | Installation, first steps, configuration |
| [Architecture](docs/architecture/) | System design, database schema, data flow |
| [API Reference](docs/api/) | REST API, WebSocket API, webhooks |
| [Deployment](docs/deployment/) | Docker, Kamal, Home Assistant |
| [Security](docs/security/) | Hardening guide, API tokens, 2FA |
| [Development](docs/development/) | Local setup, testing, contributing |
| [Operations](docs/operations/) | Backup, monitoring, troubleshooting |

## Home Assistant Integration

HomeChat integrates with Home Assistant for smart home notifications:

```yaml
# Example automation
automation:
  - alias: "Motion Alert"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door
      to: "on"
    action:
      service: notify.homechat
      data:
        message: "Motion detected at front door"
        target: "security"
```

**Repositories:**
- [homechat-addon](https://github.com/kebabmane/homechat-addon) — Home Assistant add-on
- [homechat-integration](https://github.com/kebabmane/homechat-integration) — HA custom component

See [Integration Setup](docs/deployment/home-assistant.md) for full guide.

## Technology Stack

| Component | Technology |
|-----------|------------|
| Backend | Ruby 4.0, Rails 8.1 |
| Database | SQLite 3 |
| Real-time | ActionCable (Solid Cable) |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS |
| Assets | Propshaft, Importmap |
| Deployment | Docker, Kamal |
| Mobile | Swift (iOS), Kotlin (Android) |

## Data & Storage

```
/data/
├── production.sqlite3    # Database
├── storage/              # File uploads
└── secret_key_base       # Encryption key
```

- **Portable**: Entire app state in `/data`
- **Backup**: Copy the data directory to back up everything
- **No dependencies**: SQLite, no external database required

## Configuration

### Server Settings (Admin)

Access `/admin/settings` to configure:
- Site name and branding
- User registration (open/closed)
- LiteLLM proxy for AI bots

### AI Bots (Admin)

Access `/admin/bots` to:
- Create LLM-powered assistants with custom prompts
- Configure webhook integrations
- Manage bot permissions and channels

### User Settings

Access `/settings` to configure:
- Username and password
- Two-factor authentication
- Timezone and preferences

## Security

HomeChat includes enterprise-grade security features:

- **Authentication**: bcrypt password hashing, optional 2FA (TOTP)
- **API Tokens**: Secure, hashed tokens with prefix identification
- **Rate Limiting**: Rack::Attack middleware protection
- **Audit Logging**: Track user actions and API access
- **Account Lockout**: Automatic lockout after failed attempts

See [Security Hardening Guide](docs/security/hardening-guide.md) for production deployment.

## Tests

```bash
bin/rails test           # Run all tests
bin/rails test:system    # System tests with browser
COVERAGE=true bin/rails test  # With coverage report
```

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Related Projects

| Repository | Description |
|------------|-------------|
| [homechat-addon](https://github.com/kebabmane/homechat-addon) | Home Assistant add-on |
| [homechat-integration](https://github.com/kebabmane/homechat-integration) | HA custom component |
| [homechat-android](https://github.com/kebabmane/homechat-android) | Android app |
| [homechat-ios](https://github.com/kebabmane/homechat-ios) | iOS app |

## License

MIT License. See [LICENSE](LICENSE) for details.
