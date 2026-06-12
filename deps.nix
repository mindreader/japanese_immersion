{
  pkgs,
  lib,
  beamPackages,
  overrides ? (x: y: { }),
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ pkgs.beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        ...
      }:
      old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay = import "${
          fetchTarball {
            url = "https://github.com/nix-community/fenix/archive/056c9393c821a4df356df6ce7f14c722dc8717ec.tar.gz";
            sha256 = "sha256:1cdfh6nj81gjmn689snigidyq7w98gd8hkl5rvhly6xj7vyppmnd";
          }
        }/overlay.nix";
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (extendedPkgs.makeRustPlatform {
            inherit (fenix) cargo rustc;
          }).buildRustPackage
            {
              pname = "${old.packageName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [
                extendedPkgs.cmake
              ] ++ extendedPkgs.lib.lists.optional extendedPkgs.stdenv.isDarwin extendedPkgs.darwin.IOKit;
              doCheck = false;
            };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            ln -s "$lib" "priv/native/$(basename "$lib")"
          done
        '';

        buildPhase = ''
          suggestion() {
            echo "***********************************************"
            echo "                 deps_nix                      "
            echo
            echo " Rust dependency build failed.                 "
            echo
            echo " If you saw network errors, you might need     "
            echo " to disable compilation on the appropriate     "
            echo " RustlerPrecompiled module in your             "
            echo " application config.                           "
            echo
            echo " We think you need this:                       "
            echo
            echo -n " "
            grep -Rl 'use RustlerPrecompiled' lib \
              | xargs grep 'defmodule' \
              | sed 's/defmodule \(.*\) do/config :${old.packageName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
          ${old.buildPhase}
        '';
      };
  };

  defaultOverrides = (
    final: prev:

    let
      apps = {
        crc32cer = [
          {
            name = "portCompiler";
          }
        ];
        explorer = [
          {
            name = "rustlerPrecompiled";
            toolchain = {
              name = "nightly-2024-11-01";
              sha256 = "sha256-wq7bZ1/IlmmLkSa3GUJgK17dTWcKyf5A+ndS9yRwB88=";
            };
          }
        ];
        snappyer = [
          {
            name = "portCompiler";
          }
        ];
      };

      applyOverrides =
        appName: drv:
        let
          allOverridesForApp = builtins.foldl' (
            acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
          ) { } apps.${appName};

        in
        if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

    in
    builtins.mapAttrs applyOverrides prev
  );

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {

      anthropix =
        let
          version = "0.6.2";
          drv = buildMix {
            inherit version;
            name = "anthropix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "anthropix";
              sha256 = "2e42885494ec4db68f703c17fbd815c711db00e04c77b4ba3fcaa5cf1892648f";
            };

            beamDeps = [
              jason
              nimble_options
              req
            ];
          };
        in
        drv;

      bandit =
        let
          version = "1.12.0";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bandit";
              sha256 = "45dac82dc86f45cf4a196dee9cc5a8b791d9c9469d996055f055e6ee36c66e20";
            };

            beamDeps = [
              hpax
              plug
              telemetry
              thousand_island
              websock
            ];
          };
        in
        drv;

      briefly =
        let
          version = "0.5.1";
          drv = buildMix {
            inherit version;
            name = "briefly";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "briefly";
              sha256 = "bd684aa92ad8b7b4e0d92c31200993c4bc1469fc68cd6d5f15144041bd15cb57";
            };
          };
        in
        drv;

      castore =
        let
          version = "1.0.19";
          drv = buildMix {
            inherit version;
            name = "castore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "castore";
              sha256 = "3669e6cab13f54c2df26b3e6833745d647f35b6e30d8ddd5975df0d5c842ca98";
            };
          };
        in
        drv;

      decimal =
        let
          version = "3.1.1";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "c5f25f2ced74a0587d03e6023f595db8e924c9d3922c8c8ffd9edfc4498cf1f6";
            };
          };
        in
        drv;

      dns_cluster =
        let
          version = "0.1.3";
          drv = buildMix {
            inherit version;
            name = "dns_cluster";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "dns_cluster";
              sha256 = "46cb7c4a1b3e52c7ad4cbe33ca5079fbde4840dedeafca2baf77996c2da1bc33";
            };
          };
        in
        drv;

      earmark =
        let
          version = "1.4.49";
          drv = buildMix {
            inherit version;
            name = "earmark";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "earmark";
              sha256 = "ffad0257b92ac342b236d1744f7f19793da77bbd7281f32ccdfb44c047a05bf2";
            };
          };
        in
        drv;

      ecto =
        let
          version = "3.14.0";
          drv = buildMix {
            inherit version;
            name = "ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto";
              sha256 = "130d69ffb4285f9ce4792b65dfbb994fd13ea4cbc3cbea2524b199aa3de84af3";
            };

            beamDeps = [
              decimal
              jason
              telemetry
            ];
          };
        in
        drv;

      esbuild =
        let
          version = "0.10.0";
          drv = buildMix {
            inherit version;
            name = "esbuild";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "esbuild";
              sha256 = "468489cda427b974a7cc9f03ace55368a83e1a7be12fba7e30969af78e5f8c70";
            };

            beamDeps = [
              jason
            ];
          };
        in
        drv;

      expo =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "expo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "expo";
              sha256 = "fbadf93f4700fb44c331362177bdca9eeb8097e8b0ef525c9cc501cb9917c960";
            };
          };
        in
        drv;

      finch =
        let
          version = "0.20.0";
          drv = buildMix {
            inherit version;
            name = "finch";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "finch";
              sha256 = "2658131a74d051aabfcba936093c903b8e89da9a1b63e430bee62045fa9b2ee2";
            };

            beamDeps = [
              mime
              mint
              nimble_options
              nimble_pool
              telemetry
            ];
          };
        in
        drv;

      gettext =
        let
          version = "0.26.2";
          drv = buildMix {
            inherit version;
            name = "gettext";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gettext";
              sha256 = "aa978504bcf76511efdc22d580ba08e2279caab1066b76bb9aa81c4a1e0a32a5";
            };

            beamDeps = [
              expo
            ];
          };
        in
        drv;

      heroicons = pkgs.fetchFromGitHub {
        owner = "tailwindlabs";
        repo = "heroicons";
        rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
        hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
      };

      hpax =
        let
          version = "1.0.3";
          drv = buildMix {
            inherit version;
            name = "hpax";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hpax";
              sha256 = "8eab6e1cfa8d5918c2ce4ba43588e894af35dbd8e91e6e55c817bca5847df34a";
            };
          };
        in
        drv;

      jason =
        let
          version = "1.4.5";
          drv = buildMix {
            inherit version;
            name = "jason";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jason";
              sha256 = "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      mime =
        let
          version = "2.0.7";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
            };
          };
        in
        drv;

      mint =
        let
          version = "1.9.0";
          drv = buildMix {
            inherit version;
            name = "mint";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mint";
              sha256 = "007154c7d8c43916aed3c93afd1f11aebbaa9c5ff4b7ba55ebe0d17ee0296042";
            };

            beamDeps = [
              castore
              hpax
            ];
          };
        in
        drv;

      nimble_options =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "nimble_options";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_options";
              sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
            };
          };
        in
        drv;

      nimble_pool =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "nimble_pool";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_pool";
              sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
            };
          };
        in
        drv;

      phoenix =
        let
          version = "1.8.8";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "f0c843037bd2e7012fc1d1ec9574dfa6972b7e3d09e9b77fd23aa283af0aa994";
            };

            beamDeps = [
              bandit
              jason
              phoenix_pubsub
              phoenix_template
              plug
              plug_crypto
              telemetry
              websock_adapter
            ];
          };
        in
        drv;

      phoenix_html =
        let
          version = "4.3.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad";
            };
          };
        in
        drv;

      phoenix_live_dashboard =
        let
          version = "0.8.7";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_dashboard";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_dashboard";
              sha256 = "3a8625cab39ec261d48a13b7468dc619c0ede099601b084e343968309bd4d7d7";
            };

            beamDeps = [
              ecto
              mime
              phoenix_live_view
              telemetry_metrics
            ];
          };
        in
        drv;

      phoenix_live_view =
        let
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "e540d7c98dbb1c9714c204af690a71e389093efe66cdcd1c18764878219e16d7";
            };

            beamDeps = [
              jason
              phoenix
              phoenix_html
              phoenix_template
              plug
              telemetry
            ];
          };
        in
        drv;

      phoenix_pubsub =
        let
          version = "2.2.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96";
            };
          };
        in
        drv;

      phoenix_template =
        let
          version = "1.0.4";
          drv = buildMix {
            inherit version;
            name = "phoenix_template";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_template";
              sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206";
            };

            beamDeps = [
              phoenix_html
            ];
          };
        in
        drv;

      plug =
        let
          version = "1.19.2";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "b6fce20a56af5e60fa5dfecf3f907bb98ec981be43c79a3809a499bc3d133de0";
            };

            beamDeps = [
              mime
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      plug_crypto =
        let
          version = "2.1.1";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "6470bce6ffe41c8bd497612ffde1a7e4af67f36a15eea5f921af71cf3e11247c";
            };
          };
        in
        drv;

      req =
        let
          version = "0.5.14";
          drv = buildMix {
            inherit version;
            name = "req";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "req";
              sha256 = "b7b15692071d556c73432c7797aa7e96b51d1a2db76f746b976edef95c930021";
            };

            beamDeps = [
              finch
              jason
              mime
              plug
            ];
          };
        in
        drv;

      tailwind =
        let
          version = "0.2.4";
          drv = buildMix {
            inherit version;
            name = "tailwind";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tailwind";
              sha256 = "c6e4a82b8727bab593700c998a4d98cf3d8025678bfde059aed71d0000c3e463";
            };

            beamDeps = [
              castore
            ];
          };
        in
        drv;

      telemetry =
        let
          version = "1.4.2";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1";
            };
          };
        in
        drv;

      telemetry_metrics =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "telemetry_metrics";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "telemetry_metrics";
              sha256 = "e7b79e8ddfde70adb6db8a6623d1778ec66401f366e9a8f5dd0955c56bc8ce67";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      telemetry_poller =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry_poller";

            src = fetchHex {
              inherit version;
              pkg = "telemetry_poller";
              sha256 = "51f18bed7128544a50f75897db9974436ea9bfba560420b646af27a9a9b35211";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      tesla =
        let
          version = "1.20.0";
          drv = buildMix {
            inherit version;
            name = "tesla";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tesla";
              sha256 = "3ecb41cb458772332752c3acdfe983e23abb991f5a43cfd69a64e9ea3f4b0061";
            };

            beamDeps = [
              castore
              finch
              jason
              mime
              mint
              telemetry
            ];
          };
        in
        drv;

      thousand_island =
        let
          version = "1.5.0";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "708923d40523e43cf99041ab37a0d4b0ec426ac6438fa3716ab23d919eaeb412";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      websock =
        let
          version = "0.5.3";
          drv = buildMix {
            inherit version;
            name = "websock";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock";
              sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
            };
          };
        in
        drv;

      websock_adapter =
        let
          version = "0.5.9";
          drv = buildMix {
            inherit version;
            name = "websock_adapter";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock_adapter";
              sha256 = "5534d5c9adad3c18a0f58a9371220d75a803bf0b9a3d87e6fe072faaeed76a08";
            };

            beamDeps = [
              bandit
              plug
              websock
            ];
          };
        in
        drv;

    };
in
self
