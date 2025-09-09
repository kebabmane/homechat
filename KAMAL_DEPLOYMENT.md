# HomeChat Cloud Deployment with Kamal

Deploy HomeChat to any cloud provider (AWS, GCP, DigitalOcean, Vultr, Hetzner, etc.) using Kamal for zero-downtime deployments.

## 🚀 What is Kamal?

[Kamal](https://kamal-deploy.org) is a modern deployment tool built by the Rails team that:
- **Zero-downtime deployments** - Users never see downtime
- **Multi-server support** - Deploy to one or many servers  
- **SSL automation** - Automatic Let's Encrypt certificates
- **Health checks** - Ensures containers are healthy before switching traffic
- **Simple configuration** - One YAML file for all deployment settings

## 📋 Prerequisites

### Local Requirements
- **Ruby 3.3+** installed locally
- **Docker** installed and running
- **SSH access** to your target servers

### Server Requirements
- **Ubuntu 20.04+** or **Debian 11+** (recommended)
- **Docker** installed on target servers
- **SSH key-based authentication** configured
- **Domain name** pointing to your server(s)

## 🛠️ Quick Setup

### 1. Prepare Your Server(s)

For each cloud provider, create a server and install Docker:

```bash
# Connect to your server
ssh root@your-server-ip

# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Create deploy user (recommended for security)
useradd -m -s /bin/bash deploy
usermod -aG docker deploy
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

### 2. Configure Kamal

Clone and configure HomeChat:

```bash
# Clone the repository
git clone https://github.com/kebabmane/homechat.git
cd homechat

# Copy and edit the deployment configuration
cp config/deploy.yml config/deploy.yml.example
nano config/deploy.yml  # Edit with your settings
```

**Required changes in `config/deploy.yml`:**

```yaml
servers:
  web:
    - YOUR_SERVER_IP  # Replace with actual IP

proxy:
  host: chat.yourdomain.com  # Replace with your domain

registry:
  server: ghcr.io  # Or your preferred registry
  username: your-username
```

### 3. Set Up Secrets

Configure your secrets in `.kamal/secrets`:

```bash
# Set registry password (GitHub Personal Access Token for GHCR)
export KAMAL_REGISTRY_PASSWORD="your_github_token"

# The RAILS_MASTER_KEY is automatically read from config/master.key
```

### 4. Initial Deployment

```bash
# Set up servers and deploy
bin/kamal setup

# For subsequent deployments
bin/kamal deploy
```

## 🌍 Cloud Provider Guides

### AWS EC2

**1. Launch Instance:**
- **AMI**: Ubuntu 22.04 LTS
- **Instance Type**: t3.small (minimum), t3.medium+ (recommended)
- **Security Group**: Allow SSH (22), HTTP (80), HTTPS (443)
- **Storage**: 20GB+ EBS volume

**2. Configure Deployment:**
```yaml
servers:
  web:
    - ec2-xxx-xxx-xxx-xxx.compute-1.amazonaws.com  # Use Public DNS

ssh:
  user: ubuntu  # Default Ubuntu user
```

**3. Domain Setup:**
- Point your domain to the EC2 Elastic IP
- Consider using Route 53 for DNS management

### Google Cloud Platform (GCP)

**1. Create Compute Engine Instance:**
```bash
gcloud compute instances create homechat-server \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-small \
  --boot-disk-size=20GB \
  --tags=http-server,https-server
```

**2. Configure Firewall:**
```bash
gcloud compute firewall-rules create allow-http-https \
  --allow tcp:80,tcp:443 \
  --source-ranges 0.0.0.0/0 \
  --target-tags http-server,https-server
```

**3. Configure Deployment:**
```yaml
servers:
  web:
    - EXTERNAL_IP  # Use external IP from console

ssh:
  user: your-username  # Your GCP username
```

### DigitalOcean

**1. Create Droplet:**
- **Image**: Ubuntu 22.04 LTS
- **Size**: Basic $12/month (2GB RAM, 1vCPU)
- **Region**: Choose closest to your users
- **SSH Keys**: Add your public key

**2. Configure Deployment:**
```yaml
servers:
  web:
    - your-droplet-ip

ssh:
  user: root  # Default for DigitalOcean
```

**3. Optional Enhancements:**
- Add Load Balancer for multiple droplets
- Use Spaces for file storage
- Enable DigitalOcean Monitoring

### Vultr

**1. Deploy Instance:**
- **Server Type**: Cloud Compute - Regular Performance
- **Location**: Choose optimal location
- **Image**: Ubuntu 22.04 LTS
- **Size**: $6/month (1GB RAM) minimum

**2. Configure Deployment:**
```yaml
servers:
  web:
    - your-vultr-ip

ssh:
  user: root
```

### Hetzner Cloud

**1. Create Server:**
- **Location**: Choose your region
- **Image**: Ubuntu 22.04
- **Type**: CX11 (€3.29/month) minimum

**2. Configure Deployment:**
```yaml
servers:
  web:
    - your-hetzner-ip

ssh:
  user: root
```

## 📚 Environment Management

HomeChat supports multiple deployment environments:

### Deploy to Staging
```bash
bin/kamal deploy -d staging
```

### Deploy to Production
```bash
bin/kamal deploy -d production
```

### Environment-Specific Settings

**Staging** (`config/deploy.staging.yml`):
- Auto-generates API tokens
- Debug logging enabled
- Uses subdomain (staging-chat.domain.com)

**Production** (`config/deploy.production.yml`):
- Manual token management
- Optimized performance settings
- Multiple server support

## 🔧 Common Operations

### Check Application Status
```bash
bin/kamal app details
```

### View Logs
```bash
bin/kamal app logs -f
```

### Access Rails Console
```bash
bin/kamal console
```

### Database Operations
```bash
# Access database console
bin/kamal dbc

# Run migrations
bin/kamal app exec "bin/rails db:migrate"

# Create admin user
bin/kamal app exec "bin/rails runner 'User.create!(username: \"admin\", password: \"your-password\", admin: true)'"
```

### Rolling Back
```bash
# Rollback to previous version
bin/kamal rollback
```

### Scale Up/Down
```bash
# Update server list in config/deploy.yml, then:
bin/kamal deploy
```

## 🔒 Security Best Practices

### Server Security
1. **Use non-root user** for deployments
2. **Configure firewall** (ufw or cloud security groups)
3. **Enable automatic security updates**
4. **Use SSH keys** instead of passwords
5. **Change default SSH port** (optional)

### Application Security  
1. **Keep RAILS_MASTER_KEY secure** - never commit to git
2. **Use environment variables** for sensitive data
3. **Enable SSL/TLS** with Let's Encrypt
4. **Regular security updates** via `bin/kamal deploy`
5. **Monitor logs** for suspicious activity

### Backup Strategy
```bash
# Backup volumes (run on server)
docker run --rm -v homechat_production_data:/source:ro \
  -v $(pwd):/backup ubuntu tar czf /backup/homechat-data-$(date +%Y%m%d).tar.gz -C /source .

# Database backup (via Kamal)
bin/kamal app exec "bin/rails runner 'puts Rails.application.config.database_configuration[Rails.env]'" > db_backup.sql
```

## 🚨 Troubleshooting

### Common Issues

**Deployment fails with "Connection refused"**
```bash
# Check SSH access
ssh deploy@your-server-ip

# Verify Docker is running
bin/kamal server exec "docker ps"
```

**SSL certificate issues**
```bash
# Check certificate status
bin/kamal traefik logs

# Force certificate renewal
bin/kamal traefik restart
```

**Application won't start**
```bash
# Check container logs
bin/kamal app logs

# Check environment variables
bin/kamal app exec "printenv"
```

**Database issues**
```bash
# Check database files
bin/kamal app exec "ls -la /rails/db/"

# Reset database (CAUTION: Data loss!)
bin/kamal app exec "bin/rails db:reset"
```

### Performance Optimization

**For high-traffic deployments:**

1. **Use external database**:
   ```yaml
   accessories:
     db:
       image: postgres:15
       # ... configuration
   ```

2. **Add Redis for ActionCable**:
   ```yaml
   accessories:
     redis:
       image: redis:7.0
       # ... configuration
   ```

3. **Multiple web servers**:
   ```yaml
   servers:
     web:
       - server1-ip
       - server2-ip
       - server3-ip
   ```

4. **External file storage** (S3, GCS, etc.):
   ```ruby
   # config/environments/production.rb
   config.active_storage.service = :amazon
   ```

## 📊 Monitoring & Maintenance

### Health Monitoring
```bash
# Check health endpoint
curl https://chat.yourdomain.com/up

# Monitor resource usage
bin/kamal server exec "htop"
```

### Log Management
```bash
# Application logs
bin/kamal app logs -f

# System logs
bin/kamal server exec "journalctl -f"
```

### Updates & Maintenance
```bash
# Deploy latest version
git pull origin main
bin/kamal deploy

# Server updates
bin/kamal server exec "apt update && apt upgrade -y"

# Docker cleanup
bin/kamal server exec "docker system prune -f"
```

## 💡 Tips & Best Practices

1. **Test deployments** on staging before production
2. **Monitor disk space** - logs and Docker images can accumulate
3. **Regular backups** of volumes and database
4. **Use health checks** to ensure smooth deployments
5. **Keep secrets secure** - use password managers
6. **Document your setup** - server IPs, domains, access methods
7. **Plan for scaling** - design for growth from the start

## 🆘 Getting Help

- **Kamal Documentation**: [kamal-deploy.org](https://kamal-deploy.org)
- **HomeChat Issues**: [GitHub Issues](https://github.com/kebabmane/homechat/issues)
- **Rails Deployment Guide**: [guides.rubyonrails.org](https://guides.rubyonrails.org/deployment.html)

Happy deploying! 🚀