#!/usr/bin/env node

const { Command } = require('commander');
const chalk = require('chalk');
const path = require('path');
const fs = require('fs');
const { execSync, spawn } = require('child_process');
const inquirer = require('inquirer');
const ora = require('ora');
const YAML = require('yaml');

const program = new Command();

// Version
const packageJson = require('../package.json');

// Configuration
const CONFIG_FILE = path.join(process.env.HOME || process.env.USERPROFILE, '.wp-dind-config.json');

// Helper functions
function loadConfig() {
    if (fs.existsSync(CONFIG_FILE)) {
        return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    }
    return {
        defaultImagePath: null,
        instances: {}
    };
}

function saveConfig(config) {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

function execCommand(command, options = {}) {
    try {
        return execSync(command, {
            stdio: options.silent ? 'pipe' : 'inherit',
            cwd: options.cwd || process.cwd(),
            ...options
        });
    } catch (error) {
        if (!options.ignoreError) {
            console.error(chalk.red(`Error executing command: ${command}`));
            process.exit(1);
        }
        return null;
    }
}

function checkDocker() {
    try {
        execSync('docker --version', { stdio: 'pipe' });
        return true;
    } catch (error) {
        console.error(chalk.red('Docker is not installed or not running.'));
        console.error(chalk.yellow('Please install Docker from https://www.docker.com/'));
        return false;
    }
}

function checkDockerCompose() {
    try {
        execSync('docker-compose --version', { stdio: 'pipe' });
        return true;
    } catch (error) {
        console.error(chalk.red('docker-compose is not installed.'));
        console.error(chalk.yellow('Please install docker-compose'));
        return false;
    }
}

function loadWorkspaceConfig(targetDir) {
    const workspaceFile = path.join(targetDir, 'wp-dind-workspace.json');
    if (fs.existsSync(workspaceFile)) {
        return JSON.parse(fs.readFileSync(workspaceFile, 'utf8'));
    }
    return null;
}

function saveWorkspaceConfig(targetDir, config) {
    const workspaceFile = path.join(targetDir, 'wp-dind-workspace.json');
    fs.writeFileSync(workspaceFile, JSON.stringify(config, null, 2));
}

function generateDockerCompose(targetDir, config = {}) {
    const containerName = config.workspaceName ? `wp-dind-${config.workspaceName}` : `wp-dind-${path.basename(targetDir)}`;

    // Add workspace mode port if needed
    let workspacePort = '';
    if (config.workspaceType === 'workspace') {
        workspacePort = '      - "${WORDPRESS_PORT:-8000}:80"\n';
    }

    // Add instance ports range for multi-instance mode
    let instancePorts = '';
    if (config.workspaceType === 'multi-instance') {
        instancePorts = '      - "8001-8020:8001-8020"\n';
    }

    // Generate YAML manually to properly handle environment variable substitution
    const composeYaml = `version: '3.8'

services:
  wordpress-dind:
    image: ${config.dindImage || 'airoman/wp-dind:dind-27.0.3'}
    container_name: ${containerName}
    privileged: true
    environment:
      ENABLE_NETWORK_ISOLATION: 'true'
      DOCKER_TLS_CERTDIR: ''
      PUID: "\${PUID:-1000}"
      PGID: "\${PGID:-1000}"
      WORKSPACE_TYPE: '${config.workspaceType || 'multi-instance'}'
    # Ports are not exposed to localhost to avoid conflicts with multiple DinD instances
    # Access services via DinD IP address instead
    expose:
      - "2375"
      - "8080"
      - "1080"
      - "1025"
      - "6379"
      - "8081"
      - "8000"
      - "8001"
      - "8002"
      - "8003"
      - "8004"
      - "8005"
      - "8006"
      - "8007"
      - "8008"
      - "8009"
      - "8010"
      - "8011"
      - "8012"
      - "8013"
      - "8014"
      - "8015"
      - "8016"
      - "8017"
      - "8018"
      - "8019"
      - "8020"
    volumes:
      - ./data/wordpress:/var/www/html
      - ./wordpress-instances:/wordpress-instances
      - ./shared-images:/shared-images
      - ./wp-dind-workspace.json:/wordpress-instances/.workspace-config.json:ro
      - dind-docker-data:/var/lib/docker
    networks:
      - wp-dind
    restart: "no"
    healthcheck:
      test: ["CMD", "docker", "info"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  wp-dind:
    name: wp-dind
    driver: bridge
    ipam:
      config:
        - subnet: 172.19.0.0/16

volumes:
  dind-docker-data:
    driver: local
`;

    return composeYaml;
}

// Commands

program
    .name('wp-dind')
    .description('WordPress Docker-in-Docker CLI Manager')
    .version(packageJson.version);

program
    .command('init')
    .description('Initialize WordPress DinD environment in current directory')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .option('--with-phpmyadmin', 'Include phpMyAdmin service')
    .option('--with-mailcatcher', 'Include MailCatcher service')
    .action(async (options) => {
        if (!checkDocker() || !checkDockerCompose()) {
            process.exit(1);
        }

        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();
        
        console.log(chalk.blue.bold('\n🚀 WordPress Docker-in-Docker Initializer\n'));
        console.log(chalk.gray(`Target directory: ${targetDir}\n`));

        // Check if directory exists
        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        // Check if already initialized
        const composeFile = path.join(targetDir, 'docker-compose.yml');
        if (fs.existsSync(composeFile)) {
            const answers = await inquirer.prompt([{
                type: 'confirm',
                name: 'overwrite',
                message: 'docker-compose.yml already exists. Overwrite?',
                default: false
            }]);

            if (!answers.overwrite) {
                console.log(chalk.yellow('Initialization cancelled.'));
                process.exit(0);
            }
        }

        // Interactive configuration
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'workspaceName',
                message: 'Workspace name:',
                default: path.basename(targetDir),
                validate: (input) => {
                    if (!input || input.trim() === '') {
                        return 'Workspace name cannot be empty';
                    }
                    if (!/^[a-zA-Z0-9_-]+$/.test(input)) {
                        return 'Workspace name can only contain letters, numbers, hyphens, and underscores';
                    }
                    return true;
                }
            },
            {
                type: 'list',
                name: 'workspaceType',
                message: 'Workspace type:',
                choices: [
                    {
                        name: 'workspace - Single WordPress site with selected stack',
                        value: 'workspace'
                    },
                    {
                        name: 'multi-instance - Multiple WordPress sites for testing different stacks',
                        value: 'multi-instance'
                    }
                ],
                default: 'workspace'
            }
        ]);

        // If workspace mode, ask for stack configuration
        let workspaceStack = null;
        if (answers.workspaceType === 'workspace') {
            const stackAnswers = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'webserver',
                    message: 'Web server:',
                    choices: ['nginx', 'apache'],
                    default: 'nginx'
                },
                {
                    type: 'list',
                    name: 'phpVersion',
                    message: 'PHP version:',
                    choices: ['8.3', '8.2', '8.1', '8.0', '7.4'],
                    default: '8.3'
                },
                {
                    type: 'list',
                    name: 'mysqlVersion',
                    message: 'MySQL version:',
                    choices: ['8.0', '5.7', '5.6'],
                    default: '8.0'
                }
            ]);
            workspaceStack = stackAnswers;
        }

        // Note: phpMyAdmin, MailHog, Redis, and Redis Commander are always included
        // They run inside the DinD container via supervisord

        const spinner = ora('Generating configuration files...').start();

        // Create workspace configuration
        const workspaceConfig = {
            workspaceName: answers.workspaceName,
            workspaceType: answers.workspaceType,
            initializedAt: new Date().toISOString(),
            workspaceStack: workspaceStack,  // Only set for workspace mode
            instances: {},  // For multi-instance mode
            stack: {
                dindImage: 'airoman/wp-dind:dind-27.0.3',
                phpVersions: ['7.4', '8.0', '8.1', '8.2', '8.3'],
                mysqlVersions: ['5.6', '5.7', '8.0'],
                webservers: ['nginx', 'apache'],
                services: {
                    phpmyadmin: true,
                    mailhog: true,
                    redis: true,
                    redisCommander: true
                }
            },
            imageVersions: {
                dind: '27.0.3',
                php74: '7.4.33',
                php80: '8.0.30',
                php81: '8.1.31',
                php82: '8.2.26',
                php83: '8.3.14',
                mysql56: '5.6.51',
                mysql57: '5.7.44',
                mysql80: '8.0.40',
                nginx: '1.27.3',
                apache: '2.4.62',
                redis: '7.4.1',
                redisCommander: '0.8.1',
                phpmyadmin: '5.2.3',
                mailhog: '1.0.1'
            }
        };

        // Save workspace configuration
        saveWorkspaceConfig(targetDir, workspaceConfig);

        // Create necessary directories
        const dirs = ['data/wordpress', 'wordpress-instances', 'shared-images', 'logs'];
        dirs.forEach(dir => {
            const dirPath = path.join(targetDir, dir);
            if (!fs.existsSync(dirPath)) {
                fs.mkdirSync(dirPath, { recursive: true });
            }
        });

        // Generate docker-compose.yml
        const composeContent = generateDockerCompose(targetDir, { ...answers, workspaceName: answers.workspaceName });
        fs.writeFileSync(composeFile, composeContent);

        // Create .env file
        const envContent = `# WordPress Docker-in-Docker Environment
# Generated by wp-dind CLI

# Docker-in-Docker Configuration
ENABLE_NETWORK_ISOLATION=true
DOCKER_TLS_CERTDIR=

# Service Port Configuration (all services run inside DinD container)
# Change these if you have port conflicts with other services
DOCKER_DAEMON_PORT=2375
PHPMYADMIN_PORT=8080
MAILCATCHER_WEB_PORT=1080
MAILCATCHER_SMTP_PORT=1025
REDIS_PORT=6379
REDIS_COMMANDER_PORT=8082

# Note: WordPress instances get dynamically assigned ports
# Use 'wp-dind instance info <name>' to find the assigned port

# If you get port conflicts, change the ports above. For example:
# REDIS_PORT=6380
# PHPMYADMIN_PORT=8081

# User/Group IDs for file permissions
# Set these to your host user's UID/GID to allow editing WordPress files
# Run 'id -u' and 'id -g' on your host to get these values
PUID=1000
PGID=1000
`;
        fs.writeFileSync(path.join(targetDir, '.env'), envContent);

        // Create README
        const readmeContent = `# WordPress Docker-in-Docker Environment

Workspace: **${workspaceConfig.workspaceName}**
Initialized: ${new Date(workspaceConfig.initializedAt).toLocaleString()}

This directory contains a WordPress Docker-in-Docker (DinD) environment.

## Quick Start

### Option 1: Install WordPress in Workspace (data/wordpress)

1. Start the environment:
   \`\`\`bash
   wp-dind start
   \`\`\`

2. Install WordPress:
   \`\`\`bash
   wp-dind install-wordpress
   \`\`\`

3. Access your WordPress site:
   - WordPress: Check port with \`docker port <container-name> 80\`
   - phpMyAdmin: http://localhost:8080
   - MailCatcher: http://localhost:1080
   - Redis Commander: http://localhost:8082 (admin/admin)

### Option 2: Create Isolated WordPress Instances

1. Start the environment:
   \`\`\`bash
   wp-dind start
   \`\`\`

2. Create a WordPress instance:
   \`\`\`bash
   wp-dind instance create mysite 80 83 nginx
   \`\`\`

3. Get the instance port and access it:
   \`\`\`bash
   wp-dind instance info mysite
   # Access WordPress at the displayed port (dynamically assigned)
   \`\`\`

## Available Commands

### Environment Management
- \`wp-dind start\` - Start the DinD environment
- \`wp-dind stop\` - Stop the DinD environment
- \`wp-dind status\` - Check environment status
- \`wp-dind ps\` - List all containers
- \`wp-dind logs [-f] [-s service]\` - View logs
- \`wp-dind destroy\` - Destroy environment (removes all data)

### WordPress Installation
- \`wp-dind install-wordpress\` - Install WordPress in data/wordpress
- \`wp-dind install-wordpress --url <url> --title <title>\` - Install with options
- \`wp-dind install-wordpress --skip-install\` - Download only, skip installation

### Instance Management
- \`wp-dind instance create <name> [mysql] [php] [webserver]\` - Create instance
- \`wp-dind instance list\` - List all instances
- \`wp-dind instance info <name>\` - Show instance info
- \`wp-dind instance logs <name> [service]\` - View instance logs
- \`wp-dind instance start/stop <name>\` - Start/stop instance
- \`wp-dind instance remove <name>\` - Remove instance

### Execute Commands
- \`wp-dind exec dind <command>\` - Execute command in DinD host
- \`wp-dind exec <container> <command>\` - Execute command in specific container

### Examples

**Install WordPress in workspace:**
\`\`\`bash
wp-dind install-wordpress \\
  --url http://localhost:8000 \\
  --title "My Site" \\
  --admin-user admin \\
  --admin-password mypassword \\
  --admin-email admin@example.com
\`\`\`

**Create WordPress instance:**
\`\`\`bash
wp-dind instance create mysite 80 83 nginx
# Arguments: name mysql_version php_version webserver
# mysql_version: 56, 57, 80
# php_version: 74, 80, 81, 82, 83
# webserver: nginx, apache
\`\`\`

**Execute WP-CLI commands:**
\`\`\`bash
wp-dind exec dind wp --info
wp-dind exec dind wp plugin list
wp-dind exec dind wp user list
\`\`\`

**Access container shell:**
\`\`\`bash
wp-dind exec -i dind bash
\`\`\`

## Services (Running Inside DinD Container)

All services run inside the DinD container and are accessible from the host:

- **phpMyAdmin**: http://localhost:8080 - Database management interface
- **MailCatcher**: http://localhost:1080 - Email testing (SMTP: localhost:1025)
- **Redis**: localhost:6379 - Cache server
- **Redis Commander**: http://localhost:8082 - Redis management (admin/admin)
- **Docker Daemon**: localhost:2375 - Docker API (inside DinD)

**Note**: WordPress instances get dynamically assigned ports. Use \`wp-dind instance info <name>\` to find the port.

## Directory Structure

- \`data/wordpress/\` - Main WordPress installation
- \`wordpress-instances/\` - Isolated WordPress instances
- \`shared-images/\` - Shared Docker images
- \`logs/\` - Application logs
- \`wp-dind-workspace.json\` - Workspace configuration

## Workspace Configuration

This workspace is configured with:
- **Stack**: ${workspaceConfig.stack.dindImage}
- **PHP Versions**: ${workspaceConfig.stack.phpVersions.join(', ')}
- **MySQL Versions**: ${workspaceConfig.stack.mysqlVersions.join(', ')}
- **Web Servers**: ${workspaceConfig.stack.webservers.join(', ')}
- **Services**: ${Object.entries(workspaceConfig.stack.services).filter(([k, v]) => v).map(([k]) => k).join(', ')}
`;
        fs.writeFileSync(path.join(targetDir, 'README.md'), readmeContent);

        spinner.succeed('Configuration files generated successfully!');

        console.log(chalk.green('\n✅ WordPress DinD environment initialized!\n'));
        console.log(chalk.blue.bold('Workspace Information:'));
        console.log(chalk.gray(`  Name: ${workspaceConfig.workspaceName}`));
        console.log(chalk.gray(`  Type: ${workspaceConfig.workspaceType}`));
        if (workspaceConfig.workspaceStack) {
            console.log(chalk.gray(`  Stack: ${workspaceConfig.workspaceStack.webserver}, PHP ${workspaceConfig.workspaceStack.phpVersion}, MySQL ${workspaceConfig.workspaceStack.mysqlVersion}`));
        }
        console.log(chalk.gray(`  Initialized: ${workspaceConfig.initializedAt}`));
        console.log(chalk.gray(`  Config: wp-dind-workspace.json\n`));
        console.log(chalk.yellow('Next steps:'));
        console.log(chalk.gray('  1. cd ' + targetDir));
        console.log(chalk.gray('  2. wp-dind start'));

        if (workspaceConfig.workspaceType === 'workspace') {
            console.log(chalk.gray('  3. wp-dind install-wordpress'));
            console.log(chalk.gray('  4. Access WordPress at http://<dind-ip>:8000'));
            console.log(chalk.gray('\n  Note: Get DinD IP with "wp-dind status" after starting\n'));
        } else {
            console.log(chalk.gray('  3. Create instances:'));
            console.log(chalk.gray('     docker exec wp-dind-<name> /app/instance-manager.sh create mysite 80 83 nginx'));
            console.log(chalk.gray('  4. List instances: docker exec wp-dind-<name> /app/instance-manager.sh list'));
            console.log(chalk.gray('  5. Access instances at http://<dind-ip>:8001, 8002, etc.'));
            console.log(chalk.gray('\n  Note: Get DinD IP with "wp-dind status" after starting\n'));
        }

        // Save to config
        const config = loadConfig();
        config.instances[targetDir] = {
            created: new Date().toISOString(),
            workspaceName: answers.workspaceName
        };
        saveConfig(config);
    });

