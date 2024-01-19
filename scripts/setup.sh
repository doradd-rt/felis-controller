#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  # TODO: mod flag as core_count
  flag=0
  contention=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -f | --flag) flag=1 ;; # example flag
    -c | --contention)
      contention="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${contention-}" ]] && die "Missing required parameter: contention"
  case "$contention" in
    "low" | "mid" | "high")
        echo "Parameter is valid: $contention"
        ;;
    *)
        echo "Error: Invalid parameter. It must be 'low', 'mid', or 'high'."
        exit 1
        ;;
  esac

  # [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

parse_params "$@"
setup_colors

# script logic here

msg "${RED}Read parameters:${NOFORMAT}"
msg "- contention: ${contention}"

check_pattern() {
  # Check if the line matches the expected pattern
  # $1: line_number, $2: file, $3: pattern
  if ! sed -n "$1p" "$2" | grep -qF "$3"; then
    msg "Error: Line $1 in $2 does not match split macro."
    exit 1
  fi
}

contention_setup() {
  # config warehouse cnts and replayed logs
  local file="../FelisExperiments/src/FelisExperimentsMain.scala"

  local warehouse_pattern="def warehouses = *"
  local warehouse_line=400
  local logpath_pattern="val replayed_log_path = *"
  local logpath_line=279
  local flag_pattern="val singleWarehouse = *"
  local flag_line=721

  check_pattern $warehouse_line $file $warehouse_pattern

  set_warehouse() {
    sed -i "${warehouse_line}s/else [0-9]\{1,2\}/else $1/" "$file"
  }

  check_pattern $logpath_line $file $logpath_pattern

  set_log_path() {
    # TODO: might need to mod dir
    sed -i "${logpath_line}s/tpcc_[a-z]\{2,4\}_cont/tpcc_$1_cont/" "$file"
  }

  check_pattern $flag_line $file $flag_pattern

  set_flag() {
    sed -i "${flag_line}s/= [a-z]*/= $1/" "$file"
  }

  case "$contention" in
    "low" )
      msg "low contention"
      set_warehouse 23
      set_log_path "no"
      set_flag "false"
      ;;
    "mid" )
      msg "mid contention"
      set_warehouse 8
      set_log_path "mid"
      set_flag "false"
      ;;
    "high" )
      msg "high contention"
      set_log_path "high"
      set_flag "true"
      ;;
  esac
  cd ..
  sudo ./mill -d FelisExperiments.assembly
  msg "finish compiling and ready to run"
}

contention_setup
