{ lib, ... }:

{
  networking.hostName = "broadside";
  networking.useNetworkd = true;
  networking.useDHCP = lib.mkForce false;
  systemd.network.enable = true;

  systemd.network.links = {
    "10-lan0" = {
      matchConfig.Path = "pci-0000:01:00.0";
      linkConfig.Name = "lan0";
    };
    "10-lan1" = {
      matchConfig.Path = "pci-0000:02:00.0";
      linkConfig.Name = "lan1";
    };
  };

  systemd.network.netdevs."20-bond0" = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
      MTUBytes = "1500";
    };
    bondConfig = {
      Mode = "802.3ad";
      LACPTransmitRate = "slow";
      MIIMonitorSec = "100ms";
      TransmitHashPolicy = "layer2";
    };
  };

  systemd.network.networks = {
    "30-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig.Bond = "bond0";
      linkConfig.RequiredForOnline = "enslaved";
    };
    "30-lan1" = {
      matchConfig.Name = "lan1";
      networkConfig.Bond = "bond0";
      linkConfig.RequiredForOnline = "enslaved";
    };
    "40-bond0" = {
      matchConfig.Name = "bond0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        LinkLocalAddressing = "ipv6";
      };
      dhcpV4Config = {
        RouteMetric = 100;
        UseDNS = false;
      };
    };
  };

  systemd.network.wait-online.anyInterface = true;

  networking.nameservers = [
    "127.0.0.1"
    "10.0.5.1"
  ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 53 80 443 9000 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
