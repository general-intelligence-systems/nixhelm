let
  stable = import ./stable;
  contrib = import ./contrib;
in
stable // { inherit stable contrib; }
