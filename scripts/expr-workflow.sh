#!/usr/bin/env bash
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

msg() {
  echo >&2 -e "${1-}"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

start_server() {
  java -jar $script_dir/../out/FelisController/assembly.dest/out.jar $script_dir/../config.json > /dev/null &
  sleep 2
}

setup_controller_script() {
  ./setup.sh -c $1
}

run_all() {
  setup_controller_script "low"
  java -jar $script_dir/../out/FelisExperiments/assembly.dest/out.jar $1
  mv $script_dir/../../felis/results/singlenode-tpcc/ $script_dir/../../felis/results/singlenodelow-tpcc/

  setup_controller_script "mod"
  java -jar $script_dir/../out/FelisExperiments/assembly.dest/out.jar $1

  setup_controller_script "high"
  java -jar $script_dir/../out/FelisExperiments/assembly.dest/out.jar $1
}

check_pattern() {
  # Check if the line matches the expected pattern
  # $1: line_number, $2: file, $3: pattern
  if ! sed -n "$1p" "$2" | grep -qF "$3"; then
    msg "Error: Line $1 in $2 does not match macro."
    exit 1
  fi
}

aggregate_res() {
  local low_dir="singlenodelow-tpcc"
  local mod_dir="singlenode-tpcc"
  local high_dir="singlewarehouse-tpcc"

  local stats_script="$script_dir/../../felis/scripts/stats.sh"
  local aggre_script="$script_dir/../../felis/scripts/aggregate_res.sh"
  local agg_res_path="$script_dir/../../felis/scripts/agg_res.txt"
  local line=11
  local pattern="res_path="
  check_pattern $line $stats_script $pattern
  check_pattern $line $aggre_script $pattern

  set_res_path() {
    local res_path_pattern="${line}s/results\/[a-z]*-tpcc/results\/$1/"
    sed -i $res_path_pattern "${stats_script}"
    sed -i $res_path_pattern "${aggre_script}"
  }

  set_res_path $low_dir
  $stats_script && $aggre_script
  mv "$script_dir/agg_res.txt" "$script_dir/tpcc_low_cont.txt"

  set_res_path $mod_dir
  $stats_script && $aggre_script
  mv "$script_dir/agg_res.txt" "$script_dir/tpcc_mod_cont.txt"

  set_res_path $high_dir
  $stats_script && $aggre_script
  mv "$script_dir/agg_res.txt" "$script_dir/tpcc_high_cont.txt"
}

# workflow
start_server

run_all "runTpccLatency"
aggregate_res
