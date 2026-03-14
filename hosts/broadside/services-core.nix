{ lib, pkgs, ... }:

let
  repoSnapshotSource = builtins.path {
    path = ../../.;
    name = "broadside-homelab-source";
    filter = path: type:
      let
        base = baseNameOf path;
      in
      !(
        base == ".git" ||
        base == ".tmp" ||
        base == "result"
      );
  };

  runbookSite = pkgs.runCommandLocal "broadside-runbook-site" { } ''
    mkdir -p "$out"
    cp -R ${../../docs/runbooks} "$out/runbooks"
    cp -R ${../../docs/architecture} "$out/architecture"
    cat > "$out/index.html" <<'EOF'
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Broadside Recovery Site</title>
    </head>
    <body>
      <h1>Broadside Recovery Site</h1>
      <p>Use the runbooks and mirrored repo below during recovery.</p>
      <ul>
        <li><a href="/runbooks/">Runbooks</a></li>
        <li><a href="/architecture/">Architecture</a></li>
        <li><a href="/mirror/">Repo mirror</a></li>
      </ul>
    </body>
    </html>
    EOF
  '';

  repoSnapshot = pkgs.runCommandLocal "broadside-repo-snapshot" { } ''
    mkdir -p "$out"
    cp -R ${repoSnapshotSource} "$out/homelab"
  '';

  repoMirrorSources = [
    "https://git.in.hypyr.space/cpritchett/homelab.git"
  ];
in
{
  environment.systemPackages = with pkgs; [
    bind
    curl
    git
    jq
    nvme-cli
    rsync
    step-cli
    vim
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale.enable = true;

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "0.0.0.0" "::0" ];
        access-control = [
          "127.0.0.0/8 allow"
          "::1 allow"
          "10.0.5.0/24 allow"
          "100.64.0.0/10 allow"
        ];
        local-data = [
          "broadside.in.hypyr.space. IN A 10.0.5.107"
          "runbooks-broadside.in.hypyr.space. IN A 10.0.5.107"
          "mirror-broadside.in.hypyr.space. IN A 10.0.5.107"
          "ca-broadside.in.hypyr.space. IN A 10.0.5.107"
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [ "10.0.5.1@53" ];
        }
      ];
    };
  };

  virtualisation.docker.enable = true;

  services.caddy = {
    enable = true;
    virtualHosts = {
      "broadside.in.hypyr.space" = {
        extraConfig = ''
          root * ${runbookSite}
          file_server
        '';
      };
      "runbooks-broadside.in.hypyr.space" = {
        extraConfig = ''
          root * ${runbookSite}/runbooks
          file_server browse
        '';
      };
      "mirror-broadside.in.hypyr.space" = {
        extraConfig = ''
          root * /srv/recovery/mirror
          file_server browse
        '';
      };
    };
  };

  systemd.services.broadside-repo-mirror = {
    description = "Refresh broadside read-only repo mirror";
    path = with pkgs; [ git openssh ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -euo pipefail
      mkdir -p /srv/recovery/mirror/repos
      mkdir -p /srv/recovery/mirror/snapshots
      rsync -a --delete ${repoSnapshot}/ /srv/recovery/mirror/snapshots/

      repo_dir=/srv/recovery/mirror/repos/homelab.git
      for source in ${lib.escapeShellArgs repoMirrorSources}; do
        if [ ! -d "$repo_dir" ]; then
          if git clone --mirror "$source" "$repo_dir"; then
            exit 0
          fi
          rm -rf "$repo_dir"
          continue
        fi

        if git -C "$repo_dir" remote set-url origin "$source" && git -C "$repo_dir" remote update --prune; then
          exit 0
        fi
      done

      echo "broadside-repo-mirror: snapshot refreshed; no live mirror source reachable" >&2
    '';
  };

  systemd.timers.broadside-repo-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "1h";
      Unit = "broadside-repo-mirror.service";
    };
  };
}
