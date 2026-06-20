#!/bin/bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

for c in awk bc gron jq md5sum ncks sed; do
  if ! command -v $c &> /dev/null; then
    echo "$c is required" >&2
    exit 1
  fi
done

OUTDIR=out
IGNORE_FIELDS=".attributes.history"
SHOW_FILES_THRESHOLD_PERCENT=50
QUIET=0
TIME_VAR=time

while getopts ":i:o:pqt:" opt; do
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
    p )
      SHOW_FILES_THRESHOLD_PERCENT=$OPTARG
      ;;
    t )
      TIME_VAR=$OPTARG
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
    echo "$1" >&2
  fi
}

log "Scanning $NCDIR"

mkdir -p "$OUTDIR/ncjson"

function get_nc_data() {
  NCDIR="$1"
  OUTDIR="$2"
  NCPATH="$3"
  TIME_VAR="$4"
  IGNORE_FIELDS="$5"
  NC="${NCDIR}/${NCPATH}"
  mkdir -p "$OUTDIR/ncjson/$(dirname ${NCPATH})"
  ncks --json -mM "$NC" | jq "del($IGNORE_FIELDS)" > $OUTDIR/ncjson/${NCPATH}.json
  echo $NC $(ncks --json -v ${TIME_VAR} --dt_fmt=3 "$NC" | jq -r --arg TIMEVAR ${TIME_VAR} '.variables[$TIMEVAR].data | "\(length) \(first)Z \(last)Z"') >> "$OUTDIR/times"
}

export -f get_nc_data

(cd "$NCDIR" && find . -name '*.nc') | xargs -I {} -P 8 bash -c 'get_nc_data "$@"' _ "$NCDIR" "$OUTDIR" "{}" "$TIME_VAR" "$IGNORE_FIELDS"

find "$OUTDIR/ncjson" -type f -name "*.json" | while read -r NCJSON; do
  MD5=$(md5sum $NCJSON | awk '{print $1}')

  if [ ! -d "$OUTDIR/variants/$MD5" ]; then
    log "Found new variant $MD5"
    mkdir -p "$OUTDIR/variants/$MD5"
    cp "$NCJSON" "$OUTDIR/variants/$MD5/nc.json"
    gron "$OUTDIR/variants/$MD5/nc.json" > "$OUTDIR/variants/$MD5/nc.gron"
  fi

  echo "$NCJSON" >> "$OUTDIR/variants/$MD5/files"
done

log "Generating report..."

#sort start/end times
log "Sorting times"
sort -o "$OUTDIR/times" "$OUTDIR/times"

#prepend each line of each gron file with the number of nc files with this format for later summing
log "Prepending num files to gron"
find "$OUTDIR/variants" -mindepth 1 -maxdepth 1 -type d | while read -r variant; do
  awk -v files=$(wc -l < $variant/files) '{print files "|" $0}' $variant/nc.gron > $variant/nc.wgron
done

#make variance report

#cat together all of the nc.wgron files (containing number of files with each format as a first column), and then
#sum up the number of files containing each gron value. "json = {};" is summed as a special case to get the total
#number of files (all files are guaranteed to have this since its the root of the json document)
#create a report file with the frequency (percent and ratio) of each gron value, removing the array and object initializers
#also remove the 'json.' prefix from each gron value
log "Catting nc.wgron files"
cat $(find "$OUTDIR/variants" -name 'nc.wgron') | \
  awk -F '|' '{c[$2]+=$1} $2=="json = {};" {total_files+=$1 } END {for (l in c) printf "%5.1f%%|(%" length(total_files) "i/%i)|%s\n", c[l]*100/total_files, c[l], total_files, l}' \
  | grep -v '= {};$\|= \[\];$' | sed 's/|json\./|/' | sort -t '|' -k3 > "$OUTDIR/nc-variants.tmp"

#loop through the gron value report and under each non-standard gron value (below the SHOW_FILES_THRESHOLD_PERCENT)
#append the list of files containing that value
LASTKEY=""
LASTKEY_PERCENT_DECIMAL=0
LASTKEY_TOTAL_FILES=0
log "Looping through report"
while read -r; do
  #REPLY is set if no var name is specified in `read` above, AND it preserves leading whitespace!
  PERCENT=$(echo "$REPLY" | cut -d . -f 1)

  if [ "$PERCENT" -eq 100 ]; then
    #short circuit if this attribute is 100% consistent
    LASTKEY=""
    LASTKEY_PERCENT_DECIMAL=0
    LASTKEY_TOTAL_FILES=0
    echo "$REPLY" | tr '|' ' '
    continue
  fi

  PERCENT_DECIMAL=$(echo "$REPLY" | cut -d % -f 1)
  TOKEN=$(echo "$REPLY" | cut -d '|' -f 3)
  KEY=$(echo "$TOKEN" | cut -d ' ' -f 1)
  KEY_TOTAL_FILES=$(echo "$REPLY" | sed 's|[()]|/|g' | cut -d '/' -f 3)

  #first check if we need to check for missing values from the last key
  if [ -n "$LASTKEY" ] && [ "$KEY" != "$LASTKEY" ]; then
    FILES_MISSING_KEY="$("$DIR/nc-variant-files.sh" -m -o "$OUTDIR" "$LASTKEY")"
    if [ -n "$FILES_MISSING_KEY" ]; then
      NUM_FILES_MISSING_KEY=$(echo "$FILES_MISSING_KEY" | wc -l)
      TOTAL_FILES_CHAR_LENGTH=$(echo "$LASTKEY_TOTAL_FILES" | wc -c)
      MISSING_PERCENT=$(echo "100.0 - $LASTKEY_PERCENT_DECIMAL" | bc)
      if [ $(echo "$MISSING_PERCENT < $SHOW_FILES_THRESHOLD_PERCENT" | bc) -eq 1 ]; then
        printf "%5.1f%% (%${TOTAL_FILES_CHAR_LENGTH}i/%i) %s = null\n" "$MISSING_PERCENT" "$NUM_FILES_MISSING_KEY" "$LASTKEY_TOTAL_FILES" "$LASTKEY"
        echo "$FILES_MISSING_KEY" | awk '{print "    " $0}'
      fi
    fi
    LASTKEY_PERCENT_DECIMAL=0
  fi

  LASTKEY="$KEY"
  LASTKEY_PERCENT_DECIMAL=$(echo "$LASTKEY_PERCENT_DECIMAL + $PERCENT_DECIMAL" | bc)
  LASTKEY_TOTAL_FILES="$KEY_TOTAL_FILES"

  echo "$REPLY" | tr '|' ' '
  if [ $(echo "$PERCENT < $SHOW_FILES_THRESHOLD_PERCENT" | bc) -eq 1 ]; then
    "$DIR/nc-variant-files.sh" -o "$OUTDIR" "$TOKEN" | awk '{print "    " $0}'
  fi
done < "$OUTDIR/nc-variants.tmp" > "$OUTDIR/nc-variants.out"

rm "$OUTDIR/nc-variants.tmp"

#show final report in less if less if present and this is a tty, otherwise cat it
if command -v less &> /dev/null && [ -t 1 ]; then
  less "$OUTDIR/nc-variants.out"
else
  cat "$OUTDIR/nc-variants.out"
fi
