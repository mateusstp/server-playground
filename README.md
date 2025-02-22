# Server Playground Setup Scripts

This repository contains a collection of scripts for setting up and configuring various server components on Ubuntu 20.04. Each script is designed to be modular and can be run independently.

## Quick Start

1. First, make all scripts executable:
```bash
./apply_permissions.sh
```

## Available Scripts

### 1. Cockpit Setup (`setup_cockpit.sh`)

Installs and configures Cockpit web console for server management.

```bash
sudo ./setup_cockpit.sh
```

After installation:
- Access Cockpit at: `https://your-server-ip:9090`
- Log in with your system credentials

### 2. Firewall Configuration (`configure_firewall.sh`)

Configures UFW (Uncomplicated Firewall) with deny-all incoming policy except for essential services.

```bash
sudo ./configure_firewall.sh
```

This script:
- Sets default deny incoming policy
- Allows outgoing connections
- Preserves SSH access (port 22)
- Maintains Cockpit access (port 9090)

### 3. Ngrok Tunneling (`setup_ngrok.sh`)

Sets up ngrok for HTTPS and TCP tunneling to make local services accessible over the internet.

#### Prerequisites
1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit the `.env` file and add your configuration:
```bash
nano .env
```

Required environment variables:
```env
NGROK_AUTH_TOKEN=""        # Your ngrok authentication token
NGROK_HTTPS_PORT="8080"    # Local port for HTTPS tunnel
NGROK_TCP_PORT="4000"      # Local port for TCP tunnel
NGROK_REGION="us"          # Ngrok region (us, eu, au, ap, sa, jp, in)
```

3. Run the setup script:
```bash
./setup_ngrok.sh
```

After starting:
- View tunnel status at: `http://localhost:4040`
- Public URLs will be displayed in the console
- Stop tunnels with: `pkill ngrok`

## Security Considerations

1. Always change default passwords and use strong authentication
2. Keep your ngrok authentication token secure
3. Regularly update your system and installed packages
4. Monitor system logs for suspicious activity
5. Only open necessary ports in the firewall

## Troubleshooting

### Cockpit Issues
- Check service status: `systemctl status cockpit.socket`
- View logs: `journalctl -u cockpit.socket`

### Firewall Issues
- Check UFW status: `sudo ufw status verbose`
- View logs: `sudo tail -f /var/log/ufw.log`

### Ngrok Issues
- Check ngrok process: `ps aux | grep ngrok`
- View web interface at: `http://localhost:4040`
- Check .env file permissions and contents

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.