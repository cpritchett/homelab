{ lib, modulesPath, pkgs, ... }:

let
  installScript = pkgs.writeShellScript "install-broadside.sh" ''
    set -euo pipefail

    ASSET_BASE_URL="''${ASSET_BASE_URL:-http://10.0.5.121:8480/assets/broadside}"
    REPO_URL="''${REPO_URL:-$ASSET_BASE_URL/homelab.tar.gz}"
    DISKO_URL="''${DISKO_URL:-$ASSET_BASE_URL/disko.tar.gz}"
    NIXPKGS_URL="''${NIXPKGS_URL:-$ASSET_BASE_URL/nixpkgs.tar.gz}"
    REPO_DIR="''${REPO_DIR:-/root/homelab}"
    DISKO_DIR="''${DISKO_DIR:-/root/disko}"
    NIXPKGS_DIR="''${NIXPKGS_DIR:-/root/nixpkgs}"

    echo "[broadside-installer] fetching repo bundle from $REPO_URL"
    rm -rf "$REPO_DIR"
    mkdir -p "$REPO_DIR"
    curl -fsSL "$REPO_URL" | tar -xz -C "$REPO_DIR" --strip-components=1

    echo "[broadside-installer] fetching disko input from $DISKO_URL"
    rm -rf "$DISKO_DIR"
    mkdir -p "$DISKO_DIR"
    curl -fsSL "$DISKO_URL" | tar -xz -C "$DISKO_DIR" --strip-components=1

    echo "[broadside-installer] fetching nixpkgs input from $NIXPKGS_URL"
    rm -rf "$NIXPKGS_DIR"
    mkdir -p "$NIXPKGS_DIR"
    curl -fsSL "$NIXPKGS_URL" | tar -xz -C "$NIXPKGS_DIR" --strip-components=1

    echo "[broadside-installer] apply disko layout"
    nix --extra-experimental-features "nix-command flakes" \
      run "path:$DISKO_DIR" --override-input nixpkgs "path:$NIXPKGS_DIR" -- \
      --mode disko "$REPO_DIR/hosts/broadside/disko.nix"

    echo "[broadside-installer] install nixos configuration"
    nixos-install --no-root-password \
      --flake "$REPO_DIR#broadside" \
      --override-input nixpkgs "path:$NIXPKGS_DIR" \
      --override-input disko "path:$DISKO_DIR"

    echo
    echo "[broadside-installer] installation complete"
    echo "[broadside-installer] reboot when ready"
  '';
in
{
  imports = [
    "${modulesPath}/installer/netboot/netboot-minimal.nix"
  ];

  networking.hostName = "broadside-installer";
  time.timeZone = "America/Chicago";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.getty.autologinUser = lib.mkForce "root";

  environment.systemPackages = with pkgs; [
    bind
    curl
    ethtool
    gptfdisk
    iproute2
    jq
    nvme-cli
    step-cli
    vim
  ];

  systemd.services.broadside-installer-helper = {
    description = "Install Broadside helper script";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -m 0700 ${installScript} /root/install-broadside.sh
    '';
  };

  system.stateVersion = "24.05";
}
