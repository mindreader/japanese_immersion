{
  description = "Hatch Elixir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    lib = pkgs.lib;
    pname = "japanese-immersion";
    version = "0.1.0";
    src = ./.;
    mixFodDeps = pkgs.beamPackages.fetchMixDeps {
      inherit pname version src;
      hash = "sha256-JLyjcFBlixlyhLobbPf/eloYS5MeKfGMLHpaFvXT3T8=";
    };
    japanese-immersion-release = pkgs.beamPackages.mixRelease {
      inherit pname version src mixFodDeps;
    };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      name = "elixir-shell";
      packages = with pkgs; [
        pkgs.beam.packages.erlang_27.elixir_1_18
        pkgs.rebar3
        elixir-ls
        inotify-tools
      ];
    };
    packages.x86_64-linux.default = japanese-immersion-release;
    packages.x86_64-linux.japanese-immersion-release = japanese-immersion-release;
  };
}
