let
  entries = builtins.readDir ./.;
  nixFiles = builtins.filter (
    name: name != "default.nix" && builtins.match ".*\\.nix" name != null
  ) (builtins.attrNames entries);
  toChart = name: {
    name = builtins.replaceStrings [ ".nix" ] [ "" ] name;
    value = import (./. + "/${name}");
  };
in
builtins.listToAttrs (map toChart nixFiles)
