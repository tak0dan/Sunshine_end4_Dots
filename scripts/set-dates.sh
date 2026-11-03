#!/usr/bin/env bash
# Set the important dates fastfetch counts up from (shown under the system
# info on every new shell, e.g. "Running Linux - 2 years 7 months").
#
# Usage: set-dates.sh
#   Interactive: lists the current dates, then lets you keep them, add to
#   them or start over. Safe to run any time after installation.

set -euo pipefail

dir=${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch
# custom-info.sh reads from_tak_0/custom-info.json first, if it exists
if [[ -f $dir/from_tak_0/custom-info.json ]]; then
    file=$dir/from_tak_0/custom-info.json
else
    file=$dir/custom-info.json
fi

if [[ ! -t 0 ]]; then
    echo "set-dates: not running in a terminal, leaving $file as it is" >&2
    exit 0
fi

bold=$'\e[1m' dim=$'\e[2m' rst=$'\e[0m'

# Entries are kept as JSON lines in a temp file, turned into the final file at the end
work=$(mktemp)
trap 'rm -f "$work"' EXIT

list_entries() {
    python3 - "$1" <<'PY'
import json, sys
try:
    entries = json.load(open(sys.argv[1])).get("entries", [])
except (OSError, ValueError):
    entries = []
for e in entries:
    print(f"  - {e.get('title', '?')}  (since {e.get('since', '?')})")
if not entries:
    print("  (none)")
PY
}

echo "${bold}Important dates${rst}"
echo "fastfetch shows how long ago each of these was, under the system info."
echo
choice=n
if [[ -f $file ]]; then
    echo "Current dates in ${dim}$file${rst}:"
    list_entries "$file"
    echo
    read -rp "Keep them [k], add more [a] or start over [n]? [k] " choice
    choice=${choice:-k}
fi
case $choice in
    k|K) echo "Keeping the current dates."; exit 0 ;;
    a|A) python3 - "$file" > "$work" <<'PY'
import json, sys
for e in json.load(open(sys.argv[1])).get("entries", []):
    print(json.dumps(e))
PY
        ;;
    *) : ;;
esac

echo
echo "Add dates one by one. Leave the title empty when you are done."
while true; do
    echo
    read -rp "Title (e.g. 'Running Linux', 'Together', 'At my job'): " title
    [[ -z $title ]] && break

    while true; do
        read -rp "Date it started (YYYY-MM-DD, or 'today'): " since
        [[ $since == today ]] && since=$(date +%F)
        if python3 -c 'import sys, datetime; datetime.date.fromisoformat(sys.argv[1])' "$since" 2>/dev/null; then
            break
        fi
        echo "  Not a valid date, try again (example: 2024-03-17)."
    done

    echo "How should it be shown?"
    echo "  1) years and months      ${dim}2 years 7 months${rst}"
    echo "  2) months and days       ${dim}31 months 12 days${rst}"
    echo "  3) days                  ${dim}943 days${rst}"
    echo "  4) months, days, minutes ${dim}each as its own total, one per line${rst}"
    read -rp "Choose [1]: " style
    case ${style:-1} in
        2) units='["months", "days"]'; mode=combined ;;
        3) units='["days"]'; mode=combined ;;
        4) units='["months", "days", "minutes"]'; mode=total ;;
        *) units='["years", "months"]'; mode=combined ;;
    esac
    python3 -c 'import json, sys; print(json.dumps({"title": sys.argv[1], "since": sys.argv[2], "units": json.loads(sys.argv[3]), "mode": sys.argv[4]}, ensure_ascii=False))' \
        "$title" "$since" "$units" "$mode" >> "$work"
    echo "  Added: $title (since $since)"
done

mkdir -p "$(dirname "$file")"
python3 - "$work" "$file" <<'PY'
import json, os, sys
src, dst = sys.argv[1:]
entries = [json.loads(line) for line in open(src) if line.strip()]
tmp = dst + ".tmp"
with open(tmp, "w") as f:
    json.dump({"entries": entries}, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, dst)
print(f"\nSaved {len(entries)} date(s) to {dst}")
PY
