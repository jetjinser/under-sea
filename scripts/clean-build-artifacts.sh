#!/usr/bin/env bash
# 删除 Guix `--keep-failed` 遗留在 /tmp 的构建树（/tmp/guix-build-*.drv-*）。
#
# 这些目录是构建失败时保留下来的中间树，反复尝试会累积占用大量磁盘。本脚本只
# 删除「当前用户所有」且「超过 N 分钟没有任何写入」的目录，以免误删正在进行的
# 构建；npm/Go 解包出的只读子目录会先 `chmod -R u+w` 再删除。
#
# 用法：
#   scripts/clean-build-artifacts.sh [--min-age MIN] [--dry-run] [--force]
#     --min-age MIN  仅删除至少 MIN 分钟未写入的目录（默认 120）
#     --dry-run       只列出将删除的目录
#     --force         忽略时间保护，删除所有本用户所有的构建树
set -euo pipefail

min_age=120
dry_run=0
force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min-age) min_age="${2:?missing MIN}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "未知选项: $1" >&2; exit 2 ;;
  esac
done

me=$(id -un)
shopt -s nullglob
found=0
for d in /tmp/guix-build-*; do
  [ -d "$d" ] || continue
  found=1
  if [ "$(stat -c %U "$d" 2>/dev/null)" != "$me" ]; then
    echo "跳过（非 $me 所有）: $d"
    continue
  fi
  if [ "$force" -eq 0 ] \
     && [ -n "$(find "$d" -mmin -"$min_age" -print -quit 2>/dev/null)" ]; then
    echo "跳过（${min_age} 分钟内有写入）: $d"
    continue
  fi
  size=$(du -sh "$d" 2>/dev/null | cut -f1)
  if [ "$dry_run" -eq 1 ]; then
    echo "将删除 ($size): $d"
  else
    chmod -R u+w "$d" 2>/dev/null || true
    rm -rf "$d"
    echo "已删除 ($size): $d"
  fi
done
[ "$found" -eq 1 ] || echo "没有 /tmp/guix-build-* 构建树"
