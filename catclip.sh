#!/usr/bin/env sh
# catclip — concatenate FILE(s) to stdout AND copy to clipboard
# Copyright (c) 2025 Zephyr
# SPDX-License-Identifier: MIT
# See LICENSE or https://opensource.org/licenses/MIT

set -eu

VERSION="1.0.0"

verbose=0
clip_only=0
op="copy"   # modes: copy | paste

# ------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      echo "Usage: catclip [OPTION]... [FILE]..."
      echo "Concatenate FILE(s) to standard output and copy the same bytes to clipboard."
      echo
      echo "With no FILE, or when FILE is -, read standard input."
      echo
      echo "  -c, --clip-only  copy to clipboard only; do not write to stdout"
      echo "  -p, --paste      print current clipboard contents to stdout (text mode)"
      echo "  -q, --quiet      suppress status messages (overrides -v)"
      echo "  -v, --verbose    print copy status to standard error after completion"
      echo "      --help       display this help and exit"
      echo "      --version    output version information and exit"
      exit 0
      ;;
    --version)
      echo "catclip (trashpwnda utils) ${VERSION}"
      echo "License: MIT <https://opensource.org/licenses/MIT>"
      echo "NO WARRANTY, to the extent permitted by law."
      echo
      echo "Written by Zephyr (@trashpwnda)."
      exit 0
      ;;
    -c|--clip-only)
      clip_only=1; shift; continue
      ;;
    -p|--paste)
      op="paste"; shift; continue
      ;;
    -v|--verbose)
      verbose=1; shift; continue
      ;;
    -q|--quiet)
      verbose=0; shift; continue
      ;;
    --)
      shift; break
      ;;
    -*)
      opt="${1#-}"
      printf "%s\n" "catclip: invalid option -- '${opt}'" >&2
      printf "%s\n" "Try 'catclip --help' for more information." >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# When copying, default to stdin if no files were provided
if [ "$op" = "copy" ] && [ $# -eq 0 ]; then
  set -- -
fi

# ------------------------------------------------------------
# Detect clipboard tools (copy + paste)
# ------------------------------------------------------------
clip_cmd= ; clip_args=
paste_cmd= ; paste_args=

if command -v pbcopy >/dev/null 2>&1; then
  # macOS
  clip_cmd=pbcopy
  if command -v pbpaste >/dev/null 2>&1; then
    paste_cmd=pbpaste
  fi
elif command -v wl-copy >/dev/null 2>&1; then
  # Wayland
  clip_cmd=wl-copy
  clip_args="--foreground"
  if command -v wl-paste >/dev/null 2>&1; then
    paste_cmd=wl-paste
    paste_args="-n"
  fi
elif command -v termux-clipboard-set >/dev/null 2>&1; then
  # Android / Termux
  clip_cmd=termux-clipboard-set
  if command -v termux-clipboard-get >/dev/null 2>&1; then
    paste_cmd=termux-clipboard-get
  fi
elif command -v xclip >/dev/null 2>&1; then
  # X11
  clip_cmd=xclip
  clip_args="-selection clipboard -in -quiet -loops 1"
  paste_cmd=xclip
  paste_args="-selection clipboard -o"
elif command -v clip.exe >/dev/null 2>&1; then
  # WSL: copy supported via clip.exe; paste intentionally NOT provided (UNIX-only script)
  clip_cmd=clip.exe
else
  printf "%s\n" "catclip: no clipboard utility found (pbcopy/wl-copy/termux-clipboard-set/xclip/clip.exe)" >&2
  exit 1
fi

# Paste mode executes and exits early
if [ "$op" = "paste" ]; then
  if [ -z "${paste_cmd:-}" ]; then
    printf "%s\n" "catclip: paste not supported on this platform" >&2
    exit 1
  fi
  # shellcheck disable=SC2086
  exec $paste_cmd ${paste_args:-}
fi

# ------------------------------------------------------------
# Secure temporary FIFO setup
# ------------------------------------------------------------
umask 077

# Prefer mktemp; fallback is strictly POSIX
if command -v mktemp >/dev/null 2>&1; then
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/catclip.XXXXXX") || {
    printf "%s\n" "catclip: failed to create temp dir" >&2
    exit 1
  }
else
  tmpdir="${TMPDIR:-/tmp}/catclip.$$"
  if [ -e "$tmpdir" ] || ! mkdir -m 700 "$tmpdir" 2>/dev/null; then
    printf "%s\n" "catclip: failed to create temp dir" >&2
    exit 1
  fi
fi

fifo="$tmpdir/fifo"
status_file="$tmpdir/cat.status"

if ! mkfifo "$fifo"; then
  printf "%s\n" "catclip: failed to create fifo" >&2
  rmdir "$tmpdir" 2>/dev/null || true
  exit 1
fi

cleanup() {
  rm -f "$fifo" "$status_file"
  rmdir "$tmpdir" 2>/dev/null || true
  trap - EXIT HUP INT TERM
}
trap cleanup EXIT HUP INT TERM

# ------------------------------------------------------------
# Start clipboard process in background (single reader)
# ------------------------------------------------------------
# shellcheck disable=SC2086
$clip_cmd ${clip_args:-} < "$fifo" >/dev/null 2>&1 &

# ------------------------------------------------------------
# Fan-out to stdout + clipboard (or clipboard-only)
# ------------------------------------------------------------
rc=0

if [ "$clip_only" -eq 1 ]; then
  # Clipboard only: single read; no stdout
  if cat "$@" > "$fifo"; then
    rc=0
  else
    rc=$?
  fi
else
  # Copy + stdout with pipefail emulation
  {
    cat "$@"
    printf "%d\n" $? > "$status_file"
  } | tee "$fifo"
  rc_tee=$?
  rc_cat=$(cat "$status_file" 2>/dev/null || printf "%s" 1)
  if [ "$rc_cat" -ne 0 ]; then
    rc="$rc_cat"
  else
    rc="$rc_tee"
  fi
fi

# ------------------------------------------------------------
# Status + exit
# ------------------------------------------------------------
if [ "$verbose" -eq 1 ] && [ "$rc" -eq 0 ]; then
  printf "%s\n" "catclip: copied to clipboard" >&2
fi

exit "$rc"
