#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run-r-benchmark.sh <original|selective> <rounds> <numRoles>

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <original|selective> <rounds> <numRoles>"
  exit 1
fi

mode="$1"
rounds="$2"
n="$3"

if [[ "$mode" != "original" && "$mode" != "selective" ]] ||
   [[ ! "$rounds" =~ ^[1-9][0-9]*$ ]] ||
   [[ ! "$n" =~ ^[0-9]+$ ]] ||
   (( n < 2 || n > 100 )); then
  echo "Invalid arguments"
  exit 1
fi

# Use the previously compiled executable.
exe="$(cabal list-bin exe:r-benchmark)"

# Store each process output separately.
logdir="logs/${mode}-${rounds}-${n}"
mkdir -p "$logdir"

pids=()

# Launch all roles except Alice.
roles=(bob)

for ((i=3; i<=n; i++)); do
  roles+=("rol-$i")
done

for role in "${roles[@]}"; do
  "$exe" "$mode" "$rounds" "$n" "$role" \
    > "$logdir/$role.log" 2>&1 &
  pids+=("$!")
done

# Give the HTTP servers time to start.
sleep 2

# Alice initiates all decisions.
"$exe" "$mode" "$rounds" "$n" alice \
  > "$logdir/alice.log" 2>&1 &
pids+=("$!")

# Wait for all processes.
status=0

for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

echo
echo "=== Message counts ==="
grep -h '\[Network\]' "$logdir"/*.log || true

echo
echo "Logs: $logdir"

exit "$status"
