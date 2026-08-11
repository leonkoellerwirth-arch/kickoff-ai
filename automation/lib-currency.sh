#!/usr/bin/env bash
# =============================================================================
# automation/lib-currency.sh — Helper functions for the currency system
#
# Purpose:  Sources automation/lib-automation.sh (which in turn sources
#           scripts/lib.sh) and adds currency-specific helpers:
#           - Upstream version retrieval (brew, npm, github-release, ollama, mas)
#           - Version comparison (bash-3.2-compatible)
#           - YAML/JSON helpers for tools.yaml
#           - Date calculations (macOS BSD-date)
#           - Registry read operations
# Changes:  Nothing directly — sourced by automation/bin/up2date and
#           automation/bin/sunset
# Requires: bash 3.2+, yq (mikefarah v4+), jq, macOS
# Usage:    source "$(dirname "${BASH_SOURCE[0]}")/lib-currency.sh"
# =============================================================================

[ "${_KICKOFF_CURRENCY_LIB_LOADED:-}" = "1" ] && return 0
_KICKOFF_CURRENCY_LIB_LOADED=1

_LIB_CURRENCY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "$_LIB_CURRENCY_DIR/.." && pwd)"

# lib-automation in turn sources scripts/lib.sh
source "$_LIB_CURRENCY_DIR/lib-automation.sh"

# Path to the registry
TOOLS_YAML="$_REPO_ROOT/manifests/tools.yaml"
# Overridable so a read-only caller can redirect the write. up2date always
# refreshes STATE.json, which is a tracked file — fine when a human runs the
# check, not fine when the GATE runs it, because the gate promises to change
# nothing and would otherwise dirty the worktree it is judging.
# shellcheck disable=SC2034  # STATE_JSON, CHANGELOG_MD are used by up2date/sunset after sourcing
STATE_JSON="${STATE_JSON:-$_REPO_ROOT/manifests/STATE.json}"
CHANGELOG_MD="$_REPO_ROOT/CHANGELOG.md"

# Network timeout in seconds
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"
CURL_RETRY="${CURL_RETRY:-2}"

# =============================================================================
# Dependency checks
# =============================================================================

# Checks whether yq (mikefarah v4+) and jq are available
require_yq() {
    if ! have yq; then
        err "yq not found. Install: brew install yq"
    fi
    # Check minimum version: yq v4 has 'yq --version' = 'yq (https://...) version v4.x.y'
    local ver major
    ver=$(yq --version 2>&1 | grep -oE 'version v[0-9]+' | grep -oE '[0-9]+' || echo "0")
    major="${ver:-0}"
    if [ "${major}" -lt 4 ] 2>/dev/null; then
        err "yq v4+ required (found: v${major}). Upgrade: brew upgrade yq"
    fi
}

require_jq() {
    if ! have jq; then
        err "jq not found. Install: brew install jq"
    fi
}

# =============================================================================
# Version comparison (bash 3.2-compatible, no sort -V)
# =============================================================================

# Compares two version strings segment by segment (dots as separator).
# Returns 0 if $1 > $2, 1 if $1 <= $2
# Supports: 1.2.3, 1.2.3.4, v1.2.3 (leading v is stripped)
version_gt() {
    local v1 v2
    v1=$(printf '%s' "${1:-0}" | sed 's/^v//')
    v2=$(printf '%s' "${2:-0}" | sed 's/^v//')

    # Equal
    [ "$v1" = "$v2" ] && return 1

    # Compare segment by segment
    local IFS_BAK="$IFS"
    IFS='.'
    # shellcheck disable=SC2086
    set -- $v1
    local a1="${1:-0}" a2="${2:-0}" a3="${3:-0}" a4="${4:-0}"
    # shellcheck disable=SC2086
    set -- $v2
    local b1="${1:-0}" b2="${2:-0}" b3="${3:-0}" b4="${4:-0}"
    IFS="$IFS_BAK"

    # Compare each segment numerically (non-numeric → 0)
    a1=$(printf '%s' "$a1" | grep -o '^[0-9]*'); a1="${a1:-0}"
    a2=$(printf '%s' "$a2" | grep -o '^[0-9]*'); a2="${a2:-0}"
    a3=$(printf '%s' "$a3" | grep -o '^[0-9]*'); a3="${a3:-0}"
    a4=$(printf '%s' "$a4" | grep -o '^[0-9]*'); a4="${a4:-0}"
    b1=$(printf '%s' "$b1" | grep -o '^[0-9]*'); b1="${b1:-0}"
    b2=$(printf '%s' "$b2" | grep -o '^[0-9]*'); b2="${b2:-0}"
    b3=$(printf '%s' "$b3" | grep -o '^[0-9]*'); b3="${b3:-0}"
    b4=$(printf '%s' "$b4" | grep -o '^[0-9]*'); b4="${b4:-0}"

    if   [ "$a1" -gt "$b1" ] 2>/dev/null; then return 0
    elif [ "$a1" -lt "$b1" ] 2>/dev/null; then return 1
    elif [ "$a2" -gt "$b2" ] 2>/dev/null; then return 0
    elif [ "$a2" -lt "$b2" ] 2>/dev/null; then return 1
    elif [ "$a3" -gt "$b3" ] 2>/dev/null; then return 0
    elif [ "$a3" -lt "$b3" ] 2>/dev/null; then return 1
    elif [ "$a4" -gt "$b4" ] 2>/dev/null; then return 0
    fi
    return 1
}

