# HomeChat API Documentation

## Overview

HomeChat provides a RESTful API for integration with mobile apps, bots, and external services.

**Base URL:** `/api/v1`

**Authentication:** Bearer token in `Authorization` header or `X-API-Key` header.

```
Authorization: Bearer <your-api-token>
# or
X-API-Key: <your-api-token>
```

---

## Authentication

### Sign In

```http
POST /api/v1/signin
```

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200):**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "johndoe",
    "role": "user"
  },
  "token": "your-api-token"
}
```

**Response (401):**
```json
{
  "success": false,
  "error": "Invalid username or password"
}
```

### Sign Up

```http
POST /api/v1/signup
```

**Request Body:**
```json
{
  "username": "string",
  "password": "string",
  "password_confirmation": "string"
}
```

**Response (201):**
```json
{
  "success": true,
  "user": {
    "id": 2,
    "username": "newuser",
    "role": "user"
  },
  "token": "your-api-token"
}
```

### Sign Out

```http
DELETE /api/v1/signout
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "message": "Signed out successfully"
}
```

---

## Channels

### List Channels

```http
GET /api/v1/channels
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "channels": [
    {
      "id": 1,
      "name": "general",
      "description": "General discussion",
      "type": "public",
      "member_count": 10,
      "online_member_count": 3,
      "last_message": {
        "id": 100,
        "content": "Hello!",
        "created_at": "2024-01-15T10:30:00Z",
        "user": {
          "id": 1,
          "username": "johndoe"
        }
      },
      "unread_count": 0,
      "is_member": true,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### Join Channel

```http
POST /api/v1/channels/:id/join
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "message": "Successfully joined channel"
}
```

### Leave Channel

```http
DELETE /api/v1/channels/:id/leave
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "success": true,
  "message": "Successfully left channel"
}
```

### Get Channel Members

```http
GET /api/v1/channels/:id/members
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "members": [
    {
      "id": 1,
      "username": "johndoe",
      "is_online": true,
      "status": "Available",
      "last_seen_at": "2024-01-15T10:30:00Z",
      "avatar_url": null,
      "avatar_initials": "J",
      "avatar_color_index": 3
    }
  ]
}
```

---

## Messages

### List Messages

```http
GET /api/v1/messages?channel=<channel_name>&limit=50&before=<message_id>
```

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `channel` (required): Channel name
- `limit` (optional): Max messages to return (default: 50)
- `before` (optional): Get messages before this message ID (pagination)

**Response (200):**
```json
{
  "messages": [
    {
      "id": 1,
      "content": "Hello world!",
      "created_at": "2024-01-15T10:30:00Z",
      "user": {
        "id": 1,
        "username": "johndoe"
      },
      "channel_id": 1,
      "files": []
    }
  ]
}
```

### Create Message

```http
POST /api/v1/messages
```

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "message": "Hello world!",
  "room": "general"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": {
    "id": 101,
    "content": "Hello world!",
    "created_at": "2024-01-15T10:35:00Z"
  }
}
```

### Create Message in Channel

```http
POST /api/v1/channels/:id/messages
```

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "content": "Hello world!"
}
```

### Send Direct Message

```http
POST /api/v1/users/:id/messages
```

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "message": "Private message content"
}
```

---

## Search

### Global Search

```http
GET /api/v1/search?q=<query>
```

**Headers:** `Authorization: Bearer <token>`

**Query Parameters:**
- `q` (required): Search query (min 2 characters)

**Response (200):**
```json
{
  "users": [
    {
      "id": 1,
      "username": "johndoe",
      "is_online": true,
      "avatar_initials": "J"
    }
  ],
  "channels": [
    {
      "id": 1,
      "name": "general",
      "type": "public",
      "is_member": true
    }
  ],
  "messages": [
    {
      "id": 50,
      "content": "Message containing query...",
      "created_at": "2024-01-15T10:00:00Z",
      "user": { "id": 1, "username": "johndoe" },
      "channel": { "id": 1, "name": "general" }
    }
  ],
  "totalResults": 10
}
```

### Search Users

```http
GET /api/v1/users/search?q=<query>
```

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "users": [
    {
      "id": 1,
      "username": "johndoe",
      "is_online": true
    }
  ]
}
```

---

## Health & Metrics

### Health Check (No Auth)

```http
GET /api/v1/health
```

**Response (200):**
```json
{
  "status": "ok"
}
```

### Basic Metrics (No Auth)

```http
GET /api/v1/metrics/health
```

**Response (200):**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "Homechat",
  "environment": "production"
}
```

### Detailed Metrics (Admin Only)

```http
GET /api/v1/metrics
```

**Headers:** `Authorization: Bearer <admin-token>`

**Response (200):**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "application": {
    "name": "Homechat",
    "environment": "production",
    "ruby_version": "3.3.0",
    "rails_version": "8.0.2"
  },
  "users": {
    "total": 100,
    "admins": 2,
    "online": 15
  },
  "channels": {
    "total": 20,
    "active_today": 10
  },
  "messages": {
    "total": 5000,
    "today": 150
  }
}
```

**Prometheus Format:**

```http
GET /api/v1/metrics
Accept: text/plain
```

Returns metrics in Prometheus exposition format.

---

## Webhooks

### Receive Webhook (Bots)

```http
POST /api/v1/webhooks/:webhook_id
```

**Headers:**
- `X-Webhook-Signature`: HMAC-SHA256 signature

**Request Body:** Varies by integration

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| General | 300 requests / 5 minutes |
| Login | 5 attempts / 20 seconds |
| Signup | 3 attempts / hour |
| API | 100 requests / minute |
| Messages | 30 messages / minute |

Rate limit headers are included in responses:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`

---

## Error Responses

All endpoints return consistent error formats:

```json
{
  "error": "Error message describing the issue"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

---

## WebSocket (ActionCable)

Connect to `/cable` for real-time updates.

### Channels

- **ChatChannel**: Subscribe to receive new messages
- **PresenceChannel**: User online/offline status
- **TypingChannel**: Typing indicators

### Example Connection (JavaScript)

```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer("/cable?token=your-api-token")

consumer.subscriptions.create(
  { channel: "ChatChannel", channel_id: 1 },
  {
    received(data) {
      console.log("New message:", data)
    }
  }
)
```
