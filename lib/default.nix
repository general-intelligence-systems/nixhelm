{ pkgs }:
{
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
}
