let
  entries = builtins.readDir ./.;
  dirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
in
builtins.listToAttrs (map (name: { inherit name; value = import (./. + "/${name}"); }) dirs)
