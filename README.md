# Avalanche Fuji Validator (Docker + docker-compose)

This repo contains everything needed to bring up an Avalanche Fuji (testnet) validator on Ubuntu 22.04 using Docker and docker-compose. It assumes an EC2 host with public IP `54.193.165.179` and private IP `172.31.24.68`, but the steps work for any Ubuntu 22.04 host.

## Contents
- `docker-compose.yml` – avalanchego service definition for Fuji with metrics and indexing enabled (data mounted to `/root/.avalanchego` in the container).
- `config/config.json` – runtime configuration consumed via `--config-file` (mounted read-only to `/config/config.json` in the container so it is not shadowed by the data volume).
- `scripts/install_docker.sh` – installs Docker Engine and Compose plugin.
- `scripts/start_validator.sh` – starts avalanchego with your `PUBLIC_IP` export.
- `scripts/check_health.sh` – quick health RPC probe.
- `scripts/monitor.sh` – one-shot view of readiness, validator status, and key Prometheus metrics.


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
The compose service uses `--config-file=/config/config.json` plus a runtime `PUBLIC_IP` override. Export your reachable public IP before starting (required for staking):

```bash
export PUBLIC_IP=54.193.165.179  # replace with your host's public IP
```

If you prefer a static configuration file, you can also set `"public-ip"` inside `config/config.json`, but the `PUBLIC_IP` environment variable will take precedence. If you change the network or staking port in the config, wipe old data with `docker compose down --volumes && rm -rf data` to avoid mixing incompatible state.

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
1. [TESTNET FAUCET](https://core.app/tools/testnet-faucet) Go to this link to obtain testnet AVAX
2. [Cross Chain](https://core.app/stake/cross-chain-transfer) Cross Chain transfer at least 1 AVAX from C-Chain to P-Chain

## 6) Add the validator (14-day minimum)
Once `info.isBootstrapped` reports `true` for X/P/C chains and peers are stable:
Use [Validate](https://core.app/stake/validate) to register node as validator

## 7) Monitoring essentials
Use the bundled monitor script to print readiness, validator progress, and the requested metrics in one run:

```bash
chmod +x scripts/monitor.sh
NODE_ID=NodeID-KPS44VwPPYEaN1gVmaoDqZHHfs4rbWA9Q ./scripts/monitor.sh
# Override HOST/PORT/NODE_ID to target a different node
```

## 8) Validator visibility
[TestNet Explorer for NodeID-KPS44VwPPYEaN1gVmaoDqZHHfs4rbWA9Q](https://subnets-test.avax.network/validators/NodeID-KPS44VwPPYEaN1gVmaoDqZHHfs4rbWA9Q)

## 9) Data persistence and upgrades
- All state lives in `./data`, which maps to `/root/.avalanchego` inside the container; keep the volume attached between restarts.
- To upgrade avalanchego: update `image: avaplatform/avalanchego:<version>` in `docker-compose.yml` then run `docker compose pull && docker compose up -d`.

## 10) Operational tips
- Ensure EC2 security group allows inbound TCP/UDP 9651 and TCP 9650.
- Use `systemctl status docker` if the service stops unexpectedly.
- Snapshot the EBS volume before upgrades.

## 11) Cleaning up
```bash
docker compose down --volumes
rm -rf data
```
