{ lib, config, pkgs, ... }:
let
  cfg = config.services.peerix;

  peerix = pkgs.callPackage ./default.nix {};
in
{
  options = with lib; {
    services.peerix = {
      enable = lib.mkEnableOption "peerix";

      openFirewall = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Defines whether or not firewall ports should be opened for it.
        '';
      };

      privateKeyFile = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          The private key to sign the derivations with.
        '';
      }; 

      publicKeyFile = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          The private key to sign the derivations with.
        '';
      };

      user = lib.mkOption {
        type = with types; oneOf [ str int ];
        default = "nobody";
        description = ''
          The user the service will use.
        '';
      };

      group = lib.mkOption {
        type = with types; oneOf [ str int ];
        default = "nobody";
        description = ''
          The user the service will use.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd.services.peerix = {
      description = "Local p2p nix caching daemon";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";

        User = cfg.user;
        Group = cfg.group;

        PrivateMounts = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateIPC = true;
        PrivateUsers = true;

        SystemCallFilters = [
          "@aio"
          "@basic-io"
          "@file-system"
          "@io-event"
          "@process"
          "@network-io"
          "@timer"
          "@signal"
          "@alarm"
        ];
        SystemCallErrorNumber = "EPERM";

        ProtectSystem = "full";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
        RestrictNamespaces = "";

        NoNewPrivileges = true;
        ReadOnlyPaths = lib,mkMerge [
          ([
            "/nix/var"
            "/nix/store"
          ])

          (lib.mkIf (cfg.privateKeyFile != null) [
            (toString cfg.privateKeyFile)
          ]);
        ];
        ExecPaths = [
          "/nix/store"
        ];
        Environment = lib.mkIf (cfg.privateKeyFile != null) [
          "NIX_SECRET_KEY_FILE=${toString cfg.privateKeyFile}"
        ];
      };
      script = ''
        exec ${peerix}/bin/peerix
      '';
    };

    nix = {
      binaryCaches = [
        "http://127.0.0.1:12304/"
      ];
      binaryCachePublicKeys = lib.mkIf (cfg.publicKeyFile != null) [
        (builtins.readFile cfg.publicKeyFile)
      ];
    };

    networking.firewall = lib.mkIf (cfg.openFirewall) {
      allowedTCPPorts = [ 12304 ];
      allowedUDPPorts = [ 12304 ];
    };
  };
}