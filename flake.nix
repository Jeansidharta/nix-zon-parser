{
  inputs = { };
  outputs =
    { ... }:
    let
      parser = import ./parser.nix;
    in
    {
      inherit parser;
    };
}
