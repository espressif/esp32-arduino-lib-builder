#!/bin/bash
# shellcheck disable=SC2034

DEBUG() { echo -e "DEBUG: $*\n" >&2; }

if [ -z "$IDF_PATH" ]; then
    export IDF_PATH="$PWD/esp-idf"
fi

if [ -z "$IDF_BRANCH" ]; then
    IDF_BRANCH="release/v5.5"
fi

if [ -z "$AR_PR_TARGET_BRANCH" ]; then
    AR_PR_TARGET_BRANCH="master"
fi

if [ -z "$IDF_TARGET" ]; then
    if [ -f sdkconfig ]; then
        IDF_TARGET=$(grep CONFIG_IDF_TARGET= sdkconfig | cut -d'"' -f2)
        if [ "$IDF_TARGET" = "" ]; then
            IDF_TARGET="esp32"
        fi
    else
        IDF_TARGET="esp32"
    fi
fi

# Owner of the target ESP32 Arduino repository
AR_USER="${GITHUB_REPOSITORY_OWNER:-espressif}"

# The full name of the repository
AR_REPO="$AR_USER/arduino-esp32"
IDF_REPO="$AR_USER/esp-idf"
AR_LIBS_REPO="$AR_USER/esp32-arduino-lib-builder"

AR_REPO_URL="https://github.com/$AR_REPO.git"
IDF_REPO_URL="https://github.com/$IDF_REPO.git"
AR_LIBS_REPO_URL="https://github.com/$AR_LIBS_REPO.git"
if [ -n "$GITHUB_TOKEN" ]; then
    AR_REPO_URL="https://$GITHUB_TOKEN@github.com/$AR_REPO.git"
    AR_LIBS_REPO_URL="https://$GITHUB_TOKEN@github.com/$AR_LIBS_REPO.git"
fi

AR_ROOT="$PWD"
AR_COMPS="$AR_ROOT/components"
AR_MANAGED_COMPS="$AR_ROOT/managed_components"
AR_OUT="$AR_ROOT/out"
AR_TOOLS="$AR_OUT/tools"
AR_PATCHES="$AR_ROOT/patches"
AR_PLATFORM_TXT="$AR_OUT/platform.txt"
AR_GEN_PART_PY="$AR_TOOLS/gen_esp32part.py"
AR_SDK="$AR_TOOLS/esp32-arduino-libs/$IDF_TARGET"
PIOARDUINO_SDK="FRAMEWORK_SDK_DIR, \"$IDF_TARGET\""
TOOLS_JSON_OUT="$AR_TOOLS/esp32-arduino-libs"

if [ -d "$IDF_PATH" ]; then
    IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
    IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)
    export IDF_COMMIT
    export IDF_BRANCH
fi

get_os() {
    DEBUG "get_os()"
    OSBITS=$(uname -m)
    DEBUG "OSTYPE=$OSTYPE, OSBITS=$OSBITS"
    if [[ "$OSTYPE" == "linux"* ]]; then
        case "$OSBITS" in
            i686) echo "linux32" ;;
            x86_64) echo "linux64" ;;
            armv7l) echo "linux-armel" ;;
            *) echo "unknown"; return 1 ;;
        esac
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "win32"
    else
        echo "$OSTYPE"
        return 1
    fi
}

AR_OS=$(get_os)
export SED="sed"
export SSTAT="stat -c %s"

if [[ "$AR_OS" == "macos" ]]; then
    if ! command -v gsed >/dev/null; then
        echo "ERROR: gsed not installed" >&2
        exit 1
    fi
    if ! command -v gawk >/dev/null; then
        echo "ERROR: gawk not installed" >&2
        exit 1
    fi
    export SED="gsed"
    export SSTAT="stat -f %z"
fi

github_get_libs_idf() {
    DEBUG "github_get_libs_idf($1, $2, $3)"
    local repo_path="$1"
    local branch_name="$2"
    local message_prefix="$3"
    message_prefix=$(echo "$message_prefix" | sed 's/[]\/$*.^|[]/\\&/g')
    local page=1 libs_version=""
    while [[ -z "$libs_version" && "$page" -le 5 ]]; do
        DEBUG "Fetching commits page $page"
        local response
        response=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3.raw+json" \
            "https://api.github.com/repos/$repo_path/commits?sha=$branch_name&per_page=100&page=$page")
        local version_found
        version_found=$(echo "$response" | jq -r --arg prefix "$message_prefix" \
            '[ .[] | select(.commit.message | test($prefix + " [a-f0-9]{8}")) ][0] | .commit.message' | \
            grep -Eo "$message_prefix [a-f0-9]{8}" | awk 'END {print $NF}')
        if [[ -n "$version_found" ]]; then
            DEBUG "Found version: $version_found"
            libs_version=$version_found
        else
            ((page++))
        fi
    done
    echo "$libs_version"
}

github_commit_exists() {
    DEBUG "github_commit_exists($1, $2, $3)"
    local repo_path="$1" branch_name="$2" commit_message="$3"
    local page=1 commits_found=0
    while [ "$page" -le 5 ]; do
        DEBUG "Checking commits page $page"
        local response
        response=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3.raw+json" \
            "https://api.github.com/repos/$repo_path/commits?sha=$branch_name&per_page=100&page=$page")
        [[ -z "$response" || "$response" == "[]" ]] && break
        if echo "$response" | jq -r '.[].commit.message' | grep -q "$commit_message"; then
            commits_found=1
            break
        fi
        ((page++))
    done
    echo "$commits_found"
}

