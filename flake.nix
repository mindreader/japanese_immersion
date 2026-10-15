{
  description = "Hatch Elixir";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    # One BEAM toolchain for everything: the dev shell, the deps in deps.nix
    # and the release. Previously the release used pkgs.beamPackages, whose
    # default Elixir lagged the dev shell's (1.18 vs 1.20), so production was
    # compiled without the 1.20 type checker the code was developed against.
    beamPackages = pkgs.beam.packages.erlang_28.overrideScope (final: prev: {
      elixir = prev.elixir_1_20;
    });
    lib = pkgs.lib;
    pname = "japanese-immersion";
    version = "0.1.0";
    src = ./.;
    removeCookie = false;

    mixNixDeps = import ./deps.nix {
      inherit lib beamPackages;
      inherit (pkgs) cmake fetchFromGitHub lexbor oniguruma pkg-config stdenv vips writeText;
      extend = lib.id;
    };

    japanese-immersion-release = beamPackages.mixRelease {
      inherit pname version src mixNixDeps removeCookie;

      postBuild = ''

        export DATABASE_URL=""
        export SECRET_KEY_BASE=""
        export ANTHROPIC_API_KEY=""
        export CORPUS_DIR=""

        tailwind_path="$(mix do \
          app.config --no-deps-check --no-compile + \
          eval 'Tailwind.bin_path() |> IO.puts()')"
        esbuild_path="$(mix do \
          app.config --no-deps-check --no-compile + \
          eval 'Esbuild.bin_path() |> IO.puts()')"

        ln -sfv ${pkgs.tailwindcss}/bin/tailwindcss "$tailwind_path"
        ln -sfv ${pkgs.esbuild}/bin/esbuild "$esbuild_path"
        rm -rf deps/heroicons
        # deps_nix (3.1+) wraps the checkout in a derivation with the source
        # at $out/src; .src is the fetchFromGitHub checkout itself.
        ln -sv ${mixNixDeps.heroicons.src} deps/heroicons

        mix do \
          app.config --no-deps-check --no-compile + \
                      assets.deploy --no-deps-check
      '';
    };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      name = "elixir-shell";
      packages = with pkgs; [
        beamPackages.elixir
        beamPackages.erlang
        beamPackages.rebar3
        elixir-ls
        inotify-tools
      ];
    };
    packages.x86_64-linux.default = japanese-immersion-release;
    packages.x86_64-linux.japanese-immersion-release = japanese-immersion-release;

  };
}
