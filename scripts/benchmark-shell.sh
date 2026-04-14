#!/usr/bin/env bash

set -euo pipefail

iterations="${1:-5}"

if ! [[ "${iterations}" =~ ^[0-9]+$ ]] || [[ "${iterations}" -lt 1 ]]; then
	printf 'usage: %s [iterations]\n' "${0##*/}" >&2
	exit 1
fi

for _ in $(seq 1 "${iterations}"); do
	TIMEFORMAT='%3R'
	{ time zsh -i -c exit >/dev/null; } 2>&1
done | awk '
  { sum += $1; if (NR == 1 || $1 < min) min = $1; if ($1 > max) max = $1 }
  END {
    if (NR == 0) exit 1
    printf("runs=%d avg=%.3fs min=%.3fs max=%.3fs\n", NR, sum / NR, min, max)
  }
'
