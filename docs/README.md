# WordPress Docker-in-Docker Documentation

Complete documentation for the WordPress Docker-in-Docker (DinD) environment.

## 📖 Documentation Index

### Getting Started

#### [Quick Start Guide](QUICKSTART.md)
Get up and running in minutes with the essential commands and setup steps.

**Topics:**
- Prerequisites
- Initial setup
- Creating your first instance
- Basic commands

---

#### [Installation Guide](INSTALLATION.md)
Detailed installation instructions for different environments.

**Topics:**
- System requirements
- Building Docker images
- Installing the CLI tool
- Environment initialization
- Verification steps

---

#### [Configuration Guide](CONFIGURATION.md) ⭐ **NEW**
Complete guide to configuring the WordPress DinD environment using `.env` and configuration files.

**Topics:**
- Environment variables (`.env` file)
- Port configuration
- Default instance settings
- WordPress installation defaults
- PHP, MySQL, Nginx, Apache configuration
- Instance-specific configuration
- Configuration layers and priority
- Best practices

---

#### [Workspace Modes Guide](WORKSPACE_MODES.md) ⭐ **NEW**
Complete guide to choosing and using workspace modes.

**Topics:**
- Workspace Mode vs Multi-Instance Mode
- When to use each mode
- Architecture differences
- Usage examples
- Instance cloning strategies
- Switching between modes
- Best practices
- Troubleshooting

---

### Usage & Reference

#### [Usage Guide](USAGE.md)
Comprehensive usage examples and workflows.

**Topics:**
- Instance management (create, start, stop, delete)
- WordPress installation
- WP-CLI usage
- Plugin and theme management
- Database operations
- Configuration management
- Log management
- Common workflows
- Real-world scenarios

---

#### [Quick Reference](QUICK_REFERENCE.md)
Fast command reference for experienced users.

**Topics:**
- Command syntax
- Common operations
- Bash aliases
- Quick examples
- Port reference

---

### Technical Documentation

#### [Architecture Overview](ARCHITECTURE.md)
System architecture and design decisions.

**Topics:**
- Docker-in-Docker architecture
- Container hierarchy
- Volume management
- Configuration layers
- Image sharing
- Data persistence
- Security considerations

---

#### [Network Configuration](NETWORK.md)
Network isolation and configuration details.

**Topics:**
- Network architecture
- Network isolation
- Port mapping
- Inter-instance communication
- External access
- Firewall configuration

---

#### [Image Management](IMAGES.md)
Docker image details and management.

**Topics:**
- Available images and versions
- Image building process
- Image sharing between host and DinD
- Custom image creation
- Image updates
- Version management

---

### Environment Variables & Integration

#### [Environment Variable Integration](ENV_INTEGRATION.md) ⭐ **NEW**
Complete summary of the `.env` integration implementation.

**Topics:**
- What was changed
- Before and after comparison
- Files modified
- New variables added
- Benefits of integration
- Migration guide
- Usage examples

---

### Help & Troubleshooting

#### [Troubleshooting Guide](TROUBLESHOOTING.md)
Common issues and their solutions.

**Topics:**
- Installation issues
- Container startup problems
- Network connectivity issues
- Permission errors
- Performance problems
- Database connection issues
- Port conflicts
- Debugging tips

---

## 🎯 Quick Navigation

### I want to...

**Get started quickly**
→ [Quick Start Guide](QUICKSTART.md)

**Install the system**
→ [Installation Guide](INSTALLATION.md)

**Configure ports and defaults**
→ [Configuration Guide](CONFIGURATION.md)

**Learn all the commands**
→ [Usage Guide](USAGE.md)

**Find a specific command**
→ [Quick Reference](QUICK_REFERENCE.md)

**Understand how it works**
→ [Architecture Overview](ARCHITECTURE.md)

**Fix a problem**
→ [Troubleshooting Guide](TROUBLESHOOTING.md)

**Customize my setup**
→ [Configuration Guide](CONFIGURATION.md)

**Learn about .env variables**
→ [Configuration Guide](CONFIGURATION.md) or [ENV Integration](ENV_INTEGRATION.md)

---

## 📋 Documentation by Topic

