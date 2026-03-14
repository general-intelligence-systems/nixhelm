# AGENTS.md

## Project Overview

nixhelm is a Nix flake that provides Helm charts as Nix derivations. Charts are declared in YAML data files (`data/http-repos.yaml` and `data/oci-repos.yaml`), and Bash scripts in `bin/` generate the corresponding `.nix` chart files by querying upstream registries for versions and hashes. Charts are regenerated nightly via GitHub Actions.

Charts are organized into two categories:
- **stable** -- Charts from trusted, well-known upstream projects (whitelisted in `data/stable.yaml`).
- **contrib** -- Community/unofficial charts (anything not in the stable whitelist).

## Repository Structure

```
bin/                              # Bash scripts for chart generation
charts/
  stable/
    <repo_name>/
      <chart_name>.nix            # Generated chart definition (5 fields)
      default.nix                 # Auto-generated; imports all charts in directory
    default.nix                   # Auto-generated; imports all repo directories
  contrib/
    <repo_name>/
      <chart_name>.nix            # Generated chart definition (5 fields)
      default.nix                 # Auto-generated; imports all charts in directory
    default.nix                   # Auto-generated; imports all repo directories
  default.nix                     # Auto-generated; merges stable to top-level, exposes stable/contrib
data/
  http-repos.yaml                 # Declarative registry of HTTP Helm repos + charts
  oci-repos.yaml                  # Declarative registry of OCI Helm repos + charts
  stable.yaml                     # Whitelist of repo names considered stable
lib/
  default.nix                     # Nix library: fetchChart, extractChart, applyValues
flake.nix                         # Flake definition
image.nix                         # OCI container image for CI
packages/                         # Wishlist/index of apps to add
```

## Chart Categories

Repos are categorized as **stable** or **contrib** based on the whitelist in `data/stable.yaml`.

- `data/stable.yaml` is a YAML list of repo names considered trusted/stable.
- Any repo **not** in `data/stable.yaml` is automatically treated as **contrib**.
- The `bin/chart-category` helper script resolves a repo name to its category.

Stable charts are promoted to the top-level `meta` attribute set for backward compatibility. Contrib charts are only accessible under `meta.contrib.<repo>.<chart>`.

## Chart Definition Format

Every chart is a `.nix` file in `charts/{stable,contrib}/<repo_name>/` with exactly 5 fields:

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

HTTP repository example (`charts/stable/argoproj/argo-cd.nix`):

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

OCI registry example (`charts/stable/forgejo/forgejo.nix`):

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

The format is identical for HTTP and OCI -- only the `repo` URL scheme differs (`https://` vs `oci://`). Each chart file contains all known versions, not just the latest.

## Data Files

Charts are declared in two YAML files, and categorized by a third.

### `data/http-repos.yaml`

Each repo maps to a list of HTTP Helm repository URLs. All charts and all versions from each URL's `index.yaml` are included automatically -- no chart names or version filters are specified.

```yaml
argoproj:
  - https://argoproj.github.io/argo-helm
```

When charts come from multiple URLs, list all of them:

```yaml
cloudnative-pg:
  - https://cloudnative-pg.github.io/charts
  - https://cloudnative-pg.io/charts
```

### `data/oci-repos.yaml`

OCI repos use a different format with explicit chart names and `regex` version filters.

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

### `data/stable.yaml`

A YAML list of repo names that are considered trusted/stable. Any repo not listed here defaults to contrib.

```yaml
- argoproj
- bitnami
- grafana
...
```

## Adding a New Helm Chart

1. Add an entry to `data/http-repos.yaml` (for HTTP repos) or `data/oci-repos.yaml` (for OCI registries).
2. If the repo is from a trusted/official source, add the repo name to `data/stable.yaml`. Otherwise it will default to contrib.
3. Run the generation scripts:
   ```sh
   bin/generate-helm-repo <repo_name>   # for HTTP repos
   bin/generate-oci-repo <repo_name>    # for OCI repos
   bin/generate-defaults
   ```
