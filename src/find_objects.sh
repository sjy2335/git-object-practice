#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./find-objects.sh commit
#   ./find-objects.sh tree
#   ./find-objects.sh blob

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <commit|tree|blob>" >&2
  exit 1
fi

target_type="$1"

case "$target_type" in
  commit|tree|blob)
    ;;
  *)
    echo "Error: type must be one of: commit, tree, blob" >&2
    exit 1
    ;;
esac

# 기준 디렉토리 결정:
# 1. 현재 위치가 Git repo 안이면 repository root 사용
# 2. 아니면 이 스크립트 파일 기준 하나 상위 디렉토리 사용
if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  repo_root="$git_root"
else
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/.." && pwd)"
fi

objects_dir="$repo_root/.git/objects"

if [ ! -d "$objects_dir" ]; then
  echo "Error: .git/objects directory not found: $objects_dir" >&2
  exit 1
fi

cd "$repo_root"

echo "Repository root: $repo_root"
echo "Search result of loose Git objects of type: $target_type"
echo

# .git/objects/ab/cdef... 형태의 loose object만 대상
# pack, info 디렉토리는 제외
find "$objects_dir" -type f |
while IFS= read -r object_file; do
  rel_path="${object_file#$objects_dir/}"

  # loose object는 디렉토리 2글자 + 파일명 38글자 = SHA-1 40글자
  # 예: .git/objects/ab/cdef...
  if [[ ! "$rel_path" =~ ^[0-9a-f]{2}/[0-9a-f]{38}$ ]]; then
    continue
  fi

  object_hash="${rel_path:0:2}${rel_path:3}"

  object_type="$(git cat-file -t "$object_hash" 2>/dev/null || true)"

  if [ "$object_type" = "$target_type" ]; then
    printf "%s\n" "$object_hash"
  fi
done
