let
  expected = {
    dependencies = {
      libevdev = {
        hash = "1220db899097092487a8a93f158766e41e9de8daa4e92094711d75c86f91c0f347f9";
        lazy = true;
        url = "https://some-url.com/some-package.zip";
      };
    };
    minimum_zig_version = "0.13.0";
    name = "PROJECT-NAME";
    paths = [
      "build"
      "build.zig"
      "build.zig.zon"
      "src"
      "LICENSE"
      "README.md"
    ];
    version = "0.0.0";
  };
in
{
  val = (import ./parser.nix) (builtins.readFile ./test.zon);
  # TODO - compare val to the expected value
}
