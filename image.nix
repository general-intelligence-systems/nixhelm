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
  ];
  fakeRootCommands = ''
    mkdir -p ./lib64
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 ./lib64/ld-linux-x86-64.so.2
  '';
  enableFakechroot = true;
}
