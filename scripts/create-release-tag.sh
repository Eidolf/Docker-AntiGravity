set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: create-release-tag.sh <tag> <release-sha>" >&2
    exit 2
fi

tag="$1"
release_sha="$2"
if ! release_commit="$(git rev-parse --verify "${release_sha}^{commit}" 2>/dev/null)"; then
    echo "Release commit does not exist: ${release_sha}" >&2
    exit 1
fi

if git show-ref --verify --quiet "refs/tags/${tag}"; then
    existing_commit="$(git rev-parse --verify "${tag}^{commit}")"
    if [[ "$existing_commit" != "$release_commit" ]]; then
        echo "Tag ${tag} already points to ${existing_commit}, not ${release_commit}." >&2
        exit 1
    fi
else
    git tag "$tag" "$release_commit"
fi

git push origin "$tag"
