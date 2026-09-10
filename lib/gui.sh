#!/bin/bash
#
# =============================================================================
# ovinstall - OpenVox-GUI Installation
# =============================================================================
# Clones the OpenVox-GUI repository and runs its built-in installer.
# Requires: functions.sh (logging), git
#
# SEC-003: allowlist gui_repo_url; pin gui_repo_ref; opt-in for untrusted remotes.
# =============================================================================

DEFAULT_GUI_REPO_URL="${DEFAULT_GUI_REPO_URL:-https://github.com/cvquesty/openvox-gui.git}"
DEFAULT_GUI_REPO_REF="${DEFAULT_GUI_REPO_REF:-main}"

# Allowlisted remotes for the same openvox-gui repo (HTTPS + SSH)
_gui_repo_allowlisted() {
    local url="$1"
    case "$url" in
        https://github.com/cvquesty/openvox-gui.git|\
        https://github.com/cvquesty/openvox-gui|\
        git@github.com:cvquesty/openvox-gui.git|\
        git@github.com:cvquesty/openvox-gui|\
        ssh://git@github.com/cvquesty/openvox-gui.git|\
        ssh://git@github.com/cvquesty/openvox-gui)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_assert_gui_repo_trusted() {
    local url="$1"
    if _gui_repo_allowlisted "$url"; then
        return 0
    fi
    if [[ "${allow_untrusted_gui_repo:-false}" == "true" || "${allow_untrusted_gui_repo:-false}" == "yes" ]]; then
        log_warn "SECURITY: allow_untrusted_gui_repo=true — installing GUI from non-allowlisted URL: $url"
        return 0
    fi
    log_fatal "gui_repo_url '$url' is outside the allowlist (expected $DEFAULT_GUI_REPO_URL or SSH equivalent). Set allow_untrusted_gui_repo=true to override (discouraged)."
}

install_gui() {
    log_info "=========================================="
    log_info "Installing OpenVox-GUI"
    log_info "=========================================="

    local gui_repo="${gui_repo_url:-$DEFAULT_GUI_REPO_URL}"
    local gui_ref="${gui_repo_ref:-$DEFAULT_GUI_REPO_REF}"
    gui_repo_url="$gui_repo"
    gui_repo_ref="$gui_ref"

    _assert_gui_repo_trusted "$gui_repo"

    clone_gui_repo
    run_gui_installer

    log_info "OpenVox-GUI installation complete"
}

clone_gui_repo() {
    local gui_dir="/opt/openvox-gui"
    local gui_repo="${gui_repo_url:-$DEFAULT_GUI_REPO_URL}"
    local gui_ref="${gui_repo_ref:-$DEFAULT_GUI_REPO_REF}"

    # Only operate on the exact expected path
    if [[ "$gui_dir" != "/opt/openvox-gui" ]]; then
        log_fatal "Refusing unexpected GUI install path: $gui_dir"
    fi

    log_info "Fetching OpenVox-GUI from $gui_repo (ref: $gui_ref)..."

    if [[ -d "$gui_dir/.git" ]]; then
        log_info "GUI git checkout exists; updating in place to ref '$gui_ref'..."
        if ! (
            cd "$gui_dir" || exit 1
            git fetch --depth 1 origin "$gui_ref"
            git checkout -f "$gui_ref" 2>/dev/null || git checkout -f "FETCH_HEAD"
        ); then
            log_fatal "Failed to update existing GUI checkout to ref '$gui_ref'"
        fi
    else
        if [[ -e "$gui_dir" ]]; then
            # Only remove the exact expected directory (non-git leftover)
            if [[ "$gui_dir" == "/opt/openvox-gui" ]]; then
                log_warn "Removing non-git path $gui_dir before clone"
                rm -rf "$gui_dir"
            else
                log_fatal "Refusing to remove unexpected path: $gui_dir"
            fi
        fi
        if ! git clone --branch "$gui_ref" --depth 1 "$gui_repo" "$gui_dir"; then
            # Some remotes reject --branch for non-branch refs; clone then checkout
            if ! git clone "$gui_repo" "$gui_dir"; then
                log_fatal "Failed to clone OpenVox-GUI repository"
            fi
            if ! (
                cd "$gui_dir" || exit 1
                git checkout -f "$gui_ref"
            ); then
                log_fatal "Failed to checkout gui_repo_ref '$gui_ref'"
            fi
        fi
    fi

    if [[ ! -f "$gui_dir/install.sh" ]]; then
        log_fatal "GUI install.sh not found at $gui_dir/install.sh"
    fi
}

run_gui_installer() {
    local gui_dir="/opt/openvox-gui"

    if [[ ! -f "$gui_dir/install.sh" ]]; then
        log_fatal "GUI install.sh not found at $gui_dir/install.sh"
    fi

    chmod +x "$gui_dir/install.sh"

    log_info "Running GUI installer..."

    (
        cd "$gui_dir" || exit 1
        if [[ "$NONINTERACTIVE" == "true" ]]; then
            if ./install.sh --help 2>&1 | grep -q -- '--non-interactive'; then
                ./install.sh --non-interactive
            else
                log_warn "GUI installer has no documented --non-interactive flag; auto-accepting prompts via yes-pipe (only after allowlist/ref checks)."
                yes "" 2>/dev/null | ./install.sh
            fi
        else
            ./install.sh
        fi
    )
}
