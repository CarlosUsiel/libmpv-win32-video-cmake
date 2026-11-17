#!/bin/bash
# PT fork: the upstream build tracks branch heads for most dependencies. To rebuild the
# 20260811 release with the same sources, every git checkout under <src_dir> is reset to the
# last commit of its branch made before <date> (the time the upstream run started).
# Usage: pin_sources.sh <src_dir> <iso-date> [dir-to-skip ...]
set -u
src_dir="$1"; date="$2"; shift 2
skip=" $* "
for d in "$src_dir"/*/; do
    d="${d%/}"; name="$(basename "$d")"
    [[ -d "$d/.git" ]] || continue
    if [[ "$skip" == *" $name "* ]]; then
        echo "PIN skip   $name $(git -C "$d" rev-parse --short=12 HEAD)"
        continue
    fi
    sha="$(git -C "$d" rev-list -1 --first-parent --before="$date" HEAD 2>/dev/null)"
    if [[ -z "$sha" ]]; then
        echo "PIN keep   $name $(git -C "$d" rev-parse --short=12 HEAD) (no commit before $date)"
        continue
    fi
    head="$(git -C "$d" rev-parse HEAD)"
    if [[ "$sha" == "$head" ]]; then
        echo "PIN same   $name ${sha:0:12}"
    else
        git -C "$d" am --abort >/dev/null 2>&1 || true
        git -C "$d" reset --hard -q "$sha" || { echo "PIN FAILED $name"; exit 1; }
        echo "PIN moved  $name ${head:0:12} -> ${sha:0:12} ($(git -C "$d" log -1 --format=%cI "$sha"))"
    fi
    if [[ -f "$d/.gitmodules" ]]; then
        git -C "$d" submodule update --init --recursive -q || echo "PIN warn   $name submodule update failed"
    fi
done
