# Changelog

All notable changes to HomeChat are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation overhaul
- Documentation hub at `docs/index.md`
- Security hardening guide
- Development and testing guides
- Signed E2EE channel key-share validation with per-recipient key epochs.
- E2EE sender-device validation for private-channel and DM writes.

### Changed
- Blank API token scopes are now backfilled to explicit scopes instead of retaining legacy full-access behavior.
- Private channels and DMs reject plaintext writes from legacy clients, bots, and Home Assistant automation integrations.
- Two-factor model boot no longer queries the database schema, allowing production asset builds before add-on database setup.

## [1.0.0] - 2025-01-10

### Added

#### Core Features
- Real-time messaging with ActionCable and Solid Cable
- Public and private channels
- Direct messages between users
- File uploads and image sharing (Active Storage)
- Rich text formatting with Action Text
- User mentions (@username)
- Message search functionality

#### User Management
- User registration with admin approval option
- Role-based access (admin/user)
- Two-factor authentication (TOTP)
- Account lockout after failed attempts
- User presence and online status
- Timezone preferences

#### AI Integration
- LiteLLM-powered AI bots
- Custom bot prompts and personas
- Bot mention system (@botname)
- Webhook-based bot communication

#### Home Assistant Integration
- Two-way communication with Home Assistant
- API token authentication
- Webhook support for HA automations
- Message priority and type formatting

#### Security
- bcrypt password hashing
- API token system with hashed storage
- Rate limiting with Rack::Attack
- Audit logging for admin actions
- CSRF protection
- Secure session management

#### Deployment
- Docker container support
- Home Assistant add-on packaging
- Kamal deployment configuration
- Multi-architecture builds (amd64, arm64)

#### API
- RESTful API for all features
- WebSocket API via ActionCable
- OpenAPI/Swagger documentation (rswag)
- Bearer token authentication

#### Mobile
- PWA support with offline caching
- mDNS/Zeroconf server discovery
- FCM push notification support
- Native iOS app (Swift/SwiftUI)
- Native Android app (Kotlin/Compose)

### Technical Details
- Ruby 3.3, Rails 8.0
- SQLite database
- Tailwind CSS styling
- Hotwire (Turbo + Stimulus)
- Propshaft asset pipeline
- Importmap for JavaScript

---

## Version History

For older changes and detailed commit history, see the [GitHub Releases](https://github.com/kebabmane/homechat/releases) page.
