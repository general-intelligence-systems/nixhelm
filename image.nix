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
    python3
    ruby
    glibc
    stdenv.cc.cc.lib
  ];
}
