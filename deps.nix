{
  lib,
  beamPackages,
  cmake,
  extend,
  lexbor,
  fetchFromGitHub,
  oniguruma,
  overrides ? (x: y: { }),
  overrideFenixOverlay ? null,
  rustlerPrecompiledOverrides ? { },
  stdenv,
  pkg-config,
  vips,
  writeText,
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        buildInputs ? [ ],
        nativeBuildInputs ? [ ],
        env ? { },
        ...
      }:
      old:
      let
        extendedPkgs = extend fenixOverlay;
        fenixOverlay =
          if overrideFenixOverlay == null then
            import "${
              fetchTarball {
                url = "https://github.com/nix-community/fenix/archive/6399553b7a300c77e7f07342904eb696a5b6bf9d.tar.gz";
                sha256 = "sha256-C6tT7K1Lx6VsYw1BY5S3OavtapUvEnDQtmQB5DSgbCc=";
              }
            }/overlay.nix"
          else
            overrideFenixOverlay;
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (
            (extendedPkgs.makeRustPlatform {
              inherit (fenix) cargo rustc;
            }).buildRustPackage
            {
              inherit env buildInputs;
              pname = "${old.beamModuleName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [ extendedPkgs.cmake ] ++ nativeBuildInputs;
              doCheck = false;
            }
          ).overrideAttrs
            rustlerPrecompiledOverrides.${old.beamModuleName} or { };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            dest="$(basename "$lib")"
            if [[ "''${dest##*.}" = "dylib" ]]
            then
              dest="''${dest%.dylib}.so"
            fi
            dest="''${dest#lib}"
            ln -s "$lib" "priv/native/$dest"
          done
        '';

        preBuild = ''
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
              | sed 's/defmodule \(.*\) do/config :${old.beamModuleName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
        '';
      };

    elixirMake = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';
    };

    lazyHtml = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';

      postPatch = ''
        substituteInPlace mix.exs \
          --replace-fail "Fine.include_dir()" '"${packages.fine}/src/c_include"' \
          --replace-fail '@lexbor_git_sha "244b84956a6dc7eec293781d051354f351274c46"' '@lexbor_git_sha ""'
      '';

      preBuild = ''
        install -Dm644           -t _build/c/third_party/lexbor/$LEXBOR_GIT_SHA/build           ${lexbor}/lib/liblexbor_static.a
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
              name = "nightly-2025-06-23";
              sha256 = "sha256-UAoZcxg3iWtS+2n8TFNfANFt/GmkuOMDf7QAE0fRxeA=";
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
          version = "1.13.0";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "bandit";
              sha256 = "c6511e2b604073294cbfe767592a8110a5cff47f787fe9d5a80377818d876f13";
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

      decimal =
        let
          version = "3.2.0";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "190bca80580ce61aa69bb0eacadd7677710205c770225c2c2c07e32a5c31b234";
            };
          };
        in
        drv;

      dns_cluster =
        let
          version = "0.3.1";
          drv = buildMix {
            inherit version;
            name = "dns_cluster";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "dns_cluster";
              sha256 = "afa60bbbd84463e977eeeecc0c564d8c5ddea260beccdb8d5f45cbb860846627";
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
          version = "3.14.2";
          drv = buildMix {
            inherit version;
            name = "ecto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ecto";
              sha256 = "25d60b8c816a07d19d85b80bdf60978bd8b102209dda198d768cd7c6745339a6";
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
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "expo";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "expo";
              sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640";
            };
          };
        in
        drv;

      finch =
        let
          version = "0.24.0";
          drv = buildMix {
            inherit version;
            name = "finch";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "finch";
              sha256 = "33ba40069c3587c2f99f9125b766e19dad87d6d54be3c6961db2304df04cef00";
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
          version = "1.0.2";
          drv = buildMix {
            inherit version;
            name = "gettext";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gettext";
              sha256 = "eab805501886802071ad290714515c8c4a17196ea76e5afc9d06ca85fb1bfeb3";
            };

            beamDeps = [
              expo
            ];
          };
        in
        drv;

      heroicons = stdenv.mkDerivation {
        name = "heroicons";
        src = fetchFromGitHub {
          owner = "tailwindlabs";
          repo = "heroicons";
          rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
          hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
        };
        buildPhase = ''
          mkdir $out
          ln -sv $src $out/src
        '';
      };

      hpax =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "hpax";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hpax";
              sha256 = "0b8d0f05832f55571d65ac720f79bf8994138ffbb133209dc4685eae0ad456a8";
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
          version = "1.11.0";
          drv = buildMix {
            inherit version;
            name = "mint";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mint";
              sha256 = "c6279ba2d6aa3a383a1d4cfbe7b59f42e6efd400f58d8e2acfeac48a438693ab";
            };

            beamDeps = [
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
          version = "1.8.15";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "7b83ed6b3d544f24a29277eab7f051be38b76f390bb511bb6ddb7ec6e8e05b95";
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
          version = "0.9.1";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_dashboard";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_dashboard";
              sha256 = "de25e1a28cfb64413d8bdaf3ba5b64da1a19e0ed44a02320119523cc45da051d";
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
          version = "1.2.12";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "656810d716e3369545dd63981196a5d68b77fdb253afe02ef0c6fa14cfd8dc2b";
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
          version = "2.4.1";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "352fba7a87bf61395b6e97da66944ad9b1bfe5459e5981039f60d68270bd9700";
            };
          };
        in
        drv;

      phoenix_template =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_template";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_template";
              sha256 = "eba70070de79b2c3501ef205a74a69f98ab352f3785aa15da9ed161f9fe0fd5d";
            };

            beamDeps = [
              phoenix_html
            ];
          };
        in
        drv;

      plug =
        let
          version = "1.20.3";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76";
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
          version = "2.2.0";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "83a95744ab1c75876542b6fab135fcc176280e0f301a111c1f757fddcec95d2c";
            };
          };
        in
        drv;

      req =
        let
          version = "0.7.5";
          drv = buildMix {
            inherit version;
            name = "req";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "req";
              sha256 = "576853c4bf403faa3c1fa5d093e0759227083b78f8a6864c67d62c0a9c45514d";
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
          version = "0.5.1";
          drv = buildMix {
            inherit version;
            name = "tailwind";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tailwind";
              sha256 = "c4e26302a59fec72abc5610ecb6ad2116d9aa31f31aab2d4b8eb6e95d25a689c";
            };
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
          version = "1.2.0";
          drv = buildMix {
            inherit version;
            name = "telemetry_metrics";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "telemetry_metrics";
              sha256 = "71dde12fc29b58b9c77ec17ec319109e5ca848d010fc1965ed4463bba1837c07";
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
          version = "1.22.0";
          drv = buildMix {
            inherit version;
            name = "tesla";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tesla";
              sha256 = "35330827f5b804073eda9792d4476b2834315c5e373e79c32d1e5ef08e607c50";
            };

            beamDeps = [
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
          version = "1.6.0";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "4d4720470f091fc21a1311777c2ac66916c43621bffc068590c9f9bb3cd057a3";
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
          version = "0.6.0";
          drv = buildMix {
            inherit version;
            name = "websock_adapter";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock_adapter";
              sha256 = "50021a85bce8f203b086705d9e0c5415e2c7eb05d319111b0428fe71f9934617";
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
