{
  "kube-prometheus-stack" = import ./kube-prometheus-stack.nix;
  "prometheus-blackbox-exporter" = import ./prometheus-blackbox-exporter.nix;
  "prometheus-operator-crds" = import ./prometheus-operator-crds.nix;
  "prometheus" = import ./prometheus.nix;
}
