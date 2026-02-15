# Troubleshooting Guide

This guide helps diagnose and resolve common HomeChat issues.

## Quick Diagnostics

### Health Check

```bash
# Basic health
curl http://localhost:3000/up
# Expected: "OK"

# API health
curl http://localhost:3000/api/v1/health
# Expected: {"status":"ok","timestamp":"..."}
```

### Log Locations

| Deployment | Log Location |
|------------|--------------|
| Development | `log/development.log` |
| Production | `log/production.log` |
| Docker | `docker logs homechat` |
| HA Addon | HA > Settings > Add-ons > HomeChat > Log |
| Kamal | `bin/kamal app logs -f` |

## Application Issues

### Application Won't Start

**Symptoms:** Container exits, "connection refused", blank page

**Check logs:**
```bash
# Docker
docker logs homechat

# Kamal
bin/kamal app logs
```

**Common causes:**

| Error | Solution |
|-------|----------|
| `RAILS_MASTER_KEY missing` | Set environment variable or create `config/master.key` |
| `database not found` | Run `bin/rails db:prepare` |
| `port already in use` | Stop other service or change port |
| `permission denied` | Check volume permissions |

**Reset database:**
```bash
# Docker
docker exec homechat bin/rails db:reset

# Development
bin/rails db:reset
```

### Slow Performance

**Symptoms:** Pages load slowly, real-time updates delayed

**Diagnose:**
```bash
# Check database size
ls -lh /data/production.sqlite3

# Check memory usage
docker stats homechat
```

**Solutions:**
- Clear old messages if database is large
- Increase container memory limits
- Check for N+1 queries (enable Bullet gem)
- Consider PostgreSQL for high-traffic deployments

### High Memory Usage

```bash
# Check current usage
docker stats homechat

# Restart to clear memory
docker restart homechat
```

## Authentication Issues

### Can't Login

**Symptoms:** "Invalid username or password", account locked

**Check account status:**
```ruby
# Access console
bin/rails console

# Find user
user = User.find_by(username: 'youruser')
user.locked_until  # Check if locked
user.failed_attempts  # Check attempt count
```

**Unlock account:**
```ruby
user.update!(locked_until: nil, failed_attempts: 0)
```

**Reset password:**
```ruby
user.update!(password: 'new_password')
```

### 2FA Issues

**Lost authenticator access:**
1. Use backup codes (if saved)
2. Admin can disable 2FA:
```ruby
user = User.find_by(username: 'youruser')
user.update!(otp_required_for_login: false, otp_secret: nil)
```

### Forgot Admin Password

```bash
# Create new admin or reset password
docker exec homechat bin/rails runner "
  user = User.find_by(username: 'admin')
  user.update!(password: 'new_secure_password')
  puts 'Password reset successfully'
"
```

## API Issues

### API Returns 401 Unauthorized

