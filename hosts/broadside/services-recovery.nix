{ config, lib, ... }:

let
  cfg = config.broadside.recovery;
in
{
  options.broadside.recovery = {
    enableStepCa = lib.mkEnableOption "optional broadside step-ca restore target";
    enableUptimeKuma = lib.mkEnableOption "optional broadside uptime kuma";
    enablePxeHelpers = lib.mkEnableOption "optional broadside dnsmasq and matchbox helpers";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enableStepCa {
      virtualisation.oci-containers.containers.step-ca = {
        image = "smallstep/step-ca:latest";
        ports = [ "9000:9000" ];
        volumes = [
          "/srv/recovery/appdata/step-ca:/home/step"
        ];
        cmd = [
          "/bin/sh"
          "-c"
          "exec step-ca --password-file /home/step/secrets/password /home/step/config/ca.json"
        ];
      };
    })

    (lib.mkIf cfg.enableUptimeKuma {
      virtualisation.oci-containers.containers.uptime-kuma = {
        image = "louislam/uptime-kuma:latest";
        ports = [ "3001:3001" ];
        volumes = [
          "/srv/recovery/appdata/uptime-kuma:/app/data"
        ];
      };
    })

    (lib.mkIf cfg.enablePxeHelpers {
      virtualisation.oci-containers.containers.dnsmasq = {
        image = "quay.io/poseidon/dnsmasq:v0.5.0-47-g28ff327";
        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--network=host"
        ];
        volumes = [
          "/srv/recovery/pxe/dnsmasq.conf:/etc/dnsmasq.conf:ro"
        ];
      };

      virtualisation.oci-containers.containers.matchbox = {
        image = "quay.io/poseidon/matchbox:v0.11.0";
        ports = [ "8480:8080" ];
        cmd = [
          "-address=0.0.0.0:8080"
          "-assets-path=/assets"
        ];
        volumes = [
          "/srv/recovery/pxe/matchbox:/var/lib/matchbox:ro"
          "/srv/recovery/pxe/assets:/assets:ro"
        ];
      };
    })
  ];
}
