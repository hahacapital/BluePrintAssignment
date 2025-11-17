# Avalanche Fuji Validator (Docker + docker-compose)

This repo contains everything needed to bring up an Avalanche Fuji (testnet) validator on Ubuntu 22.04 using Docker and docker-compose. It assumes an EC2 host with public IP `54.193.165.179` and private IP `172.31.24.68`, but the steps work for any Ubuntu 22.04 host.

## Contents
- `docker-compose.yml` – avalanchego service definition for Fuji with metrics and indexing enabled (data mounted to `/root/.avalanchego` in the container).
- `config/config.json` – runtime configuration consumed via `--config-file`.
- `scripts/install_docker.sh` – installs Docker Engine and Compose plugin.
- `scripts/start_validator.sh` – starts avalanchego with your `PUBLIC_IP` export.
- `scripts/check_health.sh` – quick health RPC probe.
- `monitoring/metrics.md` – monitoring queries and metric names to track validator health.

## Prerequisites
- Ubuntu 22.04 server with ports 9650 (HTTP API) and 9651 (staking) reachable from the internet.
- A non-root user with sudo (e.g., `ubuntu`) and SSH access.
- `jq` for JSON formatting: `sudo apt-get install -y jq`.

## 1) Install Docker and docker-compose
SSH to the EC2 host and run:

```bash
cd ~/BluePrintAssignment
chmod +x scripts/install_docker.sh
./scripts/install_docker.sh
```

## 2) Configure avalanchego
The compose service uses `--config-file` plus a runtime `PUBLIC_IP` override. Export your reachable public IP before starting (required for staking):

```bash
export PUBLIC_IP=54.193.165.179  # replace with your host's public IP
```

If you prefer a static configuration file, you can also set `"public-ip"` inside `config/config.json`, but the `PUBLIC_IP` environment variable will take precedence.

## 3) Start the node
```bash
export PUBLIC_IP=54.193.165.179  # replace if different
chmod +x scripts/start_validator.sh
./scripts/start_validator.sh
```
Check logs and health:
```bash
docker compose logs -f --tail=200
./scripts/check_health.sh
```
You should see `"healthy": true` after bootstrap and a non-zero peer count via `info.peers`.

> Note: the container now runs as root and writes to `/root/.avalanchego`. If you previously ran with a non-root user, reset the host data directory permissions with `sudo chown -R root:root data` to avoid plugin directory permission errors.

## 4) Get your NodeID
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' -H 'content-type:application/json' http://localhost:9650/ext/info | jq '.result'
```
Record the `nodeID` for validator registration.

## 5) Obtain Fuji AVAX
Use the Avalanche Faucet with a Fuji wallet address (Avalanche Wallet or Core extension) to request sufficient testnet AVAX to cover stake + fees. Target at least 2 AVAX for validator stake minimums on Fuji.

## 6) Add the validator (14-day minimum)
Once `info.isBootstrapped` reports `true` for X/P/C chains and peers are stable:

1. Export the staking certificate key pair if needed (stored in `./data/staking`).
2. Use **Avalanche-CLI** (recommended) or the **Avalanche Wallet** to add your validator:
   ```bash
   # Install Avalanche-CLI (example)
curl -sSfL https://github.com/ava-labs/avalanche-cli/releases/latest/download/avalanche-cli_linux_amd64.tar.gz -o avalanche-cli.tar.gz
tar -xzf avalanche-cli.tar.gz
sudo mv avalanche /usr/local/bin/

   # Add validator (replace placeholders)
avalanche validator add \
  --node-id <YourNodeID> \
  --tx-fee 2000000 \
  --stake-amount 2000000000 \
  --start-time "now+2m" \
  --end-time "now+14d" \
  --reward-address <YourPChainAddress> \
  --change-address <YourPChainAddress> \
  --network fuji
   ```
   Alternatively, in the Avalanche Wallet: **Earn → Validate → Add Validator** and paste your `NodeID`, start/end times (14 days minimum), stake amount, and reward address.

Transaction confirmation can be tracked via the Fuji explorer once mined.

## 7) Monitoring essentials
See `monitoring/metrics.md` for command snippets. Key points:
- `health.health` == `healthy: true`
- `info.peers` numPeers steadily > 0
- `platform.getCurrentValidators` includes your `NodeID`
- Prometheus metrics available at `:9650/ext/metrics`

## 8) Validator visibility
After the validator tx is accepted, find your node on the Fuji explorer by searching for the NodeID. Share the explorer URL for validation statistics as a deliverable.

## Data persistence and upgrades
- All state lives in `./data`, which maps to `/root/.avalanchego` inside the container; keep the volume attached between restarts.
- To upgrade avalanchego: update `image: avaplatform/avalanchego:<version>` in `docker-compose.yml` then run `docker compose pull && docker compose up -d`.

## Operational tips
- Ensure EC2 security group allows inbound TCP/UDP 9651 and TCP 9650.
- Use `systemctl status docker` if the service stops unexpectedly.
- Snapshot the EBS volume before upgrades.

## Cleaning up
```bash
docker compose down --volumes
rm -rf data
```
