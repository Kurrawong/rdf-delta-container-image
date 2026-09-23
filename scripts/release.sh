#!/usr/bin/env bash
#
# Pin new upstream commits in the Dockerfile, tag the repo, and publish a
# GitHub release. The Release workflow builds and pushes
# ghcr.io/kurrawong/rdf-delta when the release is published.
#
# Usage:
#   scripts/release.sh --jena <ref> [--delta <ref>] [--version X.Y.Z]
#   scripts/release.sh --delta <ref>
#
# A ref is a full SHA or anything the upstream repo resolves (main, a tag, a
# short SHA); it is resolved to a full SHA before being written.
#
# The version defaults to the highest existing tag with its patch incremented.
# --dry-run edits nothing and prints what would change.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${REPO_ROOT}/Dockerfile"

# Derive the upstream repo slugs from the Dockerfile where it names them, so
# this keeps working across branches that build Jena from a different fork.
slug_from_arg() {
    local arg="$1" fallback="$2" url
    url="$(grep -oP "^ARG ${arg}=\\K\\S+" "$DOCKERFILE" 2>/dev/null || true)"
    if [ -z "$url" ]; then
        echo "$fallback"
        return
    fi
    url="${url%.git}"
    echo "${url#*github.com/}"
}

JENA_REPO="${JENA_REPO:-$(slug_from_arg JENA_REPO apache/jena)}"
DELTA_REPO="${DELTA_REPO:-$(slug_from_arg DELTA_REPO afs/rdf-delta)}"

die() { echo "error: $*" >&2; exit 1; }

JENA_REF=""
DELTA_REF=""
VERSION=""
SUFFIX=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --jena)    JENA_REF="${2:-}";  shift 2 ;;
        --delta)   DELTA_REF="${2:-}"; shift 2 ;;
        --version) VERSION="${2:-}";   shift 2 ;;
        --suffix)  SUFFIX="${2:-}";    shift 2 ;;
        --dry-run) DRY_RUN=1;          shift ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's|^#\s\?||'; exit 0 ;;
        *)         die "unknown argument '$1'" ;;
    esac
done

[ -n "$JENA_REF" ] || [ -n "$DELTA_REF" ] || die "pass at least one of --jena <ref> or --delta <ref>"
[ -z "$VERSION" ] || [ -z "$SUFFIX" ] || die "--suffix applies to the derived version; drop it when passing --version"

command -v gh >/dev/null || die "gh is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run 'gh auth login'"

cd "$REPO_ROOT"
git fetch --quiet --tags origin

# Resolve a ref in an upstream repo to a full commit SHA.
resolve() {
    local repo="$1" ref="$2" sha
    sha="$(gh api "repos/${repo}/commits/${ref}" --jq .sha 2>/dev/null)" ||
        die "could not resolve '${ref}' in ${repo}"
    echo "$sha"
}

# Read the current value of a Dockerfile ARG.
current_arg() {
    grep -oP "^ARG $1=\K\S+" "$DOCKERFILE" || die "ARG $1 not found in Dockerfile"
}

declare -a CHANGES=()

plan() {
    local arg="$1" repo="$2" ref="$3"
    [ -n "$ref" ] || return 0
    local new old
    new="$(resolve "$repo" "$ref")"
    old="$(current_arg "$arg")"
    if [ "$new" = "$old" ]; then
        echo "${arg}: already at ${new}, no change"
        return 0
    fi
    echo "${arg}: ${old} -> ${new} (${repo}@${ref})"
    CHANGES+=("${arg}|${old}|${new}|${repo}")
}

plan JENA_GIT_HASH  "$JENA_REPO"  "$JENA_REF"
plan DELTA_GIT_HASH "$DELTA_REPO" "$DELTA_REF"

[ "${#CHANGES[@]}" -gt 0 ] || die "nothing to update; the Dockerfile already pins those commits"

if [ -z "$VERSION" ]; then
    LATEST="$(git tag --list --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
    [ -n "$LATEST" ] || die "no existing semver tag found; pass --version"
    IFS=. read -r MAJOR MINOR PATCH <<<"$LATEST"
    VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
    # A suffix marks a release built from a variant lineage, e.g. jenafork.
    # docker/metadata-action treats it as a prerelease, so it will not move the
    # floating {{major}} and {{major}}.{{minor}} tags.
    if [ -n "$SUFFIX" ]; then
        VERSION="${VERSION}-${SUFFIX}"
    fi
    echo "latest plain tag is ${LATEST}, releasing ${VERSION}"
fi

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
    die "version must be semver X.Y.Z or X.Y.Z-suffix, got '$VERSION'"
if git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
    die "tag ${VERSION} already exists"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "dry run: would release ${VERSION}"
    exit 0
fi

[ -z "$(git status --porcelain -- "$DOCKERFILE")" ] || die "Dockerfile has uncommitted changes; commit or stash first"
[ "$(git rev-list --count '@{u}..HEAD')" = "0" ] || die "you have unpushed commits; push or reset them first"

BODY=""
for CHANGE in "${CHANGES[@]}"; do
    IFS='|' read -r ARG OLD NEW REPO <<<"$CHANGE"
    sed -i "s|^ARG ${ARG}=.*|ARG ${ARG}=${NEW}|" "$DOCKERFILE"
    BODY+="- ${REPO}: \`${OLD}\` -> [\`${NEW:0:12}\`](https://github.com/${REPO}/commit/${NEW})"$'\n'
done

git add "$DOCKERFILE"
git commit -q -m "build: bump upstream commits for ${VERSION}" -m "$BODY"
git tag -a "$VERSION" -m "$VERSION"
git push -q origin HEAD
git push -q origin "refs/tags/${VERSION}"

gh release create "$VERSION" --title "$VERSION" --notes "$BODY"

echo
echo "Release ${VERSION} published. Watching the build..."
sleep 5
RUN_ID="$(gh run list --workflow Release --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch --exit-status "$RUN_ID" ||
    die "the Release workflow failed; see 'gh run view ${RUN_ID} --log-failed'"

echo
echo "ghcr.io/kurrawong/rdf-delta:${VERSION} is published."
echo "Next: publish downstream if you need to."
