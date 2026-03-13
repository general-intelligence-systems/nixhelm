# AGENTS.md

## Project Overview

nixhelm is a Nix flake that provides Helm charts as Nix derivations. Charts are declared in YAML data files (`data/http-repos.yaml` and `data/oci-repos.yaml`), and Bash scripts in `bin/` generate the corresponding `.nix` chart files by querying upstream registries for versions and hashes. Charts are regenerated nightly via GitHub Actions.

## Repository Structure

```
bin/                              # Bash scripts for chart generation
charts/
  <repo_name>/
    <chart_name>.nix              # Generated chart definition (5 fields)
    default.nix                   # Auto-generated; imports all charts in directory
  default.nix                     # Auto-generated; imports all repo directories
data/
  http-repos.yaml                 # Declarative registry of HTTP Helm repos + charts
  oci-repos.yaml                  # Declarative registry of OCI Helm repos + charts
lib/
  default.nix                     # Nix library: fetchChart, extractChart, applyValues
flake.nix                         # Flake definition
image.nix                         # OCI container image for CI
packages/                         # Wishlist/index of apps to add
```

## Chart Definition Format

Every chart is a `.nix` file in `charts/<repo_name>/` with exactly 5 fields:

```nix
{
  repo = "<repository URL>";
  chart = "<chart name>";
  latest = "<latest stable version>";
  versions = {
    "<version>" = "<SRI hash>";
    ...
  };
}
```

HTTP repository example (`charts/argoproj/argo-cd.nix`):

```nix
{
  repo = "https://argoproj.github.io/argo-helm";
  chart = "argo-cd";
  latest = "9.4.10";
  versions = {
    "9.4.10" = "sha256-n1ihetUtB6SbczYPB/geWZxVKV0/L4KKtsrxcbHSul0=";
    "9.4.9" = "sha256-A3DsYtrjnsAIBzKa6WQclT1/4q+BmBH2Zxcg5X+b9po=";
    ...
  };
}
```

OCI registry example (`charts/forgejo/forgejo.nix`):

```nix
{
  repo = "oci://code.forgejo.org/forgejo-helm";
  chart = "forgejo";
  latest = "16.2.1";
  versions = {
    "16.2.1" = "sha256-Ct6YvKVbNpESeH8AwEhvlXDiSiuXlYnnRBJupf0YIjs=";
    "16.2.0" = "sha256-YjkU4XD5n3tUQt5MemWo49O9RaksF3e99jhnqAElsG0=";
    ...
  };
}
```

The format is identical for HTTP and OCI -- only the `repo` URL scheme differs (`https://` vs `oci://`). Each chart file contains all known stable versions, not just the latest.

## Data Files

Charts are declared in two YAML files. The `regex` field filters which upstream version tags are included.

### `data/http-repos.yaml`

```yaml
argoproj:
  url: https://argoproj.github.io/argo-helm
  charts:
    argo-cd:
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
    argocd-image-updater:
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
```

A chart can override the repo-level URL:

```yaml
cloudnative-pg:
  url: https://cloudnative-pg.github.io/charts
  charts:
    cloudnative-pg:
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
    plugin-barman-cloud:
      url: https://cloudnative-pg.io/charts
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
```

### `data/oci-repos.yaml`

```yaml
forgejo:
  registry: code.forgejo.org/forgejo-helm
  charts:
    forgejo:
      regex: '^[0-9]+\.[0-9]+\.[0-9]+$'
```

Some OCI charts allow `v`-prefixed versions:

```yaml
envoyproxy:
  registry: registry-1.docker.io/envoyproxy
  charts:
    gateway-helm:
      regex: '^v?[0-9]+\.[0-9]+\.[0-9]+$'
```

## Adding a New Helm Chart

1. Add an entry to `data/http-repos.yaml` (for HTTP repos) or `data/oci-repos.yaml` (for OCI registries).
2. Run the generation scripts:
   ```sh
   bin/generate-repo <repo_name> http   # or: bin/generate-repo <repo_name> oci
   bin/generate-defaults
   ```
3. Stage and commit the new files.

Alternatively, just add the YAML entry and let the nightly CI workflow generate the chart files automatically.

## Generation Scripts

| Script | Description |
|---|---|
| `bin/generate` | Full regeneration: wipes `charts/`, regenerates all repos from both YAML files, runs `generate-defaults`. |
| `bin/generate-repo <repo> <http\|oci>` | Generates all chart `.nix` files for one repo into `charts/<repo>/`. |
| `bin/generate-defaults` | Generates `default.nix` import files for each repo directory and the top-level `charts/default.nix`. |
| `bin/helm-versions [filter]` | Reads `data/http-repos.yaml`, fetches each repo's `index.yaml`, outputs version/hash data. |
| `bin/oci-versions [filter]` | Reads `data/oci-repos.yaml`, lists OCI tags via `crane ls`, outputs version data. |
| `bin/hash-oci-version` | Reads version lines from stdin, computes SRI hashes from OCI manifests via `crane manifest`. |
| `bin/mkchart` | Reads version/hash lines from stdin, outputs a Nix attribute set (the chart `.nix` file content). |

## Flake Outputs

| Output | Description |
|---|---|
| `meta` | Raw chart metadata attribute set (`import ./charts`). |
| `lib { pkgs }` | Returns `{ fetchChart, extractChart, applyValues }` from `lib/default.nix`. |
| `charts.${system}.${repo}.${chart}.latest` | Built derivation for the latest stable version. |
| `charts.${system}.${repo}.${chart}.versions.${version}` | Built derivation for a specific version. |
| `formatter.${system}` | `nixfmt-tree`. |
| `devShells.${system}.default` | Shell with nixfmt-tree, helm, crane, curl, yq-go, jq, xxd. |

### Library Functions (`lib/default.nix`)

- **`fetchChart { repo, chart, version, chartHash }`** -- Downloads a chart tarball as a fixed-output derivation. Handles both HTTP and OCI schemes.
- **`extractChart tarball`** -- Extracts a chart `.tgz` into a directory, stripping the top-level component.
- **`applyValues { chart, name, namespace?, values?, includeCRDs?, kubeVersion?, apiVersions?, extraOpts? }`** -- Renders a chart with `helm template`.

## CI/CD

| Workflow | Trigger | Purpose |
|---|---|---|
| `update-all.yml` | Daily cron + manual dispatch | Orchestrates full chart update: calls `generate-http` and `generate-oci`, collects artifacts, runs `generate-defaults`, commits and pushes. |
| `generate-http.yml` | Called by `update-all` | Builds a matrix from `data/http-repos.yaml` keys, runs `bin/generate-repo <repo> http` per repo in parallel. |
| `generate-oci.yml` | Called by `update-all` | Builds a matrix from `data/oci-repos.yaml` keys, runs `bin/generate-repo <repo> oci` per repo in parallel. |
| `pages.yml` | Push to main (packages changes) + manual | Builds the packages category index and deploys to GitHub Pages. |

Dependabot is configured for weekly GitHub Actions dependency updates.

## Important Notes

- Chart `.nix` files in `charts/` are **generated** -- do not edit them by hand. Edit the YAML data files in `data/` and regenerate instead.
- `default.nix` files are **auto-generated** by `bin/generate-defaults` -- never edit them manually.
- Files must be git-tracked for Nix to see them.
- The `regex` field in the data YAML files controls which version tags are included (typically stable-only patterns).
- SRI hashes are computed automatically from upstream digests (HTTP `index.yaml` or OCI manifests via `crane`) -- never write them by hand.
- Charts are updated nightly via GitHub Actions.
