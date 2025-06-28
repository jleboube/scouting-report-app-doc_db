# Scout Pro Deployment Checklist

Complete checklist for deploying Scout Pro baseball scouting application to production.

## Pre-Deployment Checklist

### Server Requirements
- [ ] Server meets minimum requirements (4GB RAM, 2 vCPUs, 50GB SSD)
- [ ] Ubuntu 20.04+ or RHEL 8+ installed
- [ ] Docker and Docker Compose installed
- [ ] Domain name configured and DNS pointing to server
- [ ] SSL certificate ready (Let's Encrypt recommended)
- [ ] Firewall configured (ports 80, 443 open; 81 restricted)

### Security Setup
- [ ] Strong passwords generated for all services
- [ ] SSH key-based authentication configured
- [ ] Root login disabled
- [ ] Fail2ban installed and configured
- [ ] Regular security updates scheduled

### File Structure Setup
```
/opt/scoutpro/                    # Main application directory
├── docker-compose.yml           # Main Docker Compose configuration
├── .env                         # Environment variables (secure passwords)
├── .env.example                 # Template for environment variables
├── mongo-init.js               # MongoDB initialization script
├── setup.sh                    # Automated setup script
├── backup.sh                   # Database backup script
├── restore.sh                  # Database restore script
├── monitor.sh                  # Health monitoring script
├── README.md                   # Main documentation
├── PRODUCTION.md               # Production optimization guide
├── backend/                    # Backend API application
│   ├── server.js              # Main server file
│   ├── middleware.js          # Production middleware
│   ├── package.json           # Node.js dependencies
│   ├── Dockerfile             # Backend container configuration
│   └── .dockerignore          # Docker ignore file
├── frontend/                   # Frontend React application
│   ├── src/
│   │   ├── App.js            # Main React component
│   │   └── index.js          # React entry point
│   ├── public/
│   │   └── index.html        # HTML template
│   ├── package.json          # React dependencies
│   ├── Dockerfile            # Frontend container configuration
│   ├── nginx.conf            # Nginx configuration
│   └── .dockerignore         # Docker ignore file
├── logs/                      # Application logs directory
├── backups/                   # Database backups directory
└── .github/                   # CI/CD pipeline (optional)
    └── workflows/
        └── deploy.yml         # GitHub Actions workflow
```

## Deployment Steps

### 1. Initial Server Setup

```bash
# Connect to your server
ssh user@your-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login to apply group changes
exit
ssh user@your-server-ip
```

### 2. Application Setup

```bash
# Create application directory
sudo mkdir -p /opt/scoutpro
sudo chown $USER:$USER /opt/scoutpro
cd /opt/scoutpro

# Copy all application files to /opt/scoutpro/
# You can use git clone, scp, or manual upload

# Make scripts executable
chmod +x setup.sh backup.sh restore.sh monitor.sh

# Run automated setup
./setup.sh
```

### 3. Environment Configuration

```bash
# Edit environment variables
nano .env

# Required settings:
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_mongo_password_here
JWT_SECRET=your_super_secret_jwt_key_minimum_64_characters_for_security
NPM_DB_ROOT_PASSWORD=your_secure_npm_root_password_here
NPM_DB_PASSWORD=your_secure_npm_password_here
DOMAIN_NAME=your-domain.com
REACT_APP_API_URL=https://your-domain.com/api
```

### 4. SSL and Domain Setup

```bash
# Access Nginx Proxy Manager
open http://your-server-ip:81

# Default login: admin@example.com / changeme
# IMPORTANT: Change password immediately!

# Add Proxy Host:
# - Domain: your-domain.com
# - Forward to: frontend:3000
# - Enable caching and security options

# Add SSL Certificate:
# - Request Let's Encrypt certificate
# - Force SSL redirect
```

### 5. Application Verification

```bash
# Check service status
docker-compose ps

# Run health checks
./monitor.sh health

# Test application access
curl -k https://your-domain.com/health
curl -k https://your-domain.com/api/health

# Test demo login
# Email: coach@demo.com
# Password: password123
# Registration code: COACH2024
```

## Post-Deployment Configuration

### 1. Monitoring Setup

```bash
# Setup automated monitoring
echo "*/5 * * * * /opt/scoutpro/monitor.sh health >> /var/log/scoutpro-monitor.log 2>&1" | crontab -

# Setup log rotation
sudo tee /etc/logrotate.d/scoutpro << EOF
/var/log/scoutpro-*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
```

### 2. Backup Automation

```bash
# Setup daily backups at 2 AM
echo "0 2 * * * /opt/scoutpro/backup.sh >> /var/log/backup.log 2>&1" | crontab -

# Test backup
./backup.sh

# Verify backup created
ls -la backups/
```

### 3. Security Hardening

```bash
# Setup firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

# Install fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban

# Disable password authentication (if using SSH keys)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 4. Performance Optimization

```bash
# Check system resources
free -h
df -h
htop

# Optimize Docker
echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

## Testing Checklist

### Functional Testing
- [ ] User registration with valid code works
- [ ] User login/logout works
- [ ] Teams can be created and viewed
- [ ] Players can be added to teams
- [ ] Scouting reports can be created
- [ ] All evaluation categories work
- [ ] Spray charts can be uploaded
- [ ] Reports can be edited and deleted
- [ ] Navigation between views works

### Performance Testing
- [ ] Page load times < 3 seconds
- [ ] API responses < 500ms
- [ ] Image uploads work properly
- [ ] Multiple concurrent users work
- [ ] Database queries are optimized

### Security Testing
- [ ] HTTPS redirect works
- [ ] Security headers present
- [ ] Rate limiting active
- [ ] Authentication required for protected routes
- [ ] File upload restrictions work
- [ ] SQL injection protection active

### Browser Testing
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Mobile browsers (iOS/Android)

## Maintenance Schedule

### Daily
- [ ] Check application health
- [ ] Review error logs
- [ ] Monitor resource usage

### Weekly
- [ ] Review backup integrity
- [ ] Check SSL certificate status
- [ ] Update security patches

### Monthly
- [ ] Full security audit
- [ ] Performance optimization review
- [ ] Backup restore test
- [ ] Update dependencies

## Troubleshooting Guide

### Common Issues

**Services won't start:**
```bash
# Check Docker logs
docker-compose logs

# Check disk space
df -h

# Restart services
docker-compose down && docker-compose up -d
```

**Database connection failed:**
```bash
# Check MongoDB logs
docker-compose logs mongo

# Verify network connectivity
docker-compose exec backend ping mongo
```

**SSL certificate issues:**
```bash
# Check certificate expiry
openssl s_client -connect your-domain.com:443 | openssl x509 -noout -dates

# Renew certificate via Nginx Proxy Manager UI
```

**High resource usage:**
```bash
# Check container resources
docker stats

# Review application logs
./monitor.sh logs

# Scale resources if needed
```

## Emergency Procedures

### Complete Service Failure
1. Check server status and reboot if necessary
2. Restore from latest backup: `./restore.sh backup_file.tar.gz`
3. Verify all services: `./monitor.sh health`
4. Notify users of any downtime

### Data Corruption
1. Stop services: `docker-compose down`
2. Restore from backup: `./restore.sh backup_file.tar.gz`
3. Verify data integrity
4. Restart services: `docker-compose up -d`

### Security Breach
1. Immediately change all passwords
2. Review access logs
3. Update security configurations
4. Consider server rebuild if compromised

## Support Contacts

- **System Administrator**: [your-email@domain.com]
- **Development Team**: [dev-team@domain.com]
- **Emergency Contact**: [emergency@domain.com]

## Success Criteria

Deployment is successful when:
- [ ] All services running and healthy
- [ ] Application accessible via HTTPS
- [ ] Demo login works correctly
- [ ] All features tested and working
- [ ] Monitoring and backups operational
- [ ] Security hardening complete
- [ ] Documentation updated

---

**Deployment Date**: ___________  
**Deployed By**: ___________  
**Version**: ___________  
**Sign-off**: ___________