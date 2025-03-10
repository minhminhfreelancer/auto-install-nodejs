# 🚀 Node.js Auto-Deployment System

An automated deployment system for Node.js applications with zero-configuration subdomain creation, automatic SSL, database provisioning, and continuous deployment.

## ✨ Features

- **Custom Domain Support**: Use your own domain with wildcard DNS
- **Node.js 20 LTS**: Latest LTS version pre-configured
- **Instant Subdomains**: Automatically creates `yourapp.yourdomain.com`
- **Automatic SSL**: Let's Encrypt SSL certificates with auto-renewal
- **Database Integration**: PostgreSQL database and user for each application
- **Email Configuration**: SMTP account for each application
- **Continuous Deployment**: Auto-updates from Git every 5 seconds
- **Multiple Application Types**: Support for static sites, SPAs, Node.js backends, and fullstack apps
- **Comprehensive Monitoring**: Detailed logs and debugging tools
- **Domain Flexibility**: Support for custom domains beyond subdomains

## 📋 Requirements

- A Linux server (Ubuntu 22.04 LTS recommended)
- A domain with wildcard DNS configured (pointing to your server's IP)
- Root access to the server

## 🔧 Installation

### 1. Configure DNS

First, set up your domain's DNS settings:

```
yourdomain.com     A     YOUR_SERVER_IP
*.yourdomain.com   A     YOUR_SERVER_IP
```

Wait for DNS propagation (this can take up to 24-48 hours).

### 2. Install the System

Download and run the installation script:

```bash
wget -O enhanced-setup-server.sh https://raw.githubusercontent.com/yourusername/autodeploy-scripts/main/enhanced-setup-server.sh
chmod +x enhanced-setup-server.sh
sudo ./enhanced-setup-server.sh --domain yourdomain.com
```

The script will:
- Install required packages (Nginx, Node.js 20, PostgreSQL, etc.)
- Configure the server for auto-deployment
- Set up Let's Encrypt for SSL
- Create the deployment directory structure

## 📦 Usage

### Creating a New Application

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git
```

This will:
- Create a subdomain `myapp.yourdomain.com`
- Set up Let's Encrypt SSL
- Create a PostgreSQL database and user
- Configure an email account
- Set up continuous deployment from the Git repository

### Application Types

Specify the application type with the `--type` parameter:

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --type fullstack
```

Available types:
- `static`: Basic static websites
- `spa`: Single Page Applications
- `node`: Node.js API/backend
- `fullstack`: Combined frontend (SPA) + backend (Node.js API)

### Using Custom Domains

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --custom-domain app.example.com
```

### Managing Applications

**List all applications:**
```bash
sudo /opt/autodeploy/scripts/list-sites.sh
```

**Remove an application:**
```bash
sudo /opt/autodeploy/scripts/remove-site.sh myapp
```

**Debug an application:**
```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

**Force deployment:**
```bash
sudo /opt/autodeploy/scripts/deploy.sh myapp
```

## ⚙️ Configuration Details

Each application comes with:

### Database Configuration

Environmental variables are automatically created in `.env`:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=db_myapp
DB_USER=user_myapp
DB_PASSWORD=random_secure_password
DATABASE_URL=postgresql://user_myapp:random_secure_password@localhost:5432/db_myapp
```

### Email Configuration

```
SMTP_HOST=localhost
SMTP_PORT=25
SMTP_USER=noreply@myapp.yourdomain.com
SMTP_PASSWORD=random_secure_password
SMTP_FROM=noreply@myapp.yourdomain.com
```

### Application Structure

The system organizes each application in a clean directory structure:
- **Code**: `/opt/autodeploy/www/myapp/`
- **Git Repository**: `/opt/autodeploy/repos/myapp.git/`
- **Logs**: `/opt/autodeploy/logs/`
- **Configuration**: `/opt/autodeploy/config/sites/myapp.json`

## 🔍 Troubleshooting

### Debug Tool

Use the built-in debug tool for comprehensive diagnostics:

```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

This will display:
- Configuration status
- Service status (Nginx, PostgreSQL, Node.js)
- Recent deployment logs
- SSL certificate status
- Connection tests

### Common Issues

1. **Subdomain not working**
   - Check DNS configuration with `dig myapp.yourdomain.com`
   - Verify Nginx configuration with `nginx -t`

2. **Deployment failing**
   - Check logs: `tail -f /opt/autodeploy/logs/deploy/myapp.log`
   - Verify Git repository is accessible

3. **Database connection issues**
   - Review database configuration: `cat /opt/autodeploy/config/sites/myapp_db.env`
   - Check PostgreSQL status: `systemctl status postgresql`

## 📝 License

MIT License - Feel free to use, modify, and distribute as needed.

## 💡 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

Created with ❤️ for the Node.js community.
