#!/bin/bash


if [ -z $IDF_PATH ]; then
    export IDF_PATH="$PWD/esp-idf"
fi

if [ -z $IDF_BRANCH ]; then
    IDF_BRANCH="release/v5.5"
fi

if [ -z $AR_PR_TARGET_BRANCH ]; then
    AR_PR_TARGET_BRANCH="master"
fi

if [ -z $IDF_TARGET ]; then
    if [ -f sdkconfig ]; then
        IDF_TARGET=`cat sdkconfig | grep CONFIG_IDF_TARGET= | cut -d'"' -f2`
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
if [ -n $GITHUB_TOKEN ]; then
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
    export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
    export IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)
fi

function get_os(){
    OSBITS=`uname -m`
    if [[ "$OSTYPE" == "linux"* ]]; then
        if [[ "$OSBITS" == "i686" ]]; then
            echo "linux32"
        elif [[ "$OSBITS" == "x86_64" ]]; then
            echo "linux64"
        elif [[ "$OSBITS" == "armv7l" ]]; then
            echo "linux-armel"
        else
            echo "unknown"
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "win32"
    else
        echo "$OSTYPE"
        return 1
    fi
    return 0
}

AR_OS=`get_os`

export SED="sed"
export SSTAT="stat -c %s"

if [[ "$AR_OS" == "macos" ]]; then
    if ! [ -x "$(command -v gsed)" ]; then
        echo "ERROR: gsed is not installed! Please install gsed first. ex. brew install gsed"
        exit 1
    fi
    if ! [ -x "$(command -v gawk)" ]; then
        echo "ERROR: gawk is not installed! Please install gawk first. ex. brew install gawk"
        exit 1
    fi
    export SED="gsed"
    export SSTAT="stat -f %z"
fi

function github_get_libs_idf(){ # github_get_libs_idf <repo-path> <branch-name> <message-prefix>
    local repo_path="$1"
    local branch_name="$2"
    local message_prefix="$3"
    message_prefix=$(echo $message_prefix | sed 's/[]\/$*.^|[]/\\&/g') # Escape special characters
    local page=1
    local version_found=""
    local libs_version=""

    while [[ "$libs_version" == "" && "$page" -le 5 ]]; do
        # Get the latest commit message that matches the prefix and extract the hash from the last commit message
        version_found=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/commits?sha=$branch_name&per_page=100&page=$page" | \
            jq -r --arg prefix "$message_prefix" '[ .[] | select(.commit.message | test($prefix + " [a-f0-9]{8}")) ][0] | .commit.message' | \
            grep -Eo "$message_prefix [a-f0-9]{8}" | \
            awk 'END {print $NF}'`
        if [[ "$version_found" != "" && "$version_found" != "null" ]]; then
            libs_version=$version_found
        else
            page=$((page+1))
        fi
    done

    if [ ! "$libs_version" == "" ] && [ ! "$libs_version" == "null" ]; then echo $libs_version; else echo ""; fi
}

function github_commit_exists(){ #github_commit_exists <repo-path> <branch-name> <commit-message>
    local repo_path="$1"
    local branch_name="$2"
    local commit_message="$3"
    local page=1
    local commits_found=0

    while [ "$page" -le 5 ]; do
        local response=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/commits?sha=$branch_name&per_page=100&page=$page"`

        if [[ -z "$response" || "$response" == "[]" ]]; then
            break
        fi

        local commits=`echo "$response" | jq -r '.[].commit.message' | grep "$commit_message" | wc -l`
        if [ "$commits" -gt 0 ]; then
            commits_found=1
            break
        fi

        page=$((page+1))
    done

    echo $commits_found
}

function github_last_commit(){ # github_last_commit <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local commit=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/commits/heads/$branch_name" | jq -r '.sha'`
    if [ ! "$commit" == "" ] && [ ! "$commit" == "null" ]; then
        echo ${commit:0:8}
    else
        echo ""
    fi
}

function github_branch_exists(){ # github_branch_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local branch=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/branches/$branch_name" | jq -r '.name'`
    if [ "$branch" == "$branch_name" ]; then echo 1; else echo 0; fi
}

