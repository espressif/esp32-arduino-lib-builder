#!/bin/bash
# shellcheck disable=SC2034

DEBUG() { echo -e "DEBUG: $*\n" >&2; }

if [ -z "$IDF_PATH" ]; then
    export IDF_PATH="$PWD/esp-idf"
fi

if [ -z "$IDF_BRANCH" ]; then
    IDF_BRANCH="release/v6.1"
fi

if [ -z "$AR_PR_TARGET_BRANCH" ]; then
    AR_PR_TARGET_BRANCH="release/v4.0.x"
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

if [ -z "$CHIP_VARIANT" ]; then
    CHIP_VARIANT="$IDF_TARGET"
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
AR_SDK="$AR_TOOLS/esp32-arduino-libs/$CHIP_VARIANT"
PIOARDUINO_SDK="FRAMEWORK_SDK_DIR, \"$CHIP_VARIANT\""
TOOLS_JSON_OUT="$AR_TOOLS/esp32-arduino-libs"

if [ -d "$IDF_PATH" ]; then
    IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
    IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)
    export IDF_COMMIT
    export IDF_BRANCH
fi

# ===========================================================================
# Selectable BT stack helpers (shared by copy-libs.sh, copy-mem-variant.sh and
# copy-bt-variant.sh). See tools/copy-bt-variant.sh for the full design notes.
# ===========================================================================

