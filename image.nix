{ pkgs, lib, org, registry, ... }:
{
  name = "${registry}/nixhelm-generate";
  tag = "latest";
  contents = with pkgs; [
    bash
    coreutils
    gnugrep
    gawk
    findutils
    curl
    yq-go
    jq
    crane
    unixtools.xxd
    git
    cacert
    nodejs
    python3
    ruby
  ];
}
