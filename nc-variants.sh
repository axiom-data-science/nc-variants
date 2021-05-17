#!/bin/bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

for c in awk gron jq md5sum ncks sed; do
  if ! command -v $c &> /dev/null; then
    echo "$c is required" >&2
    exit 1
  fi
done

OUTDIR=out
IGNORE_FIELDS=".attributes.history"
SHOW_FILES_THRESHOLD_PERCENT=50
QUIET=0

while getopts ":i:o:qt:" opt; do
  case ${opt} in
    i )
      IGNORE_FIELDS="$IGNORE_FIELDS,$OPTARG"
      ;;
    o )
      OUTDIR=$OPTARG
      ;;
    q )
      QUIET=1
      ;;
    t )
      SHOW_FILES_THRESHOLD_PERCENT=$OPTARG
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
  echo "Single argument (directory containing nc files) is required" >&2
  exit 1
fi

NCDIR=$1

if [ -z "$NCDIR" ]; then
  echo "Must provide path to directory with nc files as argument" >&2
  exit 1
fi

if [ ! -e "$NCDIR" ]; then
  echo "$NCDIR doesn't exist" >&2
  exit 1
fi

if [ ! -d "$NCDIR" ]; then
  echo "$NCDIR is not a directory" >&2
  exit 1
fi

if [ -d "$OUTDIR" ]; then
  if [ $QUIET -ne 1 ]; then
    echo "$OUTDIR exists, deleting old contents..."
  fi
  rm -rf "$OUTDIR"/*
fi
mkdir -p "$OUTDIR"

function log() {
  if [ $QUIET -ne 1 ]; then
    echo "$1"
  fi
}

log "Scanning $NCDIR"

find "$NCDIR" -name '*.nc' | while read -r nc; do
  log "Checking $nc"

  NCJSON=$(ncks --json -mM "$nc" | jq "del($IGNORE_FIELDS)")
  MD5=$(printf '%s' "$NCJSON" | md5sum | awk '{print $1}')
  if [ ! -d "$OUTDIR/$MD5" ]; then
    log "Found new variant $MD5"
    mkdir "$OUTDIR/$MD5"
    echo "$NCJSON" > "$OUTDIR/$MD5/nc.json"
    gron "$OUTDIR/$MD5/nc.json" > "$OUTDIR/$MD5/nc.gron"
  fi

  echo "$nc" >> "$OUTDIR/$MD5/files"
done

#prepend each line of each gron file with the number of nc files with this format for later summing
find "$OUTDIR/" -mindepth 1 -maxdepth 1 -type d | while read -r variant; do
  awk -v files=$(wc -l < $variant/files) '{print files "|" $0}' $variant/nc.gron > $variant/nc.wgron
done

#make variance report

#cat together all of the nc.wgron files (containing number of files with each format as a first column), and then
#sum up the number of files containing each gron value. "json = {};" is summed as a special case to get the total
#number of files (all files are guaranteed to have this since its the root of the json document)
#create a report file with the frequency (percent and ratio) of each gron value, removing the array and object initializers
#also remove the 'json.' prefix from each gron value
cat $(find "$OUTDIR/" -name 'nc.wgron') | \
  awk -F '|' '{c[$2]+=$1} $2=="json = {};" {total_files+=$1 } END {for (l in c) printf "%5.1f%%|(%" length(total_files) "i/%i)|%s\n", c[l]*100/total_files, c[l], total_files, l}' \
  | grep -v '= {};$\|= \[\];$' | sed 's/|json\./|/' | sort -t '|' -k3 > "$OUTDIR/nc-variants.tmp"

#loop through the gron value report and under each non-standard gron value (below the SHOW_FILES_THRESHOLD_PERCENT)
#append the lis of files containing that value
while read; do
  #REPLY is set if no var name is specified in `read` above, AND it preserves leading whitespace!
  echo "$REPLY" | tr '|' ' ' >> "$OUTDIR/nc-variants.out"
  PERCENT=$(echo $REPLY | cut -d . -f 1)

  if [ $PERCENT -lt $SHOW_FILES_THRESHOLD_PERCENT ]; then
    TOKEN=$(echo $REPLY | cut -d '|' -f 3)
    ./nc-variant-files.sh -o "$OUTDIR" "$TOKEN" | awk '{print "    " $0}' >> "$OUTDIR/nc-variants.out"
  fi
done < "$OUTDIR/nc-variants.tmp"

rm "$OUTDIR/nc-variants.tmp"

#show final report in less if less if present and this is a tty, otherwise cat it
if command -v less &> /dev/null && [ -t 1 ]; then
  less "$OUTDIR/nc-variants.out"
else
  cat "$OUTDIR/nc-variants.out"
fi
