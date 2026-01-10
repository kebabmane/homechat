# Architecture Overview

HomeChat is a self-hosted, offline-first chat application built on Rails 8 with real-time messaging capabilities.

## System Diagram

```mermaid
graph TB
    subgraph "Clients"
        Web[Web Browser<br/>PWA]
        iOS[iOS App<br/>Swift/SwiftUI]
        Android[Android App<br/>Kotlin/Compose]
    end

    subgraph "HomeChat Server"
        Rails[Rails 8 Application]
        Cable[ActionCable<br/>WebSocket]
        API[REST API]
        Jobs[Solid Queue<br/>Background Jobs]
    end

    subgraph "Data Layer"
        SQLite[(SQLite<br/>Database)]
        Storage[Active Storage<br/>File Uploads]
        Cache[Solid Cache]
    end

    subgraph "External Services"
        HA[Home Assistant]
        LiteLLM[LiteLLM<br/>AI Models]
        FCM[Firebase<br/>Push Notifications]
    end

    Web --> Rails
    Web --> Cable
    iOS --> API
    iOS --> Cable
    Android --> API
    Android --> Cable

    Rails --> SQLite
    Rails --> Storage
    Rails --> Cache
    Cable --> SQLite
    Jobs --> SQLite

    Rails --> HA
    Rails --> LiteLLM
    Rails --> FCM
```

## Core Components

### Web Application (Rails 8)

The main application server handles all HTTP requests and WebSocket connections.

| Component | Purpose |
|-----------|---------|
| Controllers | Handle HTTP requests and responses |
| Models | Business logic and data validation |
| Views | HTML templates with Hotwire |
| Channels | ActionCable WebSocket handlers |
| Jobs | Background processing (Solid Queue) |

### Real-Time Messaging

HomeChat uses ActionCable with Solid Cable for real-time updates without Redis:

```mermaid
sequenceDiagram
    participant User1 as User 1
    participant Server as Rails Server
    participant Cable as ActionCable
    participant User2 as User 2

    User1->>Server: POST /messages
    Server->>Server: Create message
    Server->>Cable: Broadcast to channel
    Cable->>User1: Message update
    Cable->>User2: Message update
```

**Key channels:**
- `ChannelChannel` — Channel messages and updates
- `PresenceChannel` — User online/offline status
- `NotificationsChannel` — Personal notifications

### Database Layer

SQLite with Active Record provides:
- Simple deployment (single file database)
- No external dependencies
- Easy backup and portability

See [Database Schema](database-schema.md) for table details.

### File Storage

Active Storage manages file uploads:
- Images with automatic resizing (vips)
- Attachments stored in `/data/storage/`
- Variant generation for thumbnails

### Background Jobs

Solid Queue handles async processing:
- Push notification delivery
- Webhook processing
- Bot message handling

## Data Flow

### Message Flow

```mermaid
flowchart LR
    A[User sends message] --> B[Controller validates]
    B --> C[Model saves to DB]
    C --> D[Broadcast via Cable]
    D --> E[All channel members receive]
    C --> F[Process mentions]
    F --> G[Notify mentioned users]
    C --> H[Trigger bot responses]
```

### Authentication Flow

```mermaid
flowchart TB
    A[Login Request] --> B{Valid credentials?}
    B -->|No| C[Increment failed attempts]
    C --> D{Account locked?}
    D -->|Yes| E[Reject with lockout]
    D -->|No| F[Reject with error]
    B -->|Yes| G{2FA enabled?}
    G -->|Yes| H[Request TOTP code]
    H --> I{Valid code?}
    I -->|Yes| J[Create session]
    I -->|No| C
    G -->|No| J
    J --> K[Set session cookie]
```

### API Authentication

```mermaid
flowchart LR
    A[API Request] --> B{Has Bearer token?}
    B -->|No| C[401 Unauthorized]
    B -->|Yes| D[Extract token prefix]
    D --> E[Find token by prefix]
    E --> F{Token exists & active?}
    F -->|No| C
    F -->|Yes| G[Verify full token hash]
    G --> H{Hash matches?}
    H -->|No| C
    H -->|Yes| I[Process request]
    I --> J[Update last_used_at]
```

## Technology Stack

### Backend

| Technology | Purpose |
|------------|---------|
| Ruby 3.3 | Programming language |
| Rails 8.0 | Web framework |
| SQLite 3 | Database |
| Puma | Application server |
| Solid Cable | ActionCable adapter |
| Solid Queue | Job processing |
| Solid Cache | Caching |

### Frontend

| Technology | Purpose |
|------------|---------|
| Hotwire | SPA-like interactivity |
| Turbo | Navigation and forms |
| Stimulus | JavaScript controllers |
| Tailwind CSS | Styling |
| Propshaft | Asset pipeline |
| Importmap | JavaScript modules |

### Deployment

| Technology | Purpose |
|------------|---------|
| Docker | Containerization |
| Kamal | Zero-downtime deployment |
| Thruster | Asset serving and HTTP/2 |

## Integration Points

### Home Assistant

Two integration methods:

1. **Add-on**: Runs HomeChat as an HA supervised container
2. **Integration**: Custom component for HA automations

Communication flow:

```mermaid
flowchart LR
    HA[Home Assistant] -->|Webhook| HC[HomeChat]
    HC -->|API Response| HA
    HA -->|notify.homechat| HC
    HC -->|Events| HA
```

### AI Bots

LiteLLM provides a unified interface to multiple LLM providers:

```mermaid
flowchart TB
    User[User mentions @bot] --> HC[HomeChat]
    HC --> LiteLLM[LiteLLM Proxy]
    LiteLLM --> Ollama[Ollama]
    LiteLLM --> OpenAI[OpenAI]
    LiteLLM --> Anthropic[Anthropic]
    LiteLLM --> HC
    HC --> User
```

### Push Notifications

Firebase Cloud Messaging for mobile push:

```mermaid
flowchart LR
    HC[HomeChat] -->|HTTP| FCM[Firebase]
    FCM -->|Push| iOS[iOS Device]
    FCM -->|Push| Android[Android Device]
```

## Offline-First Design

HomeChat works without internet connectivity:

| Feature | Implementation |
|---------|----------------|
| No CDN dependencies | All assets served locally |
| No external fonts | System fonts or bundled |
| Database-backed ActionCable | Solid Cable, no Redis |
| PWA caching | Service worker for app shell |
| Mobile offline | Core Data (iOS), Room (Android) |

### PWA Architecture

```mermaid
flowchart TB
    Browser --> SW[Service Worker]
    SW --> Cache[Cache Storage]
    SW --> Network[Network]
    Cache --> Browser
    Network --> Browser
```

## Security Architecture

See [Security Hardening Guide](../security/hardening-guide.md) for detailed security information.

### Key Security Features

- bcrypt password hashing
- TOTP two-factor authentication
- Hashed API tokens with prefix identification
- Rate limiting (Rack::Attack)
- Audit logging
- Account lockout

## Scalability Considerations

HomeChat is designed for household/small team use:

| Metric | Typical Capacity |
|--------|------------------|
| Users | 10-50 |
| Messages/day | 1,000-10,000 |
| Concurrent connections | 10-50 |
| Database size | < 1GB |

For larger deployments, consider:
- PostgreSQL instead of SQLite
- Redis for ActionCable and caching
- Multiple server instances behind load balancer