# List "<component>\t<archive>" for every component whose library depends
# (transitively) on IDF's "bt" component -- i.e. every library whose compiled code
# can change with the selected BT host, which is exactly the set that must be swapped
# between BT stacks. Read straight from the build's own dependency graph, so there is
# no maintained allow/deny list and new BT-dependent components are picked up
# automatically. 'bt' itself is included; the core/sketch libs (main, arduino) are
# excluded because they are compiled from source in the user's build, not shipped.
#   $1 = project_description.json path (default: build/project_description.json)
bt_swappable_libs() {
    local pd="${1:-build/project_description.json}"
    [ -f "$pd" ] || return 0
    jq -r '
        .build_component_info as $ci
        | ($ci | to_entries
           | map({k:.key, deps:((.value.reqs//[])+(.value.priv_reqs//[])+(.value.managed_reqs//[]))})) as $e
        | def grow($s):
            ($e | map(select(.deps | any(. as $d | $s | index($d))) | .k)) as $n
            | ($s + $n | unique) as $s2
            | if ($s2|length) == ($s|length) then $s2 else grow($s2) end;
          grow(["bt"]) | sort[] as $c
          | select($c != "main" and $c != "arduino")
          | ($ci[$c].file // "") as $f
          | select($f != "") | "\($c)\t\($f)"
    ' "$pd"
}

# Deterministic signature of a static library archive, used to tell whether a BT
# archive's linker-relevant content changed between two builds (e.g. because a
# flash-mode/PSRAM option leaked into its compilation).
#
# WHY NOT A BYTE HASH: it would require byte-for-byte reproducible builds, which we do
# NOT have -- ar member timestamps and other packaging metadata differ even between two
# builds of identical source, so a raw byte hash false-positives constantly.
#
# WHAT WE HASH INSTEAD (all derived from the compiled objects, so identical source +
# flags always produce the same result, while any real code change is detected):
#   1. the sorted symbol table -- name, type and size (nm -P): catches symbols added,
#      removed, renamed or resized;
#   2. the disassembly WITH relocations (objdump -dr): catches instruction and
#      immediate-operand changes even when the code size is unchanged (e.g. a config
#      value compiled into an instruction) and changed call/relocation targets (e.g.
#      routing an allocation to PSRAM). Volatile header/path lines are stripped so the
#      only inputs are the deterministic instruction stream and relocation symbols.
# It is also independent of the debug level: the archive is --strip-debug'd (on a copy)
# before fingerprinting, so -g / -g3 / -ggdb / no-debug all produce the same signature.
# This is false-positive free without byte reproducibility and closes the false-
# negative gap a symbol-only signature has. The only theoretical miss is a constant
# that lives purely in a data section (never as an instruction operand) and changes
# value without changing size -- not a pattern that occurs in the BT archives.
#
# TOOLING: the archive is inspected with the IDF toolchain (${TOOLCHAIN}-strip/nm/
# objdump) -- the exact same GNU binutils the build and Arduino use -- so the output is
# identical on macOS and Linux build hosts. Only host-side text munging uses $SED (GNU
# sed, enforced for macOS in the block below) and sha256sum/shasum. Requires $TOOLCHAIN.
bt_lib_sig() {
    local f="$1" t rmt=1
    # Fingerprint a debug-stripped COPY so the result is independent of the debug level
    # (--strip-debug removes all .debug_* sections and debug symbols, so -g / -g3 / -ggdb
    # / no-debug all normalize to the same thing). We never modify the real archive; if a
    # temp cannot be made we fall back to the original (debug level is fixed per build
    # anyway, so this only loses cross-debug-level normalization).
    t=$(mktemp "${TMPDIR:-/tmp}/btsig.XXXXXX" 2>/dev/null)
    if [ -n "$t" ]; then
        cp "$f" "$t" 2>/dev/null
        "${TOOLCHAIN}-strip" --strip-debug "$t" 2>/dev/null
    else
        t="$f"; rmt=0
    fi
    {
        # name, type and size of every symbol (nm -P, ELF: "name type value size").
        # The size column (st_size) catches .bss/.data buffer resizes; the value column
        # is intentionally omitted so it stays a pure content signature.
        "${TOOLCHAIN}-nm" -P "$t" 2>/dev/null | awk 'NF>=2{print $1, $2, $4}' | LC_ALL=C sort
        # instruction stream + relocations. Dropped: the volatile "file format"/"In
        # archive" path headers, blank separators, and compiler-local label headers
        # (e.g. "00000006 <.LM4>:" line markers objdump still annotates from residual
        # -g symbols). What remains is the deterministic instruction lines and their
        # relocation operands; real symbol names are already covered by the nm pass.
        "${TOOLCHAIN}-objdump" -dr "$t" 2>/dev/null \
            | $SED -e '/file format/d' -e '/^In archive/d' -e '/^[0-9a-fA-F]* <\.L/d' -e '/^$/d'
    } | if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1
    [ "$rmt" = 1 ] && rm -f "$t"
}

# Emit "<libname> <sig>" for every swappable BT archive in the CURRENT build tree.
# Used to record a reference on the primary pass and to re-check it on each memory
# variant pass. Requires $TOOLCHAIN.
#   $1 = project_description.json path (default: build/project_description.json)
bt_swappable_sigs() {
    local pd="${1:-build/project_description.json}" comp file name
    bt_swappable_libs "$pd" | while IFS=$'\t' read -r comp file; do
        [ -f "$file" ] || continue
        name=$(basename "$file"); name="${name#lib}"; name="${name%.a}"
        echo "$name $(bt_lib_sig "$file")"
    done
}

# Memory-agnostic guard. A swappable BT archive is shipped ONCE (from the primary
# pass) and shared across every memory config, mirroring how copy-libs.sh ships the
# default BT archives once into lib/. That is only valid if the archive is
# flash-mode/PSRAM independent. This compares the current memory config's build of
# every swappable archive against the reference written by the primary pass and fails
# if any signature differs (became memory-dependent) or the swappable set changed.
#   $1 = reference sig file (from the primary pass)  $2 = stack label  $3 = memconf
# A missing reference means the target has no BT variants -> nothing to check.
bt_check_mem_agnostic() {
    local ref="$1" label="$2" memconf="$3"
    [ -f "$ref" ] || return 0
    local tmp bad
    tmp=$(mktemp "${TMPDIR:-/tmp}/btmem.XXXXXX")
    bt_swappable_sigs > "$tmp"
    bad=$(diff <(LC_ALL=C sort "$ref") <(LC_ALL=C sort "$tmp") | grep -E '^[<>]')
    rm -f "$tmp"
    if [ -n "$bad" ]; then
        echo "ERROR: BT '$label' swappable archive(s) changed for memory config $memconf vs the primary build:"
        echo "$bad" | $SED 's/^< /  primary only : /; s/^> /  this memconf : /'
        echo "       A swapped BT archive is shipped ONCE and shared across all memory configs, so it"
        echo "       MUST be flash-mode/PSRAM independent -- this one is not, which breaks that assumption."
        echo "       Ship it per-memconf via mem_variants_files in configs/builds.json before continuing."
        return 1
    fi
    return 0
}

# True (return 0) if the base build already provides an archive named lib<name>.a on the
# linker's -L search path, so copy-bt-variant.sh must NOT re-ship it as a "flavor-only"
# blob. Two cases are covered:
#   * $sdk/lib/lib<name>.a        -- a shared archive (flags/ld_libs, -L .../lib).
#   * $sdk/<memconf>/lib<name>.a  -- a memory-variant archive shipped per memconf by
#     copy-libs.sh (mem_variants_files, e.g. libspi_flash.a). These are flash-mode/PSRAM
#     dependent, so duplicating one into lib/<flavor>/ (shipped once, shared across every
#     memconf) would BOTH break memory-agnosticism AND shadow the correct per-memconf copy
#     via build.bt_lib_search. Such libs do not depend on the BT host, so the base's
#     per-memconf archive already serves every stack -- the flavor must reuse it.
#   $1 = stripped lib name (e.g. "spi_flash")  $2 = AR_SDK  $3 = MEMCONF
bt_base_provides_lib() {
    local name="$1" sdk="$2" memconf="$3"
    [ -f "$sdk/lib/lib$name.a" ] && return 0
    [ -n "$memconf" ] && [ -f "$sdk/$memconf/lib$name.a" ] && return 0
    return 1
}

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
export REALPATH="realpath"

if [[ "$AR_OS" == "macos" ]]; then
    if ! command -v gsed >/dev/null; then
        echo "ERROR: gsed not installed" >&2
        exit 1
    fi
    if ! command -v gawk >/dev/null; then
        echo "ERROR: gawk not installed" >&2
        exit 1
    fi
    if ! command -v grealpath >/dev/null; then
        echo "ERROR: grealpath not installed (try: brew install coreutils)" >&2
        exit 1
    fi
    export SED="gsed"
    export SSTAT="stat -f %z"
    export REALPATH="grealpath"
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

set_ar_source_branch() {
    DEBUG "set_ar_source_branch($1, $2, $3)"
    local branch_exists_fn="$1"
    local repo="$2"
    local idf_ref="$3"

    if [ -n "$AR_SOURCE_BRANCH" ]; then
        export AR_SOURCE_BRANCH
        return
    fi

    local current_branch
    if [ -z "$GITHUB_HEAD_REF" ]; then
        current_branch=$(git branch --show-current)
    else
        current_branch="$GITHUB_HEAD_REF"
    fi

    local candidate="idf-$idf_ref"
    if [[ "$current_branch" != "master" && $($branch_exists_fn "$repo" "$current_branch") == "1" ]]; then
        AR_SOURCE_BRANCH="$current_branch"
    elif [ "$($branch_exists_fn "$repo" "$candidate")" == "1" ]; then
        AR_SOURCE_BRANCH="$candidate"
    elif [ "$($branch_exists_fn "$repo" "$AR_PR_TARGET_BRANCH")" == "1" ]; then
        AR_SOURCE_BRANCH="$AR_PR_TARGET_BRANCH"
    else
        AR_SOURCE_BRANCH="master"
    fi
    export AR_SOURCE_BRANCH
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