github_last_commit() {
    DEBUG "github_last_commit($1, $2)"
    local repo_path="$1" branch_name="$2"
    local url="https://api.github.com/repos/$repo_path/commits/heads/$branch_name"
    DEBUG "GET $url"
    local commit
    commit=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" "$url" | jq -r '.sha')
    [[ -n "$commit" && "$commit" != "null" ]] && echo "${commit:0:8}" || echo ""
}

github_branch_exists() {
    DEBUG "github_branch_exists($1, $2)"
    local repo_path="$1" branch_name="$2"
    local url="https://api.github.com/repos/$repo_path/branches/$branch_name"
    local branch
    branch=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" "$url" | jq -r '.name')
    [[ "$branch" == "$branch_name" ]] && echo 1 || echo 0
}

github_pr_exists() {
    DEBUG "github_pr_exists($1, $2)"
    local repo_path="$1" branch_name="$2"
    local url="https://api.github.com/repos/$repo_path/pulls?head=$AR_USER:$branch_name&state=open"
    local pr_num
    pr_num=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" "$url" | jq -r '.[].number')
    [[ -n "$pr_num" && "$pr_num" != "null" ]] && echo 1 || echo 0
}

github_release_id() {
    DEBUG "github_release_id($1, $2)"
    local repo_path="$1" release_tag="$2" page=1 release_id=""
    while [[ "$page" -le 3 ]]; do
        local url="https://api.github.com/repos/$repo_path/releases?per_page=100&page=$page"
        DEBUG "Fetching $url"
        local response
        response=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" "$url")
        [[ -z "$response" || "$response" == "[]" ]] && break
        release_id=$(echo "$response" | jq --arg tag "$release_tag" -r '.[] | select(.tag_name == $tag) | .id')
        if [[ -n "$release_id" && "$release_id" != "null" ]]; then
            DEBUG "Found release_id=$release_id"
            echo "$release_id"
            return 0
        fi
        ((page++))
    done
    echo "Release '$release_tag' not found in $repo_path" >&2
    exit 1
}

github_release_asset_id() {
    DEBUG "github_release_asset_id($1, $2, $3)"
    local repo_path="$1" release_id="$2" release_file="$3" page=1
    while [[ "$page" -le 5 ]]; do
        local url="https://api.github.com/repos/$repo_path/releases/$release_id/assets?per_page=100&page=$page"
        DEBUG "GET $url"
        local response
        response=$(curl -s -k -H "Authorization: token $GITHUB_TOKEN" "$url")
        [[ -z "$response" || "$response" == "[]" ]] && break
        local asset_id
        asset_id=$(echo "$response" | jq --arg f "$release_file" -r '.[] | select(.name == $f) | .id')
        if [[ -n "$asset_id" && "$asset_id" != "null" ]]; then
            DEBUG "Found asset_id=$asset_id"
            echo "$asset_id"
            return 0
        fi
        ((page++))
    done
    echo "No asset found for $release_file" >&2
    exit 1
}

github_release_asset_upload() {
    DEBUG "github_release_asset_upload($1, $2, $3, $4)"
    local repo_path="$1" release_id="$2" release_file_name="$3" release_file_path="$4"
    local file_extension="${release_file_name##*.}"
    local url="https://uploads.github.com/repos/$repo_path/releases/$release_id/assets?name=$release_file_name"
    DEBUG "Uploading $release_file_name to $url"
    local release_asset
    release_asset=$(curl -s -k -X POST -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/$file_extension" --data-binary "@$release_file_path" "$url" | jq -r '.id')
    [[ -n "$release_asset" && "$release_asset" != "null" ]] && echo "$release_asset" || echo ""
}

github_release_asset_delete() {
    DEBUG "github_release_asset_delete($1, $2)"
    local repo_path="$1" release_asset_id="$2"
    local url="https://api.github.com/repos/$repo_path/releases/assets/$release_asset_id"
    DEBUG "DELETE $url"
    local res
    res=$(curl -s -k -o /dev/null -w "%{http_code}" -X DELETE -H "Authorization: token $GITHUB_TOKEN" "$url")
    [[ "$res" -eq 204 ]] && echo 1 || echo 0
}

git_branch_exists() {
    DEBUG "git_branch_exists($1, $2)"
    local repo_path="$1" branch_name="$2"
    git -C "$repo_path" ls-remote --heads origin "$branch_name" | grep -q . && echo 1 || echo 0
}

git_commit_exists() {
    DEBUG "git_commit_exists($1, $2)"
    local repo_path="$1" commit_message="$2"
    git -C "$repo_path" log --all --grep="$commit_message" | grep -q commit && echo 1 || echo 0
}

git_create_pr() {
    DEBUG "git_create_pr($1, $2, $3)"
    local pr_branch="$1" pr_title="$2" pr_target="$3"
    local pr_body="\`\`\`\r\n"
    while IFS= read -r line; do pr_body+="$line\r\n"; done < "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    pr_body+="\`\`\`\r\n"
    local pr_data="{\"title\": \"$pr_title\", \"body\": \"$pr_body\", \"head\": \"$AR_USER:$pr_branch\", \"base\": \"$pr_target\"}"
    local url="https://api.github.com/repos/$AR_REPO/pulls"
    DEBUG "Creating PR via $url"
    local response
    response=$(echo "$pr_data" | curl -s -k -H "Authorization: token $GITHUB_TOKEN" --data @- "$url")
    local result
    result=$(echo "$response" | jq -r '.title')
    [[ -n "$result" && "$result" != "null" ]] && echo 1 || echo 0
}
