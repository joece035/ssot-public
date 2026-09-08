#!/usr/bin/env bash
# ============================================================
# 🌐 SSOT Dynamic Node Registry Loader
# ============================================================
# File: nodes/loader.sh
# Purpose: Auto-discovers and sources all *.node.env profiles
#          No hardcoding of node names required!
# ============================================================

_SSOT_NODES_DIR="${SSOT:-$HOME/ssot}/nodes"
SSOT_REGISTERED_NODES=()

if [[ -d "$_SSOT_NODES_DIR" ]]; then
    for _node_file in "$_SSOT_NODES_DIR"/*.node.env; do
        if [[ -f "$_node_file" ]]; then
            source "$_node_file"
            _node_basename="${_node_file##*/}"
            _node_name="${_node_basename%%.node.env}"
            SSOT_REGISTERED_NODES+=("$_node_name")
        fi
    done
    export SSOT_REGISTERED_NODES
fi

# Compatibility aliases for legacy consumers
export TERMUX_IP="${NODE_TERMUX_HOST:-${NODE_TERMUX_IP:-}}"
export TERMUX_USER="${NODE_TERMUX_USER:-u0_a331}"
export TERMUX_PORT="${NODE_TERMUX_PORT:-8022}"
export TERMUX_TELSCAIL_IP="${NODE_TERMUX_HOST:-termux}"
