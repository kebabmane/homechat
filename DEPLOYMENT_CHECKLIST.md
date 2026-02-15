# Deployment Checklist - Security & Performance Updates

Follow these steps to deploy the security and performance improvements made on 2025-12-17.

## Pre-Deployment Steps

### 1. Review Changes
- [ ] Read `SECURITY_IMPROVEMENTS.md` to understand all changes
- [ ] Review modified files in git diff
- [ ] Ensure team is aware of new rate limiting

### 2. Backup
- [ ] Backup production database
- [ ] Backup Rails credentials file
- [ ] Document current API tokens (will need regeneration)

### 3. Local Testing
- [ ] Run test suite: `rails test`
- [ ] Test login rate limiting locally
- [ ] Verify search functionality works
- [ ] Test WebSocket connections
- [ ] Check admin panel webhook secret display

---

## Deployment Steps

### Step 1: Update Dependencies

```bash
# Pull latest changes
git pull origin main  # or your branch name

# Install new gems (rack-attack)
bundle install

# Expected new gems:
# - rack-attack ~> 6.7
```

### Step 2: Configure API Token Pepper

**Option A: Rails Credentials (Recommended)**
```bash
# Edit credentials
EDITOR=nano rails credentials:edit

# Add this block:
api_token:
  pepper: "GENERATE_RANDOM_64_CHAR_STRING_HERE"

# Save and close
```

**Option B: Environment Variable**
```bash
# Add to your .env or environment configuration
export API_TOKEN_PEPPER="your-random-64-character-string"

# For systemd service, add to /etc/systemd/system/homechat.service:
Environment="API_TOKEN_PEPPER=your-random-string"
```

**Generate Secure Pepper:**
```bash
# Ruby:
ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"

# OpenSSL:
openssl rand -hex 32
```

### Step 3: Run Migrations

```bash
# Run migrations
rails db:migrate

# Expected migrations:
# - AddPerformanceIndexes (adds indexes and last_message_at column)

# Verify migration success
rails db:migrate:status
```

### Step 4: Restart Application

```bash
# For systemd:
sudo systemctl restart homechat

# For Docker:
docker-compose restart

# For Kamal:
kamal deploy

# Verify app started successfully
curl http://localhost:3000/health  # or your health check endpoint
```

---

## Post-Deployment Verification

### Critical Checks

1. **Application Starts Successfully**
```bash
# Check logs for errors
tail -f log/production.log

# Look for:
# - No BCrypt errors
# - No migration errors
# - Rack::Attack initialized
```

2. **Rate Limiting Works**
```bash
# Test login rate limit (should block after 5 attempts)
for i in {1..7}; do
  curl -X POST http://localhost:3000/signin \
    -d "username=test&password=wrong" \
    -i | grep "HTTP"
done

# Expected: First 5 attempts return 302/422, 6th+ returns 429
```

3. **API Authentication Works**
```bash
# Test with existing API token
curl http://localhost:3000/api/v1/messages \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -i

# Should return 200 OK
# Token will auto-upgrade to BCrypt on first use
```

4. **Search Functionality Works**
```bash
# Test user search
curl http://localhost:3000/api/v1/search?q=test \
  -H "Authorization: Bearer YOUR_TOKEN"

# Should return results without errors
```

5. **WebSocket Connections Work**
```bash
# Open browser console and check:
# - ActionCable connects successfully
# - Typing indicators work
# - Real-time messages appear
```

6. **Admin Panel Works**
```bash
# Visit admin bot settings page
# Verify webhook secrets are masked: ••••••••••••••••••••
# Verify "Regenerate" button exists
```

---

## Optional: Regenerate API Tokens

For maximum security, regenerate all existing API tokens (they auto-upgrade but regeneration is cleaner):

```bash
rails console

# List existing tokens
ApiToken.pluck(:id, :name, :active)

# Regenerate all tokens (BREAKS EXISTING INTEGRATIONS)
ApiToken.find_each do |token|
  old_digest = token.token_digest[0..8]
  token.regenerate!
  puts "Regenerated token #{token.id} (#{token.name}): #{token.token}"
  puts "Old digest prefix: #{old_digest}"
  puts "New token (SAVE THIS): #{token.token}"
  puts "---"
end

# OR regenerate specific tokens
token = ApiToken.find_by(name: "Home Assistant")
new_token_value = token.regenerate!
puts "New token: #{token.token}"
```

