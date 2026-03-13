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

        mapCharts = builtins.mapAttrs (
          repoName: charts:
          builtins.mapAttrs (
            chartName: chartMeta: {
              latest = buildChart chartMeta chartMeta.latest;
              versions = builtins.mapAttrs (version: hash: buildChart chartMeta version) chartMeta.versions;
            }
          ) charts
        ) self.meta;
      in
      {
        charts = mapCharts;

        packages.ci-image = pkgs.dockerTools.buildLayeredImage (import ./image.nix {
          inherit pkgs;
          inherit (pkgs) lib;
          org = "general-intelligence-systems";
          registry = "ghcr.io/general-intelligence-systems";
        });

        formatter = pkgs.nixfmt-tree;

        devShell = pkgs.mkShell {
          packages = [
            pkgs.nixfmt-tree
            pkgs.kubernetes-helm
            pkgs.crane
            pkgs.curl
            pkgs.yq-go
            pkgs.jq
            pkgs.unixtools.xxd
          ];
        };
      }
    );
}
