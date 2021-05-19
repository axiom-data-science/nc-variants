#!/bin/bash

set -eu -o pipefail

for c in sed; do
  if ! command -v $c &> /dev/null; then
    echo "$c is required" >&2
    exit 1
  fi
done

OUTDIR=out
GREP_FILE_LIST_ARG="-l" #by default show all files matching
while getopts ":mo:" opt; do
  case ${opt} in
    m )
      GREP_FILE_LIST_ARG="-L" #optionally show all files not matching
      ;;
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

#give cat /dev/null so it doesn't hang trying to read stdin if no files matched
cat /dev/null $(grep $GREP_FILE_LIST_ARG -RF "$TOKEN" $OUTDIR/*/nc.gron | sed 's/nc\.gron$/files/') | sort