**Important**: Save new token values immediately - they won't be shown again!

---

## Home Assistant Integration Check

If using Home Assistant add-on:

1. **Verify Environment Variable**
```bash
echo $HOME_ASSISTANT_ADDON
# Should output: true
```

2. **Test HA Ingress**
```bash
# From HA instance:
curl http://localhost:3000/ -i

# Check for:
# - X-Frame-Options: ALLOWALL (not SAMEORIGIN)
# - Connection successful
```

3. **Test Webhook**
```bash
# If bot webhook secret was regenerated, update HA configuration:
# 1. Go to admin/bots/[bot_id]
# 2. Click "Regenerate" button
# 3. Copy webhook_secret from flash message
# 4. Update Home Assistant configuration
```

---

## Rollback Plan

If issues occur, follow this rollback procedure:

### Quick Rollback (Revert Code)
```bash
# Revert to previous commit
git revert HEAD

# Restart application
sudo systemctl restart homechat

# Database migration rollback (if needed)
rails db:rollback STEP=1
```

### Manual Fix (Keep New Code, Fix Issues)

**Issue: BCrypt Errors**
```bash
# Ensure pepper is configured
rails credentials:edit
# OR
export API_TOKEN_PEPPER="your-pepper"

# Restart app
```

**Issue: Rate Limiting Too Aggressive**
```ruby
# Edit config/initializers/rack_attack.rb
# Increase limits temporarily
throttle('logins/ip', limit: 10, period: 20.seconds)  # was 5

# Restart app
```

**Issue: Migration Fails**
```bash
# Check what failed
rails db:migrate:status

# Rollback specific migration
rails db:rollback STEP=1

# Fix and retry
```

---

## Monitoring After Deployment

### Week 1: Close Monitoring

1. **Watch Error Logs**
```bash
# Monitor for errors
tail -f log/production.log | grep ERROR

# Watch for:
# - BCrypt::Errors
# - Rack::Attack blocks
# - SQL errors
```

2. **Track Rate Limiting**
```bash
# See who's getting rate limited
grep "Rack::Attack" log/production.log | grep throttle

# Look for:
# - Legitimate users being blocked (adjust limits)
# - Attack attempts being stopped (working correctly)
```

3. **Performance Metrics**
```bash
# If using New Relic/Datadog:
# - Message creation time (should be similar)
# - DM channel list time (should be faster)
# - Login time (will be ~100ms slower due to BCrypt)
```

### Month 1: Long-term Validation

- [ ] No security incidents related to fixed vulnerabilities
- [ ] Rate limiting not blocking legitimate users
- [ ] API token authentication working smoothly
- [ ] Performance metrics stable or improved

---

## Success Criteria

✅ **Deployment is successful if:**

- Application starts without errors
- Users can log in successfully
- API authentication works
- Rate limiting blocks excessive requests
- No XSS/SQL injection vulnerabilities
- WebSocket connections functional
- Admin panel displays properly
- Performance equal or better than before

---

## Support Contacts

If issues arise during deployment:

1. **Check documentation**:
   - `SECURITY_IMPROVEMENTS.md` - What was changed
   - `DEPLOYMENT_CHECKLIST.md` - This file
   - Rails logs in `log/production.log`

2. **Common issues**:
   - Missing API_TOKEN_PEPPER → Set in credentials or ENV
   - Migration fails → Check database permissions
   - Rate limiting too strict → Adjust in rack_attack.rb
   - Token auth fails → Check BCrypt gem installed

3. **Emergency contacts**:
   - Development team lead
   - DevOps/Infrastructure team
   - Database administrator

---

## Post-Deployment Cleanup

After successful deployment (1 week+):

- [ ] Remove old API tokens that were regenerated
- [ ] Archive backup files (if no issues)
- [ ] Update documentation with any learnings
- [ ] Schedule security audit review
- [ ] Plan next round of improvements

---

## Next Security Improvements

Consider implementing in future sprints:

1. Token expiration (add `expires_at` column)
2. Two-factor authentication for admins
3. Audit logging for sensitive operations
4. Account lockout after failed attempts
5. IP allowlisting for admin panel
6. Automated security scanning in CI/CD

---

**Good luck with the deployment! 🚀**
