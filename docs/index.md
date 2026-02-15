# HomeChat Documentation

Welcome to the HomeChat documentation. This guide covers everything from getting started to production deployment.

## Quick Navigation

| I want to... | Go to... |
|--------------|----------|
| Install HomeChat | [Getting Started](getting-started/) |
| Deploy to production | [Deployment Guide](deployment/) |
| Integrate with Home Assistant | [HA Integration](deployment/home-assistant.md) |
| Understand the architecture | [Architecture](architecture/) |
| Use the API | [API Reference](api/) |
| Secure my installation | [Security Guide](security/) |
| Contribute to HomeChat | [Development](development/) |
| Troubleshoot issues | [Operations](operations/) |

## Documentation Sections

### [Getting Started](getting-started/)

New to HomeChat? Start here.

- [Installation](getting-started/installation.md) — All deployment options
- [First Steps](getting-started/first-steps.md) — Initial setup and admin configuration
- [Configuration](getting-started/configuration.md) — Settings reference

### [Architecture](architecture/)

Understand how HomeChat works.

- [System Overview](architecture/overview.md) — High-level design and components
- [Database Schema](architecture/database-schema.md) — Tables, relationships, data model

### [Deployment](deployment/)

Deploy HomeChat for your use case.

- [Docker](deployment/docker.md) — Container deployment
- [Kamal](deployment/kamal.md) — Cloud deployment with zero-downtime
- [Home Assistant](deployment/home-assistant.md) — HA add-on and integration

### [API Reference](api/)

Integrate with HomeChat programmatically.

- [REST API](api/rest-api.md) — HTTP endpoints
- [WebSocket API](api/websocket-api.md) — Real-time messaging with ActionCable

### [Features](features/)

Deep dives into HomeChat capabilities.

- [Offline-First](features/offline-first.md) — How offline sync works
- [AI Bots](features/ai-bots.md) — LiteLLM integration
- [Push Notifications](features/push-notifications.md) — FCM/APNs setup
- [LAN Discovery](features/lan-discovery.md) — mDNS/Zeroconf

### [Security](security/)

Secure your HomeChat installation.

- [Hardening Guide](security/hardening-guide.md) — Production security checklist
- [API Tokens](security/api-tokens.md) — Token management
- [Two-Factor Auth](security/two-factor-auth.md) — TOTP setup

### [Development](development/)

Contribute to HomeChat.

- [Setup](development/setup.md) — Development environment
- [Testing](development/testing.md) — Running and writing tests
- [Code Style](development/code-style.md) — Conventions and guidelines

### [Operations](operations/)

Run HomeChat in production.

- [Backup & Restore](operations/backup-restore.md) — Data protection
- [Monitoring](operations/monitoring.md) — Health checks and metrics
- [Troubleshooting](operations/troubleshooting.md) — Common issues and solutions

## Related Repositories

| Repository | Description |
|------------|-------------|
| [homechat](https://github.com/kebabmane/homechat) | Core application (this repo) |
| [homechat-addon](https://github.com/kebabmane/homechat-addon) | Home Assistant add-on |
| [homechat-integration](https://github.com/kebabmane/homechat-integration) | HA custom component |
| [homechat-android](https://github.com/kebabmane/homechat-android) | Android app |
| [homechat-ios](https://github.com/kebabmane/homechat-ios) | iOS app |

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/kebabmane/homechat/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kebabmane/homechat/discussions)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.
