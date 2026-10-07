#!/usr/bin/env bash
# One entry point for the test tiers in docs/testing.md, for the app and the
# Worker together. Written for the bash 3.2 macOS ships.
#
#   tool/test.sh smoke              the smoke tier (~30 s): while developing
#   tool/test.sh changed            smoke + the tests this branch touches: before a commit
#   tool/test.sh feature FILE...    smoke + the test files named
#   tool/test.sh full               the full regression (~2.5 min): only when the owner asks
#
# FILE is test/<name>_test.dart or vocab-photo-api/test/<name>.test.mjs.
# The Worker side needs `npm ci` in vocab-photo-api once.
set -u
cd "$(dirname "$0")/.."

usage() {
  sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

app_files=""
api_files=""
add_file() {
  case "$1" in
    test/*_test.dart) app_files="$app_files $1" ;;
    vocab-photo-api/test/*.test.mjs) api_files="$api_files ${1#vocab-photo-api/}" ;;
    *) echo "not a test file: $1" >&2; exit 2 ;;
  esac
}

# The app's smoke files are the ones tagged @Tags(['smoke']). Run by path:
# `flutter test --tags smoke` compiles every file just to read its tags.
smoke_app=$(grep -l "@Tags(\['smoke'\])" test/*_test.dart | tr '\n' ' ')

# Test files this branch adds or changes, plus the app tests that import a
# lib/ file this branch changes. Compared with master, uncommitted work included.
changed_tests() {
  local base
  base=$(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD master)
  { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u |
    while read -r path; do
      [ -e "$path" ] || continue
      case "$path" in
        test/*_test.dart | vocab-photo-api/test/*.test.mjs) echo "$path" ;;
        lib/*.dart) grep -l "package:flutter_vocabulary_app/${path#lib/}'" test/*_test.dart ;;
      esac
    done | sort -u
}

mode=${1:-}
[ $# -gt 0 ] && shift
case "$mode" in
  smoke) ;;
  feature)
    [ $# -gt 0 ] || usage
    for f in "$@"; do add_file "$f"; done ;;
  changed)
    for f in $(changed_tests); do add_file "$f"; done
    echo "# changed tests:${app_files}${api_files:- (none in the Worker)}" ;;
  full) ;;
  *) usage ;;
esac

failed=""
run() {
  local name=$1
  shift
  local started=$SECONDS
  echo "### $name: $*"
  if "$@"; then
    echo "### $name passed in $((SECONDS - started)) s"
  else
    echo "### $name FAILED after $((SECONDS - started)) s"
    failed="$failed $name"
  fi
}

if [ "$mode" = full ]; then
  run app flutter test
  run worker npm --prefix vocab-photo-api run test:full
else
  # Duplicates are dropped, so naming a smoke file again is harmless.
  # shellcheck disable=SC2086
  run app flutter test $(printf '%s\n' $smoke_app $app_files | sort -u)
  # npm test always runs the Worker smoke test, plus any files named.
  # shellcheck disable=SC2086
  run worker npm --prefix vocab-photo-api test -- $api_files
fi

if [ -n "$failed" ]; then
  echo "### FAILED:$failed"
  exit 1
fi
echo "### all passed ($mode)"
