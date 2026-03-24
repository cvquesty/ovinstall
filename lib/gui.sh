#!/bin/bash
#
# =============================================================================
# ovinstall - OpenVox-GUI Installation
# =============================================================================
# Clones the OpenVox-GUI repository and runs its built-in installer.
# Requires: functions.sh (logging), git
# =============================================================================

install_gui() {
    log_info "=========================================="
    log_info "Installing OpenVox-GUI"
    log_info "=========================================="

    clone_gui_repo
    run_gui_installer

    log_info "OpenVox-GUI installation complete"
}

clone_gui_repo() {
    local gui_dir="/opt/openvox-gui"
    local gui_repo="${gui_repo_url:-https://github.com/cvquesty/openvox-gui.git}"

    log_info "Cloning OpenVox-GUI from $gui_repo..."

    if [[ -d "$gui_dir/.git" ]]; then
        log_info "GUI directory exists, updating..."
        # Use a subshell so cd doesn't affect the caller
        (
            cd "$gui_dir" || exit 1
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        )
    else
        rm -rf "$gui_dir"
        git clone "$gui_repo" "$gui_dir"
    fi

    if [[ ! -d "$gui_dir" ]]; then
        log_fatal "Failed to clone OpenVox-GUI repository"
    fi
}

run_gui_installer() {
    local gui_dir="/opt/openvox-gui"

    if [[ ! -f "$gui_dir/install.sh" ]]; then
        log_fatal "GUI install.sh not found at $gui_dir/install.sh"
    fi

    chmod +x "$gui_dir/install.sh"

    log_info "Running GUI installer..."

    # Run inside a subshell to avoid changing the working directory
    (
        cd "$gui_dir" || exit 1
        if [[ "$NONINTERACTIVE" == "true" ]]; then
            # Pipe 'yes' for non-interactive confirmation prompts
            yes "" 2>/dev/null | ./install.sh
        else
            ./install.sh
        fi
    )
}
