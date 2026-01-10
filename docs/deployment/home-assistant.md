# HomeChat + Home Assistant Integration

This guide walks you through setting up two-way communication between HomeChat and Home Assistant.

## Architecture Overview

```
┌─────────────────┐    API/Webhooks    ┌─────────────────┐
│                 │ ←───────────────→  │                 │
│  Home Assistant │                    │    HomeChat     │
│                 │    Notifications   │  (Rails App)    │
│   Integration   │ ───────────────→   │                 │
└─────────────────┘                    └─────────────────┘
```

**Features:**
- Send HA notifications to HomeChat rooms
- HomeChat messages trigger HA events/automations
- Bot commands for interactive control
- Rich message formatting with priorities
- Local network deployment optimized

## Prerequisites

- **Home Assistant** running (Core, Supervised, or OS)
- **HomeChat** deployed via addon or Docker
- **Network connectivity** between HA and HomeChat
- **Admin access** to both systems

## Quick Setup (Home Assistant Addon)

### 1. Install HomeChat Addon

1. Add the HomeChat addon repository:
   ```
   Settings > Add-ons > Add-on Store > ⋮ > Repositories
   Add: https://github.com/kebabmane/homechat-addon
   ```

2. Install and configure the HomeChat addon:
   ```yaml
   site_name: "My Home Chat"
   allow_signups: true
   port: 3000
   enable_integrations: true          # Enable API endpoints
   auto_create_api_token: true        # Auto-generate API token
   home_assistant_integration: true   # Enable HA features
   ```

3. Start the addon and note the API token from logs

### 2. Install Home Assistant Integration

1. Copy the integration files:
   ```bash
   # Copy to your HA config directory
   <ha_config>/custom_components/homechat/
   ```

2. Restart Home Assistant

3. Add the integration:
   ```
   Settings > Devices & Services > Add Integration
   Search: "HomeChat"
   ```

4. Configure connection:
   - **Host**: `homeassistant.local` (or addon container name)
   - **Port**: `3000`
   - **SSL**: `false` (for local addon)
   - **API Token**: From HomeChat addon logs or admin panel

### 3. Verify Setup

Test the integration with:
```yaml
service: notify.homechat
data:
  message: "Home Assistant connected successfully!"
  title: "Integration Test"
```

## Docker Deployment Setup

### 1. Deploy HomeChat with Docker

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  homechat:
    image: ghcr.io/kebabmane/homechat:latest
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - ENABLE_INTEGRATIONS=true
      - AUTO_CREATE_API_TOKEN=true
      - HOME_ASSISTANT_INTEGRATION=true
      - WEBHOOK_BASE_URL=http://homeassistant.local:3000
    volumes:
      - homechat_data:/data
      - homechat_storage:/app/storage
    restart: unless-stopped

volumes:
  homechat_data:
  homechat_storage:
```

Start with:
```bash
docker-compose up -d
```

### 2. Get API Token

```bash
# Get the generated API token
docker-compose logs homechat | grep "Token:"

# Or access the admin panel at http://localhost:3000/admin/integrations
```

### 3. Configure Home Assistant Integration

Follow the same integration setup steps as above, using:
- **Host**: `localhost` or your HomeChat server IP
- **Port**: `3000`
- **API Token**: From docker logs or admin panel

## Usage Examples

### Basic Notifications

```yaml
# Simple message
service: notify.homechat
data:
  message: "Doorbell pressed"

# With title and room
service: notify.homechat
data:
  message: "Motion detected in living room"
  title: "Security Alert"
  target: "security"
  data:
    priority: "high"
    type: "security"
```

### Advanced Service Calls

```yaml
# Send formatted notification
service: homechat.send_notification
data:
  message: "Garage door open for 30+ minutes"
  title: "Reminder"
  priority: "normal"
  room_id: "alerts"

# Send basic message
service: homechat.send_message
data:
  message: "Living room lights turned on"
  room_id: "home-automation"
  title: "Device Update"
