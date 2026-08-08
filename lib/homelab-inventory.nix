{
  lib,
  services ? import ./homelab-services.nix,
}: let
  inherit (lib) mkOption types;

  quiesceType = types.submodule {
    options = {
      unit = mkOption {
        type = types.strMatching "[A-Za-z0-9_.@-]+";
      };
      until = mkOption {
        type = types.enum ["dump" "archive"];
      };
      scope = mkOption {
        type = types.enum ["system" "user"];
        default = "system";
      };
      user = mkOption {
        type = types.nullOr (types.strMatching "[A-Za-z0-9_.-]+");
        default = null;
      };
    };
  };

  endpointType = types.submodule {
    options = {
      authorizationOwner = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      bindScope = mkOption {
        type = types.enum ["loopback" "host"];
        default = "loopback";
      };
      exposure = mkOption {
        type = types.enum ["public" "tailnet" "local" "none"];
        default = "none";
      };
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      monitorPath = mkOption {
        type = types.str;
        default = "";
      };
      pathBackends = mkOption {
        type = types.attrsOf types.port;
        default = {};
      };
      port = mkOption {
        type = types.nullOr types.port;
        default = null;
      };
    };
  };

  stateType = types.submodule {
    options = {
      paths = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      database = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      disposable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  backupType = types.submodule {
    options = {
      strategy = mkOption {
        type = types.nullOr (types.enum ["direct" "archive-transform" "application-export"]);
        default = null;
      };
      artifacts = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      transformedPaths = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      quiesce = mkOption {
        type = types.listOf quiesceType;
        default = [];
      };
    };
  };

  storageType = types.submodule {
    options = {
      units = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };

  operationsType = types.submodule {
    options = {
      units = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      monitorException = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  presentationType = types.submodule {
    options = {
      description = mkOption {type = types.str;};
      group = mkOption {
        type = types.enum ["applications" "operations"];
      };
      icon = mkOption {type = types.str;};
      order = mkOption {type = types.int;};
      title = mkOption {type = types.str;};
    };
  };

  recoveryType = types.submodule {
    options = {
      acceptance = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      order = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
      owner = mkOption {
        type = types.nullOr types.str;
        default = "homelab-operator";
      };
      runbook = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      secretOwners = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      versionPolicy = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  serviceType = types.submodule ({config, ...}: {
    options = {
      endpoint = mkOption {
        type = endpointType;
        default = {};
      };
      state = mkOption {
        type = stateType;
        default = {};
      };
      backup = mkOption {
        type = backupType;
        default = {};
      };
      storage = mkOption {
        type = storageType;
        default = {};
      };
      operations = mkOption {
        type = operationsType;
        default = {};
      };
      presentation = mkOption {
        type = types.nullOr presentationType;
        default = null;
      };
      recovery = mkOption {
        type = recoveryType;
        default = {};
      };
    };

    config.backup.strategy = lib.mkDefault (
      if config.state.disposable || (config.state.paths == [] && config.state.database == null)
      then null
      else "direct"
    );
  });

  typed =
    (lib.evalModules {
      modules = [
        {
          options.services = mkOption {type = types.attrsOf serviceType;};
          config.services = services;
        }
      ];
    }).config.services;

  stateKind = state:
    if state.disposable
    then "disposable"
    else if state.database != null && state.paths != []
    then "database+files"
    else if state.database != null
    then "database"
    else if state.paths != []
    then "files"
    else "none";
  normalize = name: service:
    service
    // {
      inherit name;
      state = service.state // {kind = stateKind service.state;};
      storage =
        service.storage
        // {
          requiresSrv = lib.any (lib.hasPrefix "/srv/") service.state.paths;
        };
      backup =
        service.backup
        // {
          archivePaths = lib.unique (
            builtins.filter (path: !(builtins.elem path service.backup.transformedPaths)) service.state.paths
            ++ service.backup.artifacts
          );
        };
      tailscaleServiceName =
        if service.endpoint.exposure == "tailnet"
        then "svc:${name}"
        else null;
    };
  normalized = lib.mapAttrs normalize typed;

  pathCoveredBy = roots: path:
    lib.any (root: path == root || lib.hasPrefix "${root}/" path) roots;
  validate = name: service: let
    inherit (service) backup endpoint operations recovery state storage;
  in
    assert lib.assertMsg (lib.all (entry:
      (entry.scope == "system" -> entry.user == null)
      && (entry.scope == "user" -> entry.user != null && entry.user != ""))
    backup.quiesce)
    "homelab service ${name} has invalid quiesce scope or user metadata";
    assert lib.assertMsg (endpoint.exposure == "none" || endpoint.port != null)
    "homelab service ${name} must declare a port when it has an endpoint";
    assert lib.assertMsg (endpoint.exposure != "public" || (endpoint.hostname != null && endpoint.hostname != ""))
    "public homelab service ${name} must declare a hostname";
    assert lib.assertMsg (!(builtins.elem endpoint.exposure ["public" "tailnet"])
      || (endpoint.authorizationOwner != null && endpoint.authorizationOwner != ""))
    "externally exposed homelab service ${name} must declare its authorization owner";
    assert lib.assertMsg (builtins.elem state.kind ["none" "disposable"] || backup.strategy != null)
    "stateful homelab service ${name} must declare or inherit a backup strategy";
    assert lib.assertMsg (backup.strategy != "application-export" || backup.artifacts != [])
    "application-export service ${name} must declare its produced artifacts";
    assert lib.assertMsg (backup.strategy
      != "archive-transform"
      || (backup.transformedPaths != [] && backup.artifacts != []))
    "archive-transform service ${name} must declare transformed state and its produced artifacts";
    assert lib.assertMsg (backup.strategy == "archive-transform" || backup.transformedPaths == [])
    "only archive-transform service ${name} may omit primary state in favor of generated artifacts";
    assert lib.assertMsg (
      state.disposable
      || state.kind == "none"
      || (
        lib.all (path:
          pathCoveredBy backup.archivePaths path
          || builtins.elem path backup.transformedPaths)
        state.paths
        && lib.all (path: builtins.elem path state.paths) backup.transformedPaths
      )
    )
    "homelab service ${name} must map every primary state path to an archive path or explicit transformation";
    assert lib.assertMsg (!state.disposable
      || (
        state.kind
        == "disposable"
        && state.paths == []
        && state.database == null
        && backup.archivePaths == []
        && backup.artifacts == []
        && backup.transformedPaths == []
        && backup.strategy == null
        && backup.quiesce == []
      ))
    "disposable homelab service ${name} cannot claim required recovery data";
    assert lib.assertMsg (!storage.requiresSrv || storage.units != [])
    "homelab service ${name} requires /srv but declares no dependent units";
    assert lib.assertMsg (endpoint.exposure == "none" || operations.units != [] || operations.monitorException != null)
    "monitored homelab service ${name} needs an important unit or explicit exception";
    assert lib.assertMsg (state.kind
      == "none"
      || (
        recovery.acceptance
        != []
        && recovery.order != null
        && recovery.owner != null
        && recovery.owner != ""
        && recovery.runbook != null
        && recovery.runbook != ""
        && recovery.versionPolicy != null
        && recovery.versionPolicy != ""
      ))
    "stateful homelab service ${name} must declare recovery ownership, order, version policy, runbook, and acceptance checks"; service;

  validated = lib.mapAttrs validate normalized;
  endpointPorts = lib.concatMap (
    service:
      lib.optional (service.endpoint.port != null) service.endpoint.port
      ++ builtins.attrValues service.endpoint.pathBackends
  ) (builtins.attrValues validated);
  publicHostnames = lib.filter (hostname: hostname != null) (
    map (service: service.endpoint.hostname) (
      lib.filter (service: service.endpoint.exposure == "public") (builtins.attrValues validated)
    )
  );
  duplicate = values: builtins.length values != builtins.length (lib.unique values);
in
  assert lib.assertMsg (!duplicate endpointPorts)
  "homelab endpoint ports, including path backends, must be globally unique";
  assert lib.assertMsg (!duplicate publicHostnames)
  "public homelab hostnames must be globally unique"; validated