program
    .command('start')
    .description('Start the WordPress DinD environment')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .action((options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();
        const composeFile = path.join(targetDir, 'docker-compose.yml');

        if (!fs.existsSync(composeFile)) {
            console.error(chalk.red('No docker-compose.yml found. Run "wp-dind init" first.'));
            process.exit(1);
        }

        // Load workspace config to get container name
        const workspaceConfig = loadWorkspaceConfig(targetDir);
        const containerName = workspaceConfig ? `wp-dind-${workspaceConfig.workspaceName}` : 'wp-dind';

        console.log(chalk.blue('Starting WordPress DinD environment...\n'));
        execCommand('docker-compose up -d', { cwd: targetDir });
        console.log(chalk.green('\n✅ Environment started successfully!\n'));

        // Get DinD container IP address
        try {
            const ipCmd = `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${containerName}`;
            const ipResult = require('child_process').execSync(ipCmd, { encoding: 'utf8' }).trim();

            // Load .env file to get port mappings
            const envPath = path.join(targetDir, '.env');
            const envContent = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf8') : '';
            const envVars = {};
            envContent.split('\n').forEach(line => {
                const match = line.match(/^([A-Z_]+)=(.+)$/);
                if (match) {
                    envVars[match[1]] = match[2];
                }
            });

            const dockerPort = envVars.DOCKER_DAEMON_PORT || '2375';
            const phpMyAdminPort = envVars.PHPMYADMIN_PORT || '8080';
            const mailcatcherWebPort = envVars.MAILCATCHER_WEB_PORT || '1080';
            const mailcatcherSmtpPort = envVars.MAILCATCHER_SMTP_PORT || '1025';
            const redisPort = envVars.REDIS_PORT || '6379';
            const redisCommanderPort = envVars.REDIS_COMMANDER_PORT || '8082';

            console.log(chalk.blue.bold('📡 DinD Container Information:\n'));
            console.log(chalk.gray(`  Container Name: ${containerName}`));
            console.log(chalk.gray(`  IP Address: ${ipResult}\n`));

            // Load workspace config to determine type
            const configPath = path.join(targetDir, 'wp-dind-workspace.json');
            let workspaceType = 'multi-instance';
            if (fs.existsSync(configPath)) {
                const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
                workspaceType = config.workspaceType || 'multi-instance';
            }

            console.log(chalk.blue.bold('🌐 Accessible Services (via DinD IP only):\n'));
            console.log(chalk.gray(`    • phpMyAdmin:        http://${ipResult}:8080`));
            console.log(chalk.gray(`    • MailCatcher Web:   http://${ipResult}:1080`));
            console.log(chalk.gray(`    • Redis Commander:   http://${ipResult}:8081`));
            console.log(chalk.gray(`    • Redis:             ${ipResult}:6379`));
            console.log(chalk.gray(`    • Docker Daemon:     ${ipResult}:2375`));
            console.log(chalk.gray(`    • MailCatcher SMTP:  ${ipResult}:1025\n`));

            if (workspaceType === 'workspace') {
                console.log(chalk.gray(`    • WordPress:         http://${ipResult}:8000\n`));
                console.log(chalk.yellow('Next steps:'));
                console.log(chalk.gray('  • wp-dind install-wordpress (install WordPress)'));
                console.log(chalk.gray('  • wp-dind status (check environment status)'));
            } else {
                console.log(chalk.yellow('Next steps:'));
                console.log(chalk.gray('  • Create instance: docker exec wp-dind-' + path.basename(targetDir) + ' /app/instance-manager.sh create mysite 80 83 nginx'));
                console.log(chalk.gray('  • List instances: docker exec wp-dind-' + path.basename(targetDir) + ' /app/instance-manager.sh list'));
                console.log(chalk.gray('  • Access instances at http://' + ipResult + ':8001, 8002, etc.'));
                console.log(chalk.gray('  • wp-dind status (check environment status)'));
            }
        } catch (error) {
            console.log(chalk.yellow('Run "wp-dind status" to check the status.'));
        }
    });

