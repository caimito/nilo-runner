# Nilo Runner

Public distribution for the Nilo Linux Runner.

## Quick Install

```bash
curl -sfL https://raw.githubusercontent.com/caimito/nilo-runner/main/install.sh | sudo bash
```

This will:
1. Detect your system architecture (amd64 or arm64)
2. Download the latest binary from this repository's releases
3. Install it to `/usr/local/bin/nilo-runner-linux`
4. Create a systemd service
5. Prompt you for the remote URL and registration key
6. Enable and start the service

## Manual Download

```bash
# amd64
curl -fsSL -o /usr/local/bin/nilo-runner-linux \
  https://github.com/caimito/nilo-runner/releases/download/latest/nilo-runner-linux-amd64

# arm64
curl -fsSL -o /usr/local/bin/nilo-runner-linux \
  https://github.com/caimito/nilo-runner/releases/download/latest/nilo-runner-linux-arm64

chmod +x /usr/local/bin/nilo-runner-linux
```

## What is Nilo Runner?

The Nilo Linux Runner is a lightweight daemon that connects a Linux machine to [Nilo Assistant](https://niloassistant.com), enabling local LLM execution and job processing. It runs as a systemd service and communicates with Nilo via WebSocket.

## Support

For support, contact your Nilo representative or visit [niloassistant.com](https://niloassistant.com).