4. Stage and commit the new files.

Alternatively, just add the YAML entries and let the nightly CI workflow generate the chart files automatically.

## Generation Scripts

| Script | Description |
|---|---|
| `bin/generate` | Full regeneration: wipes `charts/`, recreates `stable/` and `contrib/` subdirs, regenerates all repos from both YAML files, runs `generate-defaults`. |
| `bin/generate-helm-repo <repo>` | Resolves repo category via `bin/chart-category`, generates all chart `.nix` files into `charts/{stable,contrib}/<repo>/`. |
| `bin/generate-oci-repo <repo>` | Resolves repo category, generates OCI chart `.nix` files into `charts/{stable,contrib}/<repo>/`. |
| `bin/generate-defaults` | Generates `default.nix` import files for each repo directory, each category directory, and the top-level `charts/default.nix` (which merges stable to top-level). |
| `bin/chart-category <repo>` | Returns `stable` or `contrib` for a given repo name, based on `data/stable.yaml`. |
| `bin/helm-versions [filter]` | Reads `data/http-repos.yaml`, fetches each URL's `index.yaml`, enumerates all charts and versions, outputs version/hash data. |
| `bin/oci-versions [filter]` | Reads `data/oci-repos.yaml`, lists OCI tags via `crane ls`, outputs version data. |
| `bin/oci-hashes [filter]` | Reads existing chart `.nix` files (using category lookup) to extract known version hashes. |
| `bin/hash-oci-version` | Reads version lines from stdin, computes SRI hashes from OCI manifests via `crane manifest`. |
| `bin/mkchart` | Reads version/hash lines from stdin, outputs a Nix attribute set (the chart `.nix` file content). |

## Flake Outputs

| Output | Description |
|---|---|
| `meta` | Raw chart metadata attribute set (`import ./charts`). Stable repos are promoted to top-level for backward compat. `meta.stable` and `meta.contrib` provide explicit access. |
| `lib { pkgs }` | Returns `{ fetchChart, extractChart, applyValues }` from `lib/default.nix`. |
| `charts.${system}.${repo}.${chart}.latest` | Built derivation for the latest stable version (stable repos only, backward compat). |
| `charts.${system}.stable.${repo}.${chart}.latest` | Built derivation for a stable chart (explicit path). |
| `charts.${system}.contrib.${repo}.${chart}.latest` | Built derivation for a contrib chart. |
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
| `generate-http.yml` | Called by `update-all` | Builds a matrix from `data/http-repos.yaml` keys, runs `bin/generate-helm-repo <repo>` per repo in parallel. |
| `generate-oci.yml` | Called by `update-all` | Builds a matrix from `data/oci-repos.yaml` keys, runs `bin/generate-oci-repo <repo>` per repo in parallel. |
| `pages.yml` | Push to main (packages changes) + manual | Builds the packages category index and deploys to GitHub Pages. |

Dependabot is configured for weekly GitHub Actions dependency updates.

## Important Notes

- Chart `.nix` files in `charts/` are **generated** -- do not edit them by hand. Edit the YAML data files in `data/` and regenerate instead.
- `default.nix` files are **auto-generated** by `bin/generate-defaults` -- never edit them manually.
- Files must be git-tracked for Nix to see them.
- The `regex` field in `data/oci-repos.yaml` controls which OCI version tags are included (typically stable-only patterns). HTTP repos include all versions automatically.
- SRI hashes are computed automatically from upstream digests (HTTP `index.yaml` or OCI manifests via `crane`) -- never write them by hand.
- Charts are updated nightly via GitHub Actions.
- New repos default to **contrib** unless explicitly added to `data/stable.yaml`.
- The top-level `charts/default.nix` merges stable repos to the top level (`stable // { inherit stable contrib; }`), preserving backward compatibility for stable chart access paths while keeping contrib charts namespaced.