program
    .command('stop')
    .description('Stop the WordPress DinD environment')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .action((options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();
        console.log(chalk.blue('Stopping WordPress DinD environment...\n'));
        execCommand('docker-compose stop', { cwd: targetDir });
        console.log(chalk.green('\n✅ Environment stopped successfully!'));
    });

program
    .command('status')
    .description('Check the status of the WordPress DinD environment')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .action((options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();
        console.log(chalk.blue('WordPress DinD Environment Status:\n'));
        execCommand('docker-compose ps', { cwd: targetDir });
    });

program
    .command('logs')
    .description('View logs from the WordPress DinD environment')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .option('-f, --follow', 'Follow log output')
    .option('-s, --service <service>', 'Show logs for specific service')
    .action((options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();
        let cmd = 'docker-compose logs';
        if (options.follow) cmd += ' -f';
        if (options.service) cmd += ` ${options.service}`;
        
        execCommand(cmd, { cwd: targetDir });
    });

program
    .command('exec <container> <command...>')
    .description('Execute a command inside a specific Docker container')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .option('-i, --interactive', 'Run in interactive mode (allocate TTY)', false)
    .option('-u, --user <user>', 'Run as specific user (e.g., www-data, root)')
    .action((container, command, options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();

        // Check if we're targeting the DinD host or a WordPress instance container
        let dockerCmd;

        if (container === 'dind' || container === 'host') {
            // Execute in the DinD host container
            dockerCmd = `docker-compose exec`;
            if (options.user) dockerCmd += ` -u ${options.user}`;
            if (!options.interactive) dockerCmd += ` -T`;
            dockerCmd += ` wordpress-dind ${command.join(' ')}`;
        } else {
            // Execute in a WordPress instance container (inside DinD)
            // Format: <instance-name>-<service> or just <container-name>
            dockerCmd = `docker-compose exec`;
            if (!options.interactive) dockerCmd += ` -T`;
            dockerCmd += ` wordpress-dind docker exec`;
            if (options.interactive) dockerCmd += ` -it`;
            if (options.user) dockerCmd += ` -u ${options.user}`;
            dockerCmd += ` ${container} ${command.join(' ')}`;
        }

        console.log(chalk.gray(`Executing: ${dockerCmd}\n`));
        execCommand(dockerCmd, { cwd: targetDir });
    });

