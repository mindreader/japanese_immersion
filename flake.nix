{
  description = "Hatch Elixir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in with pkgs; {

    # nix develop
    devShells.x86_64-linux.default = pkgs.mkShell {

      name = "elixir-shell";
      packages = with pkgs; [
        pkgs.beam.packages.erlang_27.elixir_1_18
        pkgs.rebar3
        elixir-ls
        inotify-tools
      ];
    };
  };
}
