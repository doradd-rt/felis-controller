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
    "low" | "mod" | "high")
        echo "Parameter is valid: $contention"
        ;;
    *)
        echo "Error: Invalid parameter. It must be 'low', 'mod', or 'high'."
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

set_cont() {
  local mode=$1  # "no" or "yes"
  local file="${script_dir}/../FelisExperiments/src/FelisExperimentsMain.scala"
  local line_number=56

  if [ "$mode" == "no" ]; then
    # Check if the line is commented
    if sed -n "${line_number}p" "$file" | grep -qE '^\s*//'; then
      # Uncomment the line by removing "//"
      sed -i "${line_number}s|^\s*//||" "$file"
      echo "Line $line_number has been uncommented."
    else
      echo "Line $line_number is already uncommented."
    fi
  elif [ "$mode" == "yes" ]; then
    # Check if the line is uncommented
    if ! sed -n "${line_number}p" "$file" | grep -qE '^\s*//'; then
      # Comment the line by adding "//" at the front
      sed -i "${line_number}s|^|//|" "$file"
      echo "Line $line_number has been commented."
    else
      echo "Line $line_number is already commented."
    fi
  else
    echo "Invalid mode. Use 'no' to uncomment or 'yes' to comment."
    return 1
  fi
}

contention_setup() {
  # config warehouse cnts and replayed logs
  local file="${script_dir}/../FelisExperiments/src/FelisExperimentsMain.scala"

  local logpath_pattern="val replayed_log_path = *"
  local logpath_line=276

  check_pattern $logpath_line $file $logpath_pattern

  set_log_path() {
    # TODO: might need to mod dir
    sed -i "${logpath_line}s/uniform_[a-z]\{2,4\}_cont/uniform_$1_cont/" "$file"
  }

  case "$contention" in
    "low" )
      msg "low contention"
      set_log_path "no"
      set_cont "no"
      ;;
    "mod" )
      msg "mod contention"
      set_log_path "mod"
      set_cont "yes"
      ;;
    "high" )
      msg "high contention"
      set_log_path "high"
      set_cont "yes"
      ;;
  esac
  cd ..
  sudo ./mill -d FelisExperiments.assembly
  msg "finish compiling and ready to run"
}

contention_setup