program
    .command('instance <action> [args...]')
    .description('Manage WordPress instances (create, start, stop, remove, list, info, logs)')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .action((action, args, options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();

        const validActions = ['create', 'start', 'stop', 'remove', 'list', 'info', 'logs'];
        if (!validActions.includes(action)) {
            console.error(chalk.red(`Invalid action: ${action}`));
            console.log(chalk.yellow(`Valid actions: ${validActions.join(', ')}`));
            process.exit(1);
        }

        const cmd = `docker-compose exec -T wordpress-dind /app/instance-manager.sh ${action} ${args.join(' ')}`;
        execCommand(cmd, { cwd: targetDir });
    });

program
    .command('ps')
    .description('List all containers (DinD host and WordPress instances)')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .option('-a, --all', 'Show all containers (including stopped)')
    .action((options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();

        console.log(chalk.blue.bold('WordPress DinD Containers:\n'));

        // Show DinD host container
        console.log(chalk.yellow('DinD Host Container:'));
        execCommand('docker-compose ps', { cwd: targetDir });

        // Show WordPress instance containers (inside DinD)
        console.log(chalk.yellow('\nWordPress Instance Containers (inside DinD):'));
        const psCmd = options.all ? 'docker ps -a' : 'docker ps';
        execCommand(`docker-compose exec -T wordpress-dind ${psCmd}`, {
            cwd: targetDir,
            ignoreError: true
        });
    });