function github_pr_exists(){ # github_pr_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local pr_num=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/pulls?head=$AR_USER:$branch_name&state=open" | jq -r '.[].number'`
    if [ ! "$pr_num" == "" ] && [ ! "$pr_num" == "null" ]; then echo 1; else echo 0; fi
}

function github_release_id(){ # github_release_id <repo-path> <release-tag>
    local repo_path="$1"
    local release_tag="$2"
    local page=1
    local release_id=""

    while [[ "$page" -le 3 ]]; do
        local response=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/releases?per_page=100&page=$page"`

        if [[ -z "$response" || "$response" == "[]" ]]; then
            break
        fi

        local release=`echo "$response" | jq --arg release_tag "$release_tag" -r '.[] | select(.tag_name == $release_tag) | .id'`
        if [ ! "$release" == "" ] && [ ! "$release" == "null" ]; then
            release_id=$release
            break
        fi

        page=$((page+1))
    done

    echo "$release_id"
}

function github_release_asset_id(){ # github_release_asset_id <repo-path> <release-id> <release-file>
    local repo_path="$1"
    local release_id="$2"
    local release_file="$3"
    local page=1
    local asset_id=""

    while [[ "$page" -le 5 ]]; do
        local response=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/releases/$release_id/assets?per_page=100&page=$page"`

        if [[ -z "$response" || "$response" == "[]" ]]; then
            break
        fi

        local release_asset=`echo "$response" | jq --arg release_file "$release_file" -r '.[] | select(.name == $release_file) | .id'`
        if [ ! "$release_asset" == "" ] && [ ! "$release_asset" == "null" ]; then
            asset_id=$release_asset
            break
        fi

        page=$((page+1))
    done

    echo "$asset_id"
}

function github_release_asset_upload(){ # github_release_asset_upload <repo-path> <release-id> <release-file-name> <release-file-path>
    local repo_path="$1"
    local release_id="$2"
    local release_file_name="$3"
    local release_file_path="$4"
    local file_extension="${release_file_name##*.}"
    local release_asset=`curl -s -k -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" -H "Content-Type: application/$file_extension" --data-binary "@$release_file_path" "https://uploads.github.com/repos/$repo_path/releases/$release_id/assets?name=$release_file_name" | jq -r '.id'`
    if [ ! "$release_asset" == "" ] && [ ! "$release_asset" == "null" ]; then echo "$release_asset"; else echo ""; fi
}

function github_release_asset_delete(){ # github_release_asset_delete <repo-path> <release-asset-id>
    local repo_path="$1"
    local release_asset_id="$2"
    local res
    local return_code
    res=$(curl -s -k -o /dev/null -w "%{http_code}" -X DELETE -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/releases/assets/$release_asset_id")
    return_code=$?
    if [ "$res" -eq 204 ] && [ "$return_code" -eq 0 ] ; then echo 1; else echo 0; fi
}


function git_branch_exists(){ # git_branch_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local branch_found=`git -C "$repo_path" ls-remote --heads origin "$branch_name"`
    if [ -n "$branch_found" ]; then echo 1; else echo 0; fi
}

function git_commit_exists(){ #git_commit_exists <repo-path> <commit-message>
    local repo_path="$1"
    local commit_message="$2"
    local commits_found=`git -C "$repo_path" log --all --grep="$commit_message" | grep commit`
    if [ -n "$commits_found" ]; then echo 1; else echo 0; fi
}

function git_create_pr(){ # git_create_pr <branch> <title>
    local pr_branch="$1"
    local pr_title="$2"
    local pr_target="$3"
    local pr_body="\`\`\`\r\n"
    while read -r line; do pr_body+=$line"\r\n"; done < "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    pr_body+="\`\`\`\r\n"
    local pr_data="{\"title\": \"$pr_title\", \"body\": \"$pr_body\", \"head\": \"$AR_USER:$pr_branch\", \"base\": \"$pr_target\"}"
    git_create_pr_res=`echo "$pr_data" | curl -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" --data @- "https://api.github.com/repos/$AR_REPO/pulls"`
    local done_pr=`echo "$git_create_pr_res" | jq -r '.title'`
    if [ ! "$done_pr" == "" ] && [ ! "$done_pr" == "null" ]; then echo 1; else echo 0; fi
}

