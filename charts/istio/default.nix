{
  "base" = import ./base.nix;
  "cni" = import ./cni.nix;
  "gateway" = import ./gateway.nix;
  "istiod" = import ./istiod.nix;
}
