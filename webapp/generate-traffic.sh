#!/usr/bin/env bash
set -euo pipefail

target="${1:-http://localhost}"
iterations="${2:-20}"
account="${3:-mary}"
img_dir="${4:-../benchmarker/userdata/img}"
password="${account}${account}"

cookie_jar="$(mktemp "${TMPDIR:-/tmp}/generate-traffic-cookies.XXXXXXXXXX")"
trap 'rm -f "$cookie_jar"' EXIT

curl -sS -o /dev/null -c "$cookie_jar" -b "$cookie_jar" \
  --data-urlencode "account_name=${account}" \
  --data-urlencode "password=${password}" \
  "${target}/login"

for i in $(seq 1 "$iterations"); do
  html="$(curl -sS -c "$cookie_jar" -b "$cookie_jar" "${target}/")"
  csrf_token="$(printf '%s' "$html" | grep -o 'name="csrf_token" value="[^"]*"' | head -n1 | sed 's/.*value="\([^"]*\)"/\1/')"
  post_id="$(printf '%s' "$html" | grep -o '/posts/[0-9]\+' | head -n1 | grep -o '[0-9]\+')"

  if [ -n "$post_id" ]; then
    curl -sS -o /dev/null -c "$cookie_jar" -b "$cookie_jar" "${target}/posts/${post_id}"
    curl -sS -o /dev/null -c "$cookie_jar" -b "$cookie_jar" \
      --data-urlencode "csrf_token=${csrf_token}" \
      --data-urlencode "post_id=${post_id}" \
      --data-urlencode "comment=nice ramen #${i}" \
      "${target}/comment"
  fi

  curl -sS -o /dev/null -c "$cookie_jar" -b "$cookie_jar" "${target}/@${account}"

  if [ $((i % 5)) -eq 0 ] && [ -d "$img_dir" ]; then
    image_count="$(find "$img_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')"
    image=""
    if [ "$image_count" -gt 0 ]; then
      pick=$(( (RANDOM % image_count) + 1 ))
      image="$(find "$img_dir" -maxdepth 1 -type f | sed -n "${pick}p")"
    fi
    if [ -n "$image" ]; then
      curl -sS -o /dev/null -c "$cookie_jar" -b "$cookie_jar" \
        -F "csrf_token=${csrf_token}" \
        -F "body=posting from generate-traffic.sh #${i}" \
        -F "file=@${image}" \
        "${target}/"
    fi
  fi

  echo "iteration ${i}/${iterations} done"
done
