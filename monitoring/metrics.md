# AvalancheGo Monitoring Quick Reference

## Readiness and Sync
- **Health check**: `curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' -H 'content-type:application/json' http://localhost:9650/ext/health | jq`
  - Look for `"healthy": true` and `"checks"` entries `network` and `router health` to confirm sync.

- **Peer count**: `curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' -H 'content-type:application/json' http://localhost:9650/ext/info | jq '.result.numPeers'`
  - Target: increasing number (dozens+) indicates good connectivity.

- **Node status**: `curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}' -H 'content-type:application/json' http://localhost:9650/ext/info | jq`
  - `true` means the chain is fully synced.

## Resource usage
- **Prometheus endpoint** (enable via compose): `curl -s http://localhost:9650/ext/metrics | head`
  - Key gauges/counters:
    - `avalanche_network_peer_count`
    - `avalanche_network_bytes_sent` / `received`
    - `avalanche_healthchecks_network_healthy`
    - `go_memstats_*` and `process_cpu_seconds_total`

## Validator progress
- **Staking status** (once added): `curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"platform.getCurrentValidators","params":{"nodeIDs":["<NodeID>"]}}' -H 'content-type:application/json' http://localhost:9650/ext/bc/P | jq`
  - Confirms your NodeID is in the current validator set and shows `endTime` for the delegation period.

## Log inspection
- **Follow logs**: `docker compose logs -f avalanchego`
  - Watch for repeated peer disconnections, failed bootstraps, or disk errors.

## Alert ideas
- Notify if:
  - `info.isBootstrapped` returns `false` for more than 5 minutes.
  - `numPeers` drops below a threshold (e.g., < 10).
  - Prometheus `process_resident_memory_bytes` crosses chosen limit.
  - Container restarts (`docker inspect -f '{{.RestartCount}}' avalanchego`).
