{ pkgs }:
rec {
  fetchChart =
    {
      repo,
      chart,
      version,
      chartHash,
    }:
    let
      pullFlags =
        if (pkgs.lib.hasPrefix "oci://" repo)
        then "${repo}/${chart}"
        else ''--repo "${repo}" "${chart}"'';
    in
    pkgs.stdenv.mkDerivation {
      name = "helm-chart-${chart}-${version}.tgz";
      nativeBuildInputs = [ pkgs.cacert ];
      phases = [ "installPhase" ];
      installPhase = ''
        export HELM_CACHE_HOME="$TMP/.nix-helm-build-cache"
        mkdir -p "$TMP/out"
        ${pkgs.kubernetes-helm}/bin/helm pull \
          --version "${version}" \
          ${pullFlags} \
          -d "$TMP/out"
        mv "$TMP/out"/*.tgz "$out"
      '';
      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = chartHash;
    };

  extractChart =
    tarball:
    pkgs.stdenv.mkDerivation {
      name = "${tarball.name}-extracted";
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p "$out"
        tar xzf "${tarball}" --strip-components=1 -C "$out"
      '';
    };

  applyValues =
    {
      chart,
      name,
      namespace ? null,
      values ? { },
      includeCRDs ? true,
      kubeVersion ? null,
      apiVersions ? [ ],
      extraOpts ? [ ],
    }:
    let
      namespaceFlag = if namespace != null then "--namespace ${namespace}" else "";
      crdFlag = if includeCRDs then "--include-crds" else "";
      kubeFlag = if kubeVersion != null then "--kube-version ${kubeVersion}" else "";
      apiFlags = builtins.concatStringsSep " " (map (v: "-a ${v}") apiVersions);
    in
    pkgs.stdenv.mkDerivation {
      name = "helm-rendered-${name}";
      passAsFile = [ "helmValues" ];
      helmValues = builtins.toJSON values;
      phases = [ "installPhase" ];
      installPhase = ''
        ${pkgs.kubernetes-helm}/bin/helm template \
          ${crdFlag} \
          ${namespaceFlag} \
          ${kubeFlag} \
          --values "$helmValuesPath" \
          "${name}" \
          "${chart}" \
          ${apiFlags} \
          ${builtins.concatStringsSep " " extraOpts} \
          >> $out
      '';
    };

  # ── fromYAML ──────────────────────────────────────────────────────────
  # Parse a multi-document YAML string into a list of Nix attrsets.
  fromYAML = yaml: pkgs.lib.pipe yaml [
    (yaml: (pkgs.stdenv.mkDerivation {
      inherit yaml;
      passAsFile = "yaml";
      name = "fromYAML";
      phases = [ "buildPhase" ];
      buildPhase = "${pkgs.yq}/bin/yq -Ms . $yamlPath > $out";
    }))
    builtins.readFile
    builtins.fromJSON
    (builtins.filter (v: v != null))
  ];

  # ── fromHelm ──────────────────────────────────────────────────────────
  # Render a helm chart and parse the output into a list of Nix attrsets.
  # Accepts the same arguments as applyValues.
  fromHelm = args: pkgs.lib.pipe args [ applyValues builtins.readFile fromYAML ];
}