### Configuration
- [Configuration Guide](CONFIGURATION.md) - Complete configuration reference
- [ENV Integration](ENV_INTEGRATION.md) - Environment variable integration details
- [Network Configuration](NETWORK.md) - Network setup and isolation

### Usage
- [Usage Guide](USAGE.md) - Comprehensive usage examples
- [Quick Reference](QUICK_REFERENCE.md) - Command quick reference
- [Quick Start](QUICKSTART.md) - Get started quickly

### Technical
- [Architecture](ARCHITECTURE.md) - System architecture
- [Images](IMAGES.md) - Docker image details
- [Network](NETWORK.md) - Network architecture

### Installation & Setup
- [Installation](INSTALLATION.md) - Installation instructions
- [Quick Start](QUICKSTART.md) - Quick setup guide

### Help
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

---

## 🔧 Configuration Files Reference

### Environment Variables (`.env`)

The `.env` file is the central configuration point. See [Configuration Guide](CONFIGURATION.md) for details.

**Key variables:**
- `PHPMYADMIN_PORT` - phpMyAdmin port (default: 8080)
- `MAIL_CATCHER_HTTP_PORT` - MailCatcher web port (default: 1080)
- `DEFAULT_PHP_VERSION` - Default PHP version (default: 83)
- `DEFAULT_MYSQL_VERSION` - Default MySQL version (default: 80)
- `WORDPRESS_ADMIN_USER` - Default admin username
- `WORDPRESS_ADMIN_PASSWORD` - Default admin password

[See all variables →](CONFIGURATION.md#environment-variable-reference)

### Configuration Files

Configuration files are organized by software and version:

```
config/
├── php/{version}/        # PHP configuration
├── mysql/{version}/      # MySQL configuration
├── nginx/{version}/      # Nginx configuration
└── apache/{version}/     # Apache configuration
```

[Learn more about configuration files →](CONFIGURATION.md#configuration-files)

---

## 🚀 Common Tasks

### Change Default Ports

Edit `.env`:
```bash
PHPMYADMIN_PORT=9080
MAIL_CATCHER_HTTP_PORT=2080
```

[Full guide →](CONFIGURATION.md#changing-ports)

### Change Default PHP/MySQL Versions

Edit `.env`:
```bash
DEFAULT_PHP_VERSION=81
DEFAULT_MYSQL_VERSION=57
```

[Full guide →](CONFIGURATION.md#changing-default-versions)

### Customize WordPress Installation Defaults

Edit `.env`:
```bash
WORDPRESS_WEBSITE_TITLE="My Blog"
WORDPRESS_ADMIN_USER="webmaster"
WORDPRESS_ADMIN_EMAIL="admin@example.com"
```

[Full guide →](CONFIGURATION.md#wordpress-installation-defaults)

---

## 📚 Additional Resources

### CLI Tool
- [CLI Tool README](../cli-tool/README.md) - Global CLI tool documentation

### Project Files
- [Main README](../README.md) - Project overview
- [CHANGELOG](../CHANGELOG.md) - Version history
- [LICENSE](../LICENSE) - License information

---

## 🤝 Contributing

Found an issue or want to improve the documentation?

1. Check existing documentation for similar topics
2. Follow the existing documentation style
3. Include code examples where appropriate
4. Test all commands before documenting them
5. Update this index if adding new documentation

---

## 🤝 Contributing

Want to contribute to this project?

- **[Contributing Guidelines](../CONTRIBUTING.md)** - How to contribute
- **[Conventional Commits Guide](CONVENTIONAL_COMMITS.md)** - Commit message format
- **[Pull Request Template](PULL_REQUEST_TEMPLATE.md)** - PR template

---

## 📝 Documentation Standards

All documentation follows these standards:

- **Clear headings** - Use descriptive section headers
- **Code examples** - Include working code examples
- **Cross-references** - Link to related documentation
- **Up-to-date** - Keep documentation synchronized with code
- **Beginner-friendly** - Explain concepts clearly
- **Searchable** - Use keywords that users might search for

---

## 🔍 Search Tips

Use your editor's search function to find:
- Specific commands: Search for the command name
- Error messages: Search for the error text
- Configuration options: Search for the variable name
- Topics: Search for keywords like "port", "network", "database"

---

**Last Updated:** 2025-11-05
**Version:** 1.0.0

