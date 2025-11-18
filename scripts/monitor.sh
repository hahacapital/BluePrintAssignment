#!/usr/bin/env bash
set -euo pipefail

HOST=${HOST:-"localhost"}
PORT=${PORT:-"9650"}
NODE_ID=${NODE_ID:-"NodeID-KPS44VwPPYEaN1gVmaoDqZHHfs4rbWA9Q"}

print_section() {
  echo -e "\n=== $1 ==="
}

call_rpc() {
  local method=$1
  local params=${2:-"{}"}
  curl -s -X POST \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"${method}\",\"params\":${params}}" \
    -H 'content-type:application/json' \
    http://"${HOST}":"${PORT}"/ext/$( [[ $method == platform.* ]] && echo bc/P || ([[ $method == health.* ]] && echo health || echo info ))
}

metrics_payload=$(curl -s http://"${HOST}":"${PORT}"/ext/metrics || true)

print_metric() {
  local metric=$1
  local label=$2
  local value
  value=$(awk -v m="$metric" '$1 ~ "^" m "(\\{|$)" {print $2; exit}' <<<"${metrics_payload}")
  if [[ -n ${value} ]]; then
    printf "%s: %s\n" "$label" "$value"
  else
    printf "%s: (not found)\n" "$label"
  fi
}

print_section "Readiness & Sync"
health=$(call_rpc "health.health")
bool_health=$(jq -r '.result.healthy // false' <<<"${health}")
bootstrapped=$(call_rpc "info.isBootstrapped" '{"chain":"C"}' | jq -r '.result.isBootstrapped // false')
peer_count=$(call_rpc "info.peers" | jq -r '.result.numPeers // 0')
echo "Health: ${bool_health}"
echo "Bootstrapped (C-Chain): ${bootstrapped}"
echo "Responsive peers: ${peer_count}"

print_section "Validator Status"
validators=$(call_rpc "platform.getCurrentValidators" "{\"nodeIDs\":[\"${NODE_ID}\"]}")
validator_found=$(jq -r '.result.validators | length' <<<"${validators}")
if [[ ${validator_found} -gt 0 ]]; then
  start_time=$(jq -r '.result.validators[0].startTime // ""' <<<"${validators}")
  end_time=$(jq -r '.result.validators[0].endTime // ""' <<<"${validators}")
  printf "Validator present for %s\n" "${NODE_ID}"
  [[ -n ${start_time} ]] && printf "Start: %s | End: %s\n" "${start_time}" "${end_time}"
else
  echo "Validator not found in current set (NodeID: ${NODE_ID})."
fi

print_section "Prometheus Metrics"
print_metric "avalanche_network_peers" "Network peers"
print_metric "avalanche_p2p_peer_tracker_num_responsive_peers" "Responsive peers (tracker)"
print_metric "avalanche_network_node_uptime_weighted_average" "Uptime (weighted avg)"
print_metric "avalanche_network_node_uptime_rewarding_stake" "Rewarding stake"
print_metric "avalanche_platformvm_local_staked" "Local stake"
print_metric "avalanche_platformvm_time_until_unstake" "Time until unstake"
print_metric "avalanche_snowman_last_accepted_height" "Last accepted height"
print_metric "avalanche_snowman_bootstrap_finished" "Bootstrap finished"
print_metric "avalanche_requests_average_latency" "Average latency"
print_metric "avalanche_requests_timeouts" "Request timeouts"
print_metric "avalanche_requests_dropped" "Requests dropped"
print_metric "avalanche_resource_tracker_cpu_usage" "CPU usage"
print_metric "avalanche_resource_tracker_disk_available_space" "Disk available"
print_metric "avalanche_process_process_resident_memory_bytes" "Resident memory"

print_section "Notes"
echo "Override HOST/PORT/NODE_ID env vars to point to a different node."
