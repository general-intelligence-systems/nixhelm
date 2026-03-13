{
  "elasticsearch" = import ./elasticsearch.nix;
  "external-dns" = import ./external-dns.nix;
  "ghost" = import ./ghost.nix;
  "mariadb-galera" = import ./mariadb-galera.nix;
  "mastodon" = import ./mastodon.nix;
  "mongodb" = import ./mongodb.nix;
  "mysql" = import ./mysql.nix;
  "nginx" = import ./nginx.nix;
  "postgresql" = import ./postgresql.nix;
  "rabbitmq-cluster-operator" = import ./rabbitmq-cluster-operator.nix;
  "valkey" = import ./valkey.nix;
  "wordpress" = import ./wordpress.nix;
}