```

### Automation Examples

#### Motion Alert
```yaml
automation:
  - alias: "Motion Detection"
    trigger:
      platform: state
      entity_id: binary_sensor.motion_living_room
      to: "on"
    action:
      service: notify.homechat
      data:
        message: "Motion detected in {{ trigger.to_state.attributes.friendly_name }}"
        title: "Motion Alert"
        data:
          priority: "high"
          type: "security"
```

#### Device Offline
```yaml
automation:
  - alias: "Device Offline Alert"
    trigger:
      platform: state
      entity_id: device_tracker.phone
      to: "not_home"
      for: "00:15:00"
    action:
      service: homechat.send_notification
      data:
        message: "{{ trigger.to_state.attributes.friendly_name }} offline for 15+ minutes"
        title: "Device Status"
        priority: "normal"
        room_id: "notifications"
```

#### Daily Summary
```yaml
automation:
  - alias: "Evening Summary"
    trigger:
      platform: time
      at: "21:00:00"
    action:
      service: homechat.send_message
      data:
        message: |
          **Daily Summary**
          - Active Lights: {{ states.light | selectattr('state', 'eq', 'on') | list | length }}
          - Temperature: {{ states('sensor.living_room_temperature') }}C
        title: "Evening Report"
        room_id: "daily-reports"
```

### Two-Way Communication

Enable webhooks for HomeChat to Home Assistant communication:

```yaml
automation:
  - alias: "HomeChat Bot Commands"
    trigger:
      platform: event
      event_type: homechat_bot_message
    condition:
      condition: template
      value_template: >
        {{ trigger.event.data.message | lower | regex_search('lights (on|off)') }}
    action:
      - choose:
          - conditions:
              condition: template
              value_template: "{{ 'lights on' in trigger.event.data.message | lower }}"
            sequence:
              service: light.turn_on
              target:
                entity_id: all
          - conditions:
              condition: template
              value_template: "{{ 'lights off' in trigger.event.data.message | lower }}"
            sequence:
              service: light.turn_off
              target:
                entity_id: all
      - service: homechat.send_message
        data:
          message: "Lights {{ 'turned on' if 'on' in trigger.event.data.message else 'turned off' }}"
          room_id: "{{ trigger.event.data.room_id }}"
```

## Troubleshooting

### Connection Issues

**"Failed to connect to HomeChat"**
```bash
# Check HomeChat is running
docker ps | grep homechat
# OR for addon:
ha addons logs homechat

# Test API directly
curl http://your-homechat-host:3000/api/v1/health
```

**"Invalid API token"**
- Check token in HomeChat admin panel
- Regenerate if needed
- Ensure no extra spaces/characters

### Message Delivery Issues

**Messages not appearing in HomeChat**
1. Check target room exists or can be auto-created
2. Verify API token permissions
3. Check HomeChat logs for errors
4. Test with basic message first

**Webhooks not working**
1. Ensure two-way communication enabled in integration setup
2. Check HomeChat can reach Home Assistant network
3. Verify webhook URL in HomeChat admin panel
4. Check HA logs for webhook events

### Debug Logging

**Home Assistant:**
```yaml
logger:
  default: info
  logs:
    custom_components.homechat: debug
```

**HomeChat:**
```yaml
# In addon config
log_level: debug
```

## Security Considerations

### Local Network Deployment

- **API Tokens**: Store securely, rotate periodically
- **Network Segmentation**: Consider VLAN isolation
- **Firewall**: Restrict ports to necessary traffic only
- **TLS**: Enable SSL for production deployments
- **Authentication**: Use HomeChat's built-in user management

### Production Recommendations

1. **Use HTTPS** with proper certificates
2. **Restrict API access** to specific IP ranges
3. **Regular token rotation** via admin panel
4. **Monitor API usage** in HomeChat logs
5. **Backup database** regularly (includes tokens)

## Related Documentation

- [HomeChat Addon](https://github.com/kebabmane/homechat-addon)
- [HomeChat Integration](https://github.com/kebabmane/homechat-integration)
- [Docker Deployment](docker.md)
- [Security Hardening](../security/hardening-guide.md)