# =============================================================================
# Date calculations (macOS BSD-date)
# =============================================================================

# Returns the current date: YYYY-MM-DD
today() {
    date +%Y-%m-%d
}

# Returns today + N days: YYYY-MM-DD
# Usage: date_add_days 90
date_add_days() {
    local n="${1:-90}"
    date -v +"${n}d" +%Y-%m-%d
}

# Returns today - N days: YYYY-MM-DD
date_sub_days() {
    local n="${1:-90}"
    date -v -"${n}d" +%Y-%m-%d
}

# Returns date as YYYYMMDD integer (for comparison)
date_to_int() {
    printf '%s' "${1:-}" | tr -d '-'
}

# Returns 0 if $1 (YYYY-MM-DD) is before or equal to $2 (i.e., due/past)
date_is_due() {
    local target="${1:-}" today_str
    today_str=$(today)
    local t i
    t=$(date_to_int "$target")
    i=$(date_to_int "$today_str")
    # Due if target <= today
    [ "${t:-0}" -le "${i:-0}" ] 2>/dev/null && return 0
    return 1
}

# Returns 0 if the reviewed date is older than N days
date_is_stale() {
    local reviewed="${1:-}" days="${2:-180}"
    local cutoff_str
    cutoff_str=$(date_sub_days "$days")
    local r c
    r=$(date_to_int "$reviewed")
    c=$(date_to_int "$cutoff_str")
    [ "${r:-0}" -le "${c:-0}" ] 2>/dev/null && return 0
    return 1
}

# =============================================================================
# Network requests with timeout and retry
# =============================================================================

# Runs curl with timeout; returns stdout; returns 1 on error
# Respects rate limit (429): wait briefly and retry once
safe_curl() {
    local url="$1"
    local extra_args="${2:-}"

    local attempt result http_code
    for attempt in 1 2; do
        # shellcheck disable=SC2086
        result=$(curl -fsSL \
            --connect-timeout "$CURL_TIMEOUT" \
            --max-time $((CURL_TIMEOUT * 3)) \
            --retry "$CURL_RETRY" \
            --retry-delay 2 \
            -w "\n%{http_code}" \
            $extra_args \
            "$url" 2>/dev/null) || true

        http_code=$(printf '%s' "$result" | tail -1)
        local body
        body=$(printf '%s' "$result" | head -n -1)

        case "$http_code" in
            200) printf '%s' "$body"; return 0 ;;
            429)
                if [ "$attempt" -lt 2 ]; then
                    warn "Rate-Limit (429) from $url — waiting 30 seconds..."
                    sleep 30
                else
                    warn "Rate-Limit persistent at $url"
                    return 1
                fi
                ;;
            *)
                return 1
                ;;
        esac
    done
    return 1
}

# =============================================================================
# Upstream version retrieval by check method
# =============================================================================

# Returns the upstream version, or "unknown" on error/unavailable
# Also emits SUNSET_SIGNAL (via stderr protocol) when upstream is deprecated
# Return format: stdout = version | "unknown"
#                exit code 0 = ok, 1 = error

