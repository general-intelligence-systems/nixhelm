{
  description = "A collection of kubernetes helm charts in a nix-digestable format.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    {
      lib = { pkgs }: import ./lib { inherit pkgs; };

      meta = import ./charts;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        helmlib = import ./lib { inherit pkgs; };

        buildChart =
          chartMeta: version:
          helmlib.extractChart (helmlib.fetchChart {
            inherit (chartMeta) repo chart;
            inherit version;
            chartHash = chartMeta.versions.${version};
          });

        mapCharts =
          let
            isChartMeta = v: v ? chart && v ? repo && v ? versions;
            buildEntry = name: value:
              if isChartMeta value then {
                latest = buildChart value value.latest;
                versions = builtins.mapAttrs (ver: _: buildChart value ver) value.versions;
              }
              else builtins.mapAttrs buildEntry value;
          in
          builtins.mapAttrs buildEntry self.meta;
      in
      {
        charts = mapCharts;

        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt-tree
            pkgs.kubernetes-helm
            pkgs.crane
            pkgs.curl
            pkgs.yq-go
            pkgs.jq
            pkgs.unixtools.xxd
            pkgs.ruby
          ];
        };
      }
    );
}
