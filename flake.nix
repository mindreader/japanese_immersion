{
  description = "Hatch Elixir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    beamPackages = pkgs.beam.packages.erlang_27;
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    lib = pkgs.lib;
    pname = "japanese-immersion";
    version = "0.1.0";
    src = ./.;
    removeCookie = false;

    mixNixDeps = import ./deps.nix {
      inherit beamPackages lib pkgs;
    };

    japanese-immersion-release = pkgs.beamPackages.mixRelease {
      inherit pname version src mixNixDeps removeCookie;

      postBuild = ''

        export DATABASE_URL=""
        export SECRET_KEY_BASE=""
        export ANTHROPIC_API_KEY=""
        export CORPUS_DIR=""

        tailwind_path="$(mix do \
          app.config --no-deps-check --no-compile, \
          eval 'Tailwind.bin_path() |> IO.puts()')"
        esbuild_path="$(mix do \
          app.config --no-deps-check --no-compile, \
          eval 'Esbuild.bin_path() |> IO.puts()')"

        ln -sfv ${pkgs.tailwindcss}/bin/tailwindcss "$tailwind_path"
        ln -sfv ${pkgs.esbuild}/bin/esbuild "$esbuild_path"
        ln -sfv ${mixNixDeps.heroicons} deps/heroicons

        mix do \
          app.config --no-deps-check --no-compile, \
                      assets.deploy --no-deps-check
      '';
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