# --- brew ---
fetch_version_brew() {
    local ref="$1"
    if ! have brew; then
        printf 'unknown'
        return 0
    fi
    local json version deprecated disabled
    json=$(brew info --json=v2 "$ref" 2>/dev/null) || { printf 'unknown'; return 0; }

    # One expression, not two chained with ||. `jq '.formulae[0]...'` on a cask
    # returns EMPTY with exit 0 — it succeeded, it just found nothing — so the
    # `||` fallback never ran and every cask reported "unknown". brew info
    # returns both arrays, exactly one of which is populated, so ask for both
    # and take the first non-empty.
    version=$(printf '%s' "$json" |
        jq -r 'first((.formulae[0].versions.stable // empty),
                     (.casks[0].version // empty)) // empty' 2>/dev/null || echo "")

    # Deprecation flags likewise exist on both shapes — a deprecated cask was
    # invisible for the same reason the version was.
    deprecated=$(printf '%s' "$json" |
        jq -r 'first((.formulae[0].deprecated // empty),
                     (.casks[0].deprecated // empty)) // false' 2>/dev/null || echo "false")
    disabled=$(printf '%s' "$json" |
        jq -r 'first((.formulae[0].disabled // empty),
                     (.casks[0].disabled // empty)) // false' 2>/dev/null || echo "false")

    if [ "$deprecated" = "true" ] || [ "$disabled" = "true" ]; then
        local reason
        reason=$(printf '%s' "$json" |
            jq -r 'first((.formulae[0].deprecation_reason // empty),
                         (.formulae[0].disable_reason // empty),
                         (.casks[0].deprecation_reason // empty),
                         (.casks[0].disable_reason // empty)) // "unknown"' 2>/dev/null || echo "unknown")
        # Sunset signal via special comment on stderr
        printf 'SUNSET_SIGNAL:%s' "$reason" >&2
    fi

    printf '%s' "${version:-unknown}"
}

# --- npm ---
fetch_version_npm() {
    local ref="$1"
    if ! have npm; then
        printf 'unknown'
        return 0
    fi
    local version deprecated
    version=$(npm view "$ref" version 2>/dev/null || echo "")
    deprecated=$(npm view "$ref" deprecated 2>/dev/null || echo "")

    if [ -n "$deprecated" ]; then
        printf 'SUNSET_SIGNAL:%s' "$deprecated" >&2
    fi

    printf '%s' "${version:-unknown}"
}

# --- github-release ---
# check_ref = "owner/repo"
fetch_version_github() {
    local ref="$1"
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

    local api_url="https://api.github.com/repos/$ref/releases/latest"
    local repo_url="https://api.github.com/repos/$ref"

    # Check archived status
    local repo_json archived
    if [ -n "$token" ]; then
        repo_json=$(curl -fsSL --connect-timeout "$CURL_TIMEOUT" \
            -H "Authorization: Bearer $token" \
            "$repo_url" 2>/dev/null) || { printf 'unknown'; return 0; }
    else
        repo_json=$(safe_curl "$repo_url" 2>/dev/null) || { printf 'unknown'; return 0; }
    fi
    archived=$(printf '%s' "$repo_json" | jq -r '.archived // false' 2>/dev/null || echo "false")
    if [ "$archived" = "true" ]; then
        printf 'SUNSET_SIGNAL:GitHub repository archived' >&2
    fi

    # Latest release version
    local release_json version
    if [ -n "$token" ]; then
        release_json=$(curl -fsSL --connect-timeout "$CURL_TIMEOUT" \
            -H "Authorization: Bearer $token" \
            "$api_url" 2>/dev/null) || { printf 'unknown'; return 0; }
    else
        release_json=$(safe_curl "$api_url" 2>/dev/null) || { printf 'unknown'; return 0; }
    fi
    version=$(printf '%s' "$release_json" | jq -r '.tag_name // empty' 2>/dev/null | sed 's/^v//')

    # Check last release date (>12 months = sunset candidate)
    local pub_date cutoff
    pub_date=$(printf '%s' "$release_json" | jq -r '.published_at // empty' 2>/dev/null | cut -c1-10)
    cutoff=$(date_sub_days 365)
    if [ -n "$pub_date" ] && date_is_due "$pub_date" && ! date_is_due "$cutoff"; then
        : # Date was not published before cutoff → OK
    elif [ -n "$pub_date" ]; then
        local pub_int cut_int
        pub_int=$(date_to_int "$pub_date")
        cut_int=$(date_to_int "$cutoff")
        if [ "${pub_int:-0}" -lt "${cut_int:-0}" ] 2>/dev/null; then
            printf 'SUNSET_SIGNAL:Last release older than 12 months (%s)' "$pub_date" >&2
        fi
    fi

    printf '%s' "${version:-unknown}"
}

# --- mas ---
fetch_version_mas() {
    local ref="$1"
    if ! have mas; then
        printf 'unknown'
        return 0
    fi
    # Current version via mas info
    local version
    version=$(mas info "$ref" 2>/dev/null | grep -o 'Version:.*' | head -1 | awk '{print $2}' || echo "unknown")
    printf '%s' "${version:-unknown}"
}

# --- ollama ---
fetch_version_ollama() {
    local ref="$1"
    if ! have ollama; then
        printf 'unknown'
        return 0
    fi
    # 'ollama show <model>' outputs model info; no stable version format
    # We try via the Registry API (best effort)
    local api_url="https://registry.ollama.ai/v2/library/$ref/tags/list"
    local tag
    tag=$(safe_curl "$api_url" 2>/dev/null | jq -r '.tags[0] // empty' 2>/dev/null || echo "")
    if [ -z "$tag" ]; then
        printf 'unknown'
    else
        printf '%s' "$tag"
    fi
}

# --- manual ---
fetch_version_manual() {
    printf 'manual'
}

# Dispatcher: calls the appropriate fetch_version_* function
# Returns stdout: version or "unknown"
# Returns stderr: optional SUNSET_SIGNAL:... when upstream is deprecated/archived
fetch_upstream_version() {
    local check_method="$1"
    local check_ref="$2"

    case "$check_method" in
        brew)           fetch_version_brew "$check_ref" ;;
        npm)            fetch_version_npm "$check_ref" ;;
        github-release) fetch_version_github "$check_ref" ;;
        mas)            fetch_version_mas "$check_ref" ;;
        ollama)         fetch_version_ollama "$check_ref" ;;
        manual)         fetch_version_manual ;;
        *)              printf 'unknown' ;;
    esac
}

# =============================================================================
# Registry read helpers (yq-based)
# =============================================================================

# Returns all IDs from the registry (one per line)
registry_list_ids() {
    yq e '.[].id' "$TOOLS_YAML" 2>/dev/null
}

# Returns the value of a specific field for an ID
# Usage: registry_get <id> <field>
registry_get() {
    local id="$1"
    local field="$2"
    yq e ".[] | select(.id == \"$id\") | .$field" "$TOOLS_YAML" 2>/dev/null
}

# Returns all IDs with a specific status
# Usage: registry_ids_by_status active
registry_ids_by_status() {
    local status="$1"
    yq e ".[] | select(.status == \"$status\") | .id" "$TOOLS_YAML" 2>/dev/null
}

# Returns all IDs that do NOT have a specific status
# Usage: registry_ids_not_status sunset
registry_ids_not_status() {
    local status="$1"
    yq e ".[] | select(.status != \"$status\") | .id" "$TOOLS_YAML" 2>/dev/null
}

# Returns active + candidate IDs (the ones to check)
registry_checkable_ids() {
    yq e '.[] | select(.status == "active" or .status == "candidate") | .id' "$TOOLS_YAML" 2>/dev/null
}

# =============================================================================
# Registry write helpers (yq in-place)
# =============================================================================

# Sets a field for an ID in tools.yaml
# Usage: registry_set <id> <field> <value>
registry_set() {
    local id="$1"
    local field="$2"
    local value="$3"
    # yq in-place edit
    yq e -i "(.[] | select(.id == \"$id\") | .$field) = \"$value\"" "$TOOLS_YAML" 2>/dev/null
}

# Sets a null field (e.g. sunset: null)
registry_set_null() {
    local id="$1"
    local field="$2"
    yq e -i "(.[] | select(.id == \"$id\") | .$field) = null" "$TOOLS_YAML" 2>/dev/null
}

# =============================================================================
# Changelog write helpers
# =============================================================================

# Inserts a line into the Unreleased section of CHANGELOG.md
# Usage: changelog_add_entry "Changed" "pnpm: status changed to deprecated"
changelog_add_entry() {
    local kategorie="$1"
    local text="$2"
    local datum
    datum=$(today)

    if [ ! -f "$CHANGELOG_MD" ]; then
        warn "CHANGELOG.md not found: $CHANGELOG_MD"
        return 1
    fi

    # Check whether the Unreleased section exists
    if ! grep -q "## \[Unreleased\]" "$CHANGELOG_MD"; then
        warn "No [Unreleased] section found in CHANGELOG.md"
        return 1
    fi

    # Insert line after "### <category>" in Unreleased (or create the section)
    local tmp_file
    tmp_file=$(mktemp)
    awk -v kat="$kategorie" -v txt="$text" -v dat="$datum" '
        /## \[Unreleased\]/ { in_unreleased=1 }
        in_unreleased && /^## \[/ && !/## \[Unreleased\]/ { in_unreleased=0 }
        in_unreleased && $0 ~ "^### " kat {
            print
            print "- " dat ": " txt
            found_kat=1
            next
        }
        { print }
        END {
            if (!found_kat) {
                print ""
                print "### " kat
                print "- " dat ": " txt
            }
        }
    ' "$CHANGELOG_MD" > "$tmp_file" && mv "$tmp_file" "$CHANGELOG_MD" || rm -f "$tmp_file"
}

# =============================================================================
# Consistency check helpers
# =============================================================================

# Reads all formula names from a Brewfile
parse_brewfile_formulae() {
    local brewfile="$1"
    [ -f "$brewfile" ] || return 0
    grep -E '^brew "' "$brewfile" | sed 's/^brew "//; s/".*//'
}

# Reads all cask names from a Brewfile
parse_brewfile_casks() {
    local brewfile="$1"
    [ -f "$brewfile" ] || return 0
    grep -E '^cask "' "$brewfile" | sed 's/^cask "//; s/".*//'
}

# Reads all non-comment lines from a .txt manifest file
parse_manifest_txt() {
    local file="$1"
    [ -f "$file" ] || return 0
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$'
}
