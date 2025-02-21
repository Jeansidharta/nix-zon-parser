# Zon parser to Nix expression

This is a function to conver a `.zon` expression to a nix value. `.zon` files are related to the [zig](https://ziglang.org/) language and are mainly used to declare project metadata, such as version, name, and dependencies.

## Motivation

Currently there are very few tools to package zig projects in nix. The main issue is zig's dependencies. During build, zig will try to fetch any missing dependencies from the internet; however, since nix builds are pure, they don't have internet access. Therefore, if we want to package a zig project, we must fetch it ourselves before zig build, and provide these packages to zig using the `zig build --system <PREFETCHED_DEPENDENCIES>` command.

The manual way of doing it is to create a nix flake and populate its inputs with the project's dependencies. We then need to patch `build.zig.zon` to point to our fetched dependency, instead of a URL.

With this project, we could instead read the project's dependencies during evaluation, and automatically fetch theses dependencies using [`fetchurl`](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-fetchers-fetchurl) with the correct hash and version. It would then be very painless to maintain a flake for any zig project.

## Usage

The recomended way of using this is through flakes. Simply add this into your inputs and use its `parse` output:
```nix
{
    inputs.nix-zon-parser.url = "github:Jeansidharta/nix-zon-parser";
    outputs = { nix-zon-parser, ... }: let
        parsed = nix-zon-parser.parse (builtins.readFile ./build.zig.zon);
        inherit (parsed) name version dependencies;

        # You can then use these variables to create your derivation
    in {
        # Rest of your flake
    };
}
```

## Issues

The project is not currently very robust. It is not very well tested, and might give weird results if the zon file is not correctly formated. This project is not meant to validate a zon file, but instead to read data from a valid zon file. Therefore, it assumes the file is correctly formated while parsing it. If you encounter any issues using it, please open an issue.

## Testing

The `test.sh` script should run all automated tests.

## Comparison with Zon2nix

[zon2nix](https://github.com/nix-community/zon2nix) is a project that is similar in spirit, but has a very different purpose.

zon2nix is a CLI script that will take a `build.zig.zon` file as an argument and spit in stdout a nix expression with all of the file's dependencies. Since it's a CLI application, it cannot be used by nix to fetch the project's dependencies at runtime. The user must first manually call `zon2nix build.zig.zon > dependencies.nix` an then import these dependencies in their derivation script. Another issue is that zon2nix only cares about the dependencies, and so it cannot be used to fetch othe metadata, such as the project name or version.

This project is a parser entirely written in nix. This means it is significantly slower than zon2nix, but it allows us to use the information in `build.zig.zon` to make a derivation. The user can then do things like

```nix
{
    parsedBuild = parse (builtins.readFile ./build.zig.zon);
    projectName = parsedBuild.name;
    projectVersion = parsedBuild.version;
    projectDependencies = parsedBuild.dependencies;
}
```

## Contributing

If you wish to open an issue or a PR, feel free to do so. I'll do my best to respond in a timely manner.
