<!-- Generated from README.md.erb by bin/generate-readme -- do not edit directly -->
# nixhelm2

A collection of **805** Helm charts across **111** repositories in a nix-digestible format.

## Supported chart repositories

Nixhelm supports both traditional HTTP Helm chart repositories and OCI-compliant registries:

- **HTTP/HTTPS repositories** (ChartMuseum, traditional Helm repos)
- **OCI registries** (GitHub Container Registry, Docker Hub, Harbor, etc.)

If your chart is hosted in a git repo, remember that you can fetch it as a flake
input and pass to `fetchChart`.

## Outputs

The flake exposes three top-level outputs:

### `meta`

`meta.${repo}.${chart}` contains raw metadata about each chart:

```nix
{
  repo = "https://argoproj.github.io/argo-helm";
  chart = "argo-cd";
  latest = "9.4.10";
  versions = {
    "9.4.10" = "sha256-hmCCq6j8bkeOG+DOmSvMW9LMBaBARC2aeqWyDVnX1SA=";
    "9.4.9" = "sha256-...";
    # ...
  };
}
```

### `lib`

`lib { pkgs }` returns a set of three functions for working with charts:

- **`fetchChart { repo, chart, version, chartHash }`** -- downloads a chart tarball as a fixed-output derivation.
- **`extractChart tarball`** -- extracts a chart tarball into a directory.
- **`applyValues { chart, name, namespace?, values?, ... }`** -- renders a chart with `helm template`.

### `charts`

`charts.${system}.${repo}.${chart}` contains built derivations:

- `.latest` -- the latest stable version, extracted.
- `.versions.${version}` -- a specific version, extracted.

## Usage

### Building a chart

```sh
# Build the latest version
nix build .#charts.x86_64-linux.argoproj.argo-cd.latest

# Build a specific version
nix build .#charts.x86_64-linux.argoproj.argo-cd.versions.'"9.4.10"'
```

The chart will be extracted to `result/`.

### Using in a flake

Add nixhelm as a flake input and use `lib` to fetch and render charts:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixhelm.url = "github:general-intelligence-systems/nixhelm2";
  };

  outputs = { nixpkgs, nixhelm, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      helmlib = nixhelm.lib { inherit pkgs; };
    in {
      # Use a pre-built chart derivation directly
      packages.x86_64-linux.argo-chart =
        nixhelm.charts.x86_64-linux.argoproj.argo-cd.latest;

      # Or render a chart with custom values using applyValues
      packages.x86_64-linux.argo-rendered = helmlib.applyValues {
        chart = nixhelm.charts.x86_64-linux.argoproj.argo-cd.latest;
        name = "argo";
        namespace = "argo";
        values = {
          server.replicas = 2;
        };
      };
    };
}
```

`applyValues` accepts the following parameters:

| Parameter | Required | Description |
|---|---|---|
| `chart` | yes | An extracted chart derivation |
| `name` | yes | Release name for `helm template` |
| `namespace` | no | Kubernetes namespace |
| `values` | no | Attribute set of Helm values |
| `includeCRDs` | no | Include CRDs (default: `true`) |
| `kubeVersion` | no | Kubernetes version to template for |
| `apiVersions` | no | List of additional API versions |
| `extraOpts` | no | List of extra flags passed to `helm template` |

## Adding new charts

Charts are defined declaratively in YAML files under `data/`. To add a new chart, add an entry to the appropriate file and submit a pull request.

### HTTP repository

Add an entry to `data/http-repos.yaml`:

```yaml
my-repo:
  - https://my-repo.github.io/helm-charts
```

### OCI registry

Add an entry to `data/oci-repos.yaml`:

```yaml
my-repo:
  registry: ghcr.io/my-org/charts
  charts:
    my-chart:
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
```

### Notes

- The `regex` field controls which versions are included. Use it to filter out pre-release tags.
- If a repo already exists in the YAML file, just add your chart under its `charts` key.
- Charts are generated and updated automatically via CI -- you only need to declare them.

## Packages to Add

See [packages/](packages/README.md) for the full categorized wishlist.

## License

Apache-2.0