**Check token:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/health
```

**Verify token is active:**
```ruby
token = ApiToken.find_by(token_prefix: 'hc_xxxxx')
token.active?  # Should be true
token.last_used_at  # When last used
```

**Common causes:**
- Token deactivated
- Token expired (if expiration implemented)
- Wrong token format (should be `Bearer TOKEN`)
- Extra whitespace in token

### API Rate Limited

**Symptoms:** 429 Too Many Requests

**Check current limits:**
```ruby
# View Rack::Attack configuration
Rails.application.config.middleware.instance_variable_get(:@operations)
```

**Solutions:**
- Wait for rate limit window to pass
- Increase limits in `config/initializers/rack_attack.rb`
- Use multiple API tokens for different services

## WebSocket Issues

### Real-Time Updates Not Working

**Symptoms:** Messages don't appear immediately, need to refresh

**Check ActionCable connection:**
1. Open browser developer tools
2. Go to Network > WS (WebSocket)
3. Look for `cable` connection

**Common causes:**
- Reverse proxy not forwarding WebSocket headers
- CORS blocking WebSocket connection
- SSL certificate issues

**Nginx WebSocket fix:**
```nginx
location /cable {
    proxy_pass http://localhost:3000/cable;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

### Connection Drops Frequently

**Check connection stability:**
```javascript
// In browser console
App.cable.connection.monitor.visibilityDidChange()
```

**Solutions:**
- Increase proxy timeouts
- Check network stability
- Reduce message frequency

## Database Issues

### Database Locked

**Symptoms:** "database is locked" errors

**Solutions:**
```bash
# Stop writes temporarily
docker exec homechat bin/rails runner "ActiveRecord::Base.connection.execute('PRAGMA busy_timeout = 10000')"

# Check for long-running queries
docker exec homechat bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT * FROM sqlite_master')"
```

### Database Corruption

**Symptoms:** "database disk image is malformed"

**Check integrity:**
```bash
sqlite3 /data/production.sqlite3 "PRAGMA integrity_check;"
```

**Recovery:**
```bash
# Backup current database
cp /data/production.sqlite3 /data/production.sqlite3.backup

# Attempt repair
sqlite3 /data/production.sqlite3 ".recover" | sqlite3 /data/production_new.sqlite3

# Replace if successful
mv /data/production_new.sqlite3 /data/production.sqlite3
```

### Migration Failed

```bash
# Check migration status
docker exec homechat bin/rails db:migrate:status

# Re-run migrations
docker exec homechat bin/rails db:migrate

# Force specific migration
docker exec homechat bin/rails db:migrate VERSION=20240101000000
```

## Push Notification Issues

### Push Notifications Not Received

**Check FCM configuration:**
```ruby
# In console
puts ENV['FCM_PROJECT_ID']
puts ENV['FCM_CREDENTIALS'] ? 'Set' : 'Not set'
```

**Test notification:**
```ruby
user = User.find_by(username: 'test')
user.fcm_token  # Check if token is set
PushNotificationJob.perform_now(user, "Test notification")
```

**Common causes:**
- FCM credentials not configured
- User FCM token expired
- Mobile app not registered for push

### FCM Token Invalid

```ruby
# Clear invalid token
user.update!(fcm_token: nil)
# User will re-register on next app open
```

## Home Assistant Integration Issues

### Integration Not Connecting

**Test from HA:**
```bash
# Test API access
curl -H "Authorization: Bearer YOUR_TOKEN" http://homechat:3000/api/v1/health
```

**Check network:**
```bash
# From HA container
ping homechat
```

**Common causes:**
- Wrong host/port in integration config
- Firewall blocking connection
- SSL certificate issues (try `ssl: false` for local)

### Messages Not Appearing

1. Check channel exists in HomeChat
2. Verify API token permissions
3. Check HomeChat logs for errors
4. Test with `notify.homechat` service

### Webhooks Not Firing

1. Verify webhook URL is correct
2. Check HomeChat can reach HA
3. Enable debug logging in HA
4. Check for HMAC signature issues

## Container Issues

### Out of Disk Space

```bash
# Check disk usage
docker system df

# Clean up
docker system prune -f

# Remove old images
docker image prune -a
```

### Volume Permission Issues

```bash
# Check ownership
ls -la /var/lib/docker/volumes/homechat_data/_data/

# Fix permissions (example)
docker exec homechat chown -R rails:rails /data
```

## Debug Mode

### Enable Debug Logging

**Docker:**
```yaml
environment:
  - LOG_LEVEL=debug
```

**Rails:**
```ruby
# config/environments/production.rb
config.log_level = :debug
```

**Restart after changes:**
```bash
docker restart homechat
```

### Access Rails Console

```bash
# Docker
docker exec -it homechat bin/rails console

# Kamal
bin/kamal console
```

### Useful Debug Commands

```ruby
# Check recent errors
Rails.logger.level = :debug

# Check database connection
ActiveRecord::Base.connection.active?

# List all users
User.pluck(:username, :role)

# Check channel membership
Channel.find(1).members.pluck(:username)

# Recent messages
Message.order(created_at: :desc).limit(10)
```

## Getting Help

### Collect Information

When reporting issues, include:
1. HomeChat version/commit
2. Deployment method (Docker/Kamal/addon)
3. Relevant logs
4. Steps to reproduce
5. Expected vs actual behavior

### Log Collection

```bash
# Collect logs
docker logs homechat > homechat.log 2>&1

# System info
docker version
docker inspect homechat
```

### Resources

- [GitHub Issues](https://github.com/kebabmane/homechat/issues)
- [GitHub Discussions](https://github.com/kebabmane/homechat/discussions)
- [Security Guide](../security/hardening-guide.md)