program
    .command('install-wordpress')
    .description('Install WordPress in the wp-dind workspace (data/wordpress)')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .option('--url <url>', 'WordPress site URL')
    .option('--title <title>', 'WordPress site title')
    .option('--admin-user <user>', 'WordPress admin username')
    .option('--admin-password <password>', 'WordPress admin password')
    .option('--admin-email <email>', 'WordPress admin email')
    .option('--skip-install', 'Only download WordPress, skip installation')
    .action(async (options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();

        // Check if workspace is initialized
        const workspaceConfig = loadWorkspaceConfig(targetDir);
        if (!workspaceConfig) {
            console.error(chalk.red('This directory is not initialized as a wp-dind workspace.'));
            console.log(chalk.yellow('Run "wp-dind init" first.'));
            process.exit(1);
        }

        // Check if workspace mode
        if (workspaceConfig.workspaceType !== 'workspace') {
            console.error(chalk.red('This command only works in workspace mode.'));
            console.log(chalk.yellow('For multi-instance mode, use: wp-dind instance create <name>'));
            process.exit(1);
        }

        // Check if WordPress is already installed
        const wpPath = path.join(targetDir, 'data/wordpress');
        const wpConfigPath = path.join(wpPath, 'wp-config.php');

        if (fs.existsSync(wpConfigPath) && !options.skipInstall) {
            const answers = await inquirer.prompt([{
                type: 'confirm',
                name: 'overwrite',
                message: 'WordPress appears to be already installed. Reinstall?',
                default: false
            }]);

            if (!answers.overwrite) {
                console.log(chalk.yellow('Installation cancelled.'));
                process.exit(0);
            }
        }

        console.log(chalk.blue.bold('\n📦 Installing WordPress\n'));
        console.log(chalk.gray(`Workspace: ${workspaceConfig.workspaceName}`));
        console.log(chalk.gray(`Stack: ${workspaceConfig.workspaceStack.webserver}, PHP ${workspaceConfig.workspaceStack.phpVersion}, MySQL ${workspaceConfig.workspaceStack.mysqlVersion}`));
        console.log(chalk.gray(`Target: data/wordpress\n`));

        const spinner = ora('Downloading WordPress...').start();

        try {
            // Download WordPress using workspace-php container
            const downloadCmd = `docker-compose exec -T wordpress-dind docker exec workspace-php php -d memory_limit=512M /usr/local/bin/wp core download --path=/var/www/html --allow-root --force`;
            execCommand(downloadCmd, { cwd: targetDir, silent: true });

            spinner.succeed('WordPress downloaded successfully');

            if (options.skipInstall) {
                console.log(chalk.green('\n✅ WordPress downloaded to data/wordpress'));
                console.log(chalk.yellow('\nNext steps:'));
                console.log(chalk.gray('  1. Configure your database settings'));
                console.log(chalk.gray('  2. Run the WordPress installation manually\n'));
                return;
            }

            // Interactive configuration if not provided
            let installConfig = {
                url: options.url,
                title: options.title,
                adminUser: options.adminUser,
                adminPassword: options.adminPassword,
                adminEmail: options.adminEmail
            };

            const questions = [];

            if (!installConfig.url) {
                questions.push({
                    type: 'input',
                    name: 'url',
                    message: 'WordPress site URL:',
                    default: 'http://localhost:8000',
                    validate: (input) => input.trim() !== '' || 'URL is required'
                });
            }

            if (!installConfig.title) {
                questions.push({
                    type: 'input',
                    name: 'title',
                    message: 'Site title:',
                    default: workspaceConfig.workspaceName,
                    validate: (input) => input.trim() !== '' || 'Title is required'
                });
            }

            if (!installConfig.adminUser) {
                questions.push({
                    type: 'input',
                    name: 'adminUser',
                    message: 'Admin username:',
                    default: 'admin',
                    validate: (input) => input.trim() !== '' || 'Username is required'
                });
            }

            if (!installConfig.adminPassword) {
                questions.push({
                    type: 'password',
                    name: 'adminPassword',
                    message: 'Admin password:',
                    validate: (input) => input.length >= 8 || 'Password must be at least 8 characters'
                });
            }

            if (!installConfig.adminEmail) {
                questions.push({
                    type: 'input',
                    name: 'adminEmail',
                    message: 'Admin email:',
                    default: 'admin@example.com',
                    validate: (input) => {
                        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                        return emailRegex.test(input) || 'Invalid email address';
                    }
                });
            }

            if (questions.length > 0) {
                const answers = await inquirer.prompt(questions);
                installConfig = { ...installConfig, ...answers };
            }

            // Create wp-config.php using workspace-php container
            spinner.start('Creating wp-config.php...');
            const configCmd = `docker-compose exec -T wordpress-dind docker exec workspace-php wp config create --path=/var/www/html --dbname=wordpress --dbuser=wordpress --dbpass=wordpress --dbhost=workspace-mysql --allow-root --force`;
            execCommand(configCmd, { cwd: targetDir, silent: true });
            spinner.succeed('wp-config.php created');

            // Install WordPress using workspace-php container
            spinner.start('Installing WordPress...');
            const installCmd = `docker-compose exec -T wordpress-dind docker exec workspace-php wp core install --path=/var/www/html --url='${installConfig.url}' --title='${installConfig.title}' --admin_user='${installConfig.adminUser}' --admin_password='${installConfig.adminPassword}' --admin_email='${installConfig.adminEmail}' --allow-root`;
            execCommand(installCmd, { cwd: targetDir, silent: true });
            spinner.succeed('WordPress installed successfully');

            console.log(chalk.green('\n✅ WordPress installation complete!\n'));
            console.log(chalk.blue.bold('Access Information:'));
            console.log(chalk.gray(`  URL: ${installConfig.url}`));
            console.log(chalk.gray(`  Admin User: ${installConfig.adminUser}`));
            console.log(chalk.gray(`  Admin Email: ${installConfig.adminEmail}\n`));
            console.log(chalk.yellow('Next steps:'));
            console.log(chalk.gray('  1. Visit your WordPress site'));
            console.log(chalk.gray('  2. Log in with your admin credentials'));
            console.log(chalk.gray('  3. Start building your site!\n'));

        } catch (error) {
            spinner.fail('Installation failed');
            console.error(chalk.red('\nError during installation:'));
            console.error(error.message);
            process.exit(1);
        }
    });

