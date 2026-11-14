#!/usr/bin/env bash
# playground で自動生成されたファイルのうち、指定した network/snapshot に関連するものを
# このリポジトリへコピーする。
#
# Usage:
#   ./copy_from_playground.sh [-n] [-p PLAYGROUND_DIR] NETWORK SNAPSHOT
#
#   -p DIR  playground のディレクトリ (default: $PLAYGROUND_DIR or ~/playground)
#   -n      dry-run (コピーせず、対象を表示するのみ)
#
# Example:
#   ./copy_from_playground.sh -p ~/ool-mddo/playground mddo-fw original_asis
#
# コピー対象 (<N>=network, <S>=snapshot):
#   queries/<N>/<S>/
#   topologies/<N>/<S>/  および  topologies/<N>/<S>_conduit*/
#   policies/firewall-policy-parser/{configs,outputs}/<N>/<S>/
#   policies/bgp-policy-parser/{configs,outputs,bgp_policies}/<N>/<S>/
#   usecases/refocus_topology/<N>/<S>_blueprint*/  と  usecases/refocus_topology/<N>/params.yaml
#
# コピー(対象)したファイルは1件ずつ表示する。git 操作は行わない。
# 注意: 追加・上書きのみを行い、このリポジトリ側の余剰ファイルは削除しない。
#       playground 側に存在しない対象はスキップする (警告を表示)。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYGROUND_DIR="${PLAYGROUND_DIR:-$HOME/playground}"
DRY_RUN=0

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

while getopts "p:nh" opt; do
  case "$opt" in
    p) PLAYGROUND_DIR="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

[ $# -eq 2 ] || usage 1
NETWORK="$1"
SNAPSHOT="$2"

# パス区切りや相対指定による意図しない場所へのコピーを防ぐ
for v in "$NETWORK" "$SNAPSHOT"; do
  case "$v" in
    "" | . | .. | */* ) echo "invalid network/snapshot name: '$v'" >&2; exit 1 ;;
  esac
done

PLAYGROUND_DIR="${PLAYGROUND_DIR%/}"
if [ ! -d "$PLAYGROUND_DIR" ]; then
  echo "playground directory not found: $PLAYGROUND_DIR" >&2
  exit 1
fi

copied=0
missing=0

# copy_dir <playground からの相対ディレクトリ> : ディレクトリの中身を同じ相対パスへコピー
copy_dir() {
  local rel="$1" src="$PLAYGROUND_DIR/$1" dst="$REPO_DIR/$1"
  if [ ! -d "$src" ]; then
    echo "[skip] not found: $rel" >&2
    missing=$((missing + 1))
    return
  fi
  local f n=0
  echo "[copy] $rel/"
  while IFS= read -r -d '' f; do
    echo "         ${f#"$PLAYGROUND_DIR"/}"
    n=$((n + 1))
  done < <(find "$src" -type f -print0 | sort -z)
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
  fi
  copied=$((copied + n))
}

# copy_file <playground からの相対ファイル>
copy_file() {
  local rel="$1" src="$PLAYGROUND_DIR/$1" dst="$REPO_DIR/$1"
  if [ ! -f "$src" ]; then
    echo "[skip] not found: $rel" >&2
    missing=$((missing + 1))
    return
  fi
  echo "[copy] $rel"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
  fi
  copied=$((copied + 1))
}

# copy_glob <playground からの相対の親ディレクトリ> <名前の prefix> : prefix* に一致するディレクトリ
copy_glob_dirs() {
  local parent="$1" prefix="$2" d found=0
  [ -d "$PLAYGROUND_DIR/$parent" ] || { echo "[skip] not found: $parent" >&2; missing=$((missing + 1)); return; }
  for d in "$PLAYGROUND_DIR/$parent/$prefix"*/; do
    [ -d "$d" ] || continue
    found=1
    copy_dir "$parent/$(basename "$d")"
  done
  if [ "$found" -eq 0 ]; then
    echo "[skip] not found: $parent/${prefix}*" >&2
    missing=$((missing + 1))
  fi
}

echo "playground: $PLAYGROUND_DIR"
echo "network/snapshot: $NETWORK/$SNAPSHOT$([ "$DRY_RUN" -eq 1 ] && echo " (dry-run)")"

# Batfish クエリ出力
copy_dir "queries/$NETWORK/$SNAPSHOT"

# トポロジ (本体 + 土管化(conduit) トポロジ)
copy_dir "topologies/$NETWORK/$SNAPSHOT"
copy_glob_dirs "topologies/$NETWORK" "${SNAPSHOT}_conduit"

# ポリシーパーサ入出力 (network がそのパーサの対象でなければ skip 警告になる)
for sub in firewall-policy-parser/configs firewall-policy-parser/outputs; do
  copy_dir "policies/$sub/$NETWORK/$SNAPSHOT"
done
for sub in bgp-policy-parser/configs bgp-policy-parser/outputs bgp-policy-parser/bgp_policies; do
  copy_dir "policies/$sub/$NETWORK/$SNAPSHOT"
done

# 土管化ユースケース (blueprint)
copy_glob_dirs "usecases/refocus_topology/$NETWORK" "${SNAPSHOT}_blueprint"
copy_file "usecases/refocus_topology/$NETWORK/params.yaml"

echo "done: $copied file(s) $([ "$DRY_RUN" -eq 1 ] && echo 'would be ')copied, $missing target(s) skipped"
