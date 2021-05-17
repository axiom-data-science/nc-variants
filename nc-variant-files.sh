#!/bin/bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

for c in awk; do
  if ! command -v $c &> /dev/null; then
    echo "$c is required" >&2
    exit 1
  fi
done

OUTDIR=out
while getopts ":o:" opt; do
  case ${opt} in
    o )
      OUTDIR=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

if [ $# -ne 1 ]; then
  echo "Single argument (gron search token) is required (example 'json.dimensions.time = 0;')" >&2
  exit 1
fi

TOKEN="$1"

cat $(grep -Rl "$TOKEN" out/*/nc.gron | awk '{gsub("/nc.gron$","/files", $0); print $0}') | sort