program
    .command('destroy')
    .description('Destroy the WordPress DinD environment (removes all data)')
    .option('-d, --dir <directory>', 'Target directory (default: current directory)')
    .action(async (options) => {
        const targetDir = options.dir ? path.resolve(options.dir) : process.cwd();

        const answers = await inquirer.prompt([{
            type: 'confirm',
            name: 'confirm',
            message: chalk.red('This will remove all containers, volumes, data directory, and workspace files. Are you sure?'),
            default: false
        }]);

        if (!answers.confirm) {
            console.log(chalk.yellow('Cancelled.'));
            process.exit(0);
        }

        console.log(chalk.blue('Destroying WordPress DinD environment...\n'));

        // Stop and remove containers and volumes (if docker-compose.yml exists)
        const composeFile = path.join(targetDir, 'docker-compose.yml');
        if (fs.existsSync(composeFile)) {
            console.log(chalk.blue('Stopping and removing containers...'));
            try {
                execCommand('docker-compose down -v', { cwd: targetDir });
            } catch (error) {
                console.log(chalk.yellow('⚠️  Could not stop containers (they may not be running)'));
            }
        } else {
            console.log(chalk.yellow('⚠️  No docker-compose.yml found, skipping container removal'));
        }

        // Remove all files and directories in the workspace folder (use sudo to handle permission issues)
        console.log(chalk.blue('Removing all workspace files and directories...'));
        try {
            // Remove everything in the directory except . and ..
            execCommand(`sudo rm -rf "${targetDir}"/{*,.*} 2>/dev/null || true`, { cwd: targetDir });

            // Alternative: remove specific known files/directories
            const itemsToRemove = [
                'data',
                'logs',
                'shared-images',
                'wordpress-instances',
                'wp-dind-workspace.json',
                'docker-compose.yml',
                '.env',
                'README.md'
            ];

            for (const item of itemsToRemove) {
                const itemPath = path.join(targetDir, item);
                if (fs.existsSync(itemPath)) {
                    try {
                        execCommand(`sudo rm -rf "${itemPath}"`, { cwd: targetDir });
                    } catch (e) {
                        // Continue even if one item fails
                    }
                }
            }

            console.log(chalk.green('\n✅ Environment destroyed successfully!'));
            console.log(chalk.gray('All containers, volumes, data, and configuration files have been removed.'));
        } catch (error) {
            console.log(chalk.yellow('\n⚠️  Some files could not be removed automatically.'));
            console.log(chalk.yellow(`Please run manually: sudo rm -rf "${targetDir}"/*`));
        }
    });

program.parse(process.argv);

// Show help if no command provided
if (!process.argv.slice(2).length) {
    program.outputHelp();
}

