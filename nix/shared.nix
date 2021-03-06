{ compiler ? "ghc843", coverage ? false }:

let
  fetchNixpkgs = import ./fetchNixpkgs.nix;

  overlayShared = pkgsNew: pkgsOld: {
    dhall-sdist =
      let
        predicate = path: type:
          let
            base = baseNameOf path;

          in
             !( pkgsNew.lib.hasSuffix ".nix" base
             || base == "dist"
             || base == "result"
             || base == ".git"
             );

        src = builtins.filterSource predicate ../dhall;

      in
        pkgsNew.callPackage (import ./dhall-sdist.nix src) { };

    haskell = pkgsOld.haskell // {
      packages = pkgsOld.haskell.packages // {
        "${compiler}" = pkgsOld.haskell.packages."${compiler}".override (old: {
            overrides =
              let
                applyCoverage = drv:
                  if coverage
                  then
                    pkgsNew.haskell.lib.overrideCabal
                      (pkgsNew.haskell.lib.doCoverage
                        (pkgsNew.haskell.lib.doCheck drv)
                      )
                      (old: {
                          postInstall = (old.postInstall or "") + ''
                            ${pkgsNew.coreutils}/bin/mkdir --parents $out/nix-support
                            ${pkgsNew.coreutils}/bin/ln --symbolic $out/share/hpc/vanilla/html/dhall-* "$out/share/hpc/vanilla/html/dhall"
                            ${pkgsNew.coreutils}/bin/echo "report coverage $out/share/hpc/vanilla/html/dhall/hpc_index.html" >> $out/nix-support/hydra-build-products
                          '';
                        }
                      )
                  else
                    pkgsNew.haskell.lib.dontCheck drv;

                failOnAllWarnings = drv:
                  # GHC 7.10.3 incorrectly detects non-exhaustive pattern
                  # matches
                  if compiler == "ghc7103"
                  then drv
                  else pkgsNew.haskell.lib.failOnAllWarnings drv;

                extension =
                  haskellPackagesNew: haskellPackagesOld: {
                    aeson =
                      pkgsNew.haskell.lib.dontCheck haskellPackagesOld.aeson;

                    comonad =
                      pkgsNew.haskell.lib.dontCheck haskellPackagesOld.comonad;

                    dhall =
                      applyCoverage
                        (failOnAllWarnings
                          (haskellPackagesNew.callCabal2nix
                            "dhall"
                            pkgsNew.dhall-sdist
                            { }
                          )
                        );

                    dhall-bash =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "dhall-bash"
                          ../dhall-bash
                          { }
                        );

                    dhall-json =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "dhall-json"
                          ../dhall-json
                          { }
                        );

                    dhall-text =
                      failOnAllWarnings
                        (haskellPackagesNew.callCabal2nix
                          "dhall-text"
                          ../dhall-text
                          { }
                        );

                    distributive =
                      pkgsNew.haskell.lib.dontCheck haskellPackagesOld.distributive;

                    doctest =
                      pkgsNew.haskell.lib.dontCheck haskellPackagesOld.doctest;

                    # https://github.com/well-typed/cborg/issues/172
                    serialise =
                      pkgsNew.haskell.lib.dontCheck
                        haskellPackagesOld.serialise;

                    prettyprinter =
                      pkgsNew.haskell.lib.dontCheck
                        haskellPackagesOld.prettyprinter;

                    unordered-containers =
                      pkgsNew.haskell.lib.dontCheck
                        haskellPackagesOld.unordered-containers;
                  };

              in
                pkgsNew.lib.fold
                  pkgsNew.lib.composeExtensions
                  (old.overrides or (_: _: {}))
                  [ (pkgsNew.haskell.lib.packagesFromDirectory { directory = ./.; })

                    extension
                  ];
          }
        );
      };
    };
  };

  overlayCabal2nix = pkgsNew: pkgsOld: {
    haskellPackages = pkgsOld.haskellPackages.override (old: {
        overrides =
          let
            extension =
              haskellPackagesNew: haskellPackagesOld: {
                # `cabal2nix` requires a newer version of `hpack`
                hpack =
                  haskellPackagesOld.hpack_0_29_6;
              };

          in
            pkgsNew.lib.composeExtensions
              (old.overrides or (_: _: {}))
              extension;
      }
    );
  };

  overlayGHC7103 = pkgsNew: pkgsOld: {
    haskell = pkgsOld.haskell // {
      packages = pkgsOld.haskell.packages // {
        "${compiler}" = pkgsOld.haskell.packages."${compiler}".override (old: {
            overrides =
              let
                extension =
                  haskellPackagesNew: haskellPackagesOld: {
                    # Newer version of these packages have bounds incompatible
                    # with GHC 7.10.3
                    lens-family-core =
                      haskellPackagesOld.lens-family-core_1_2_1;

                    memory =
                      haskellPackagesOld.memory_0_14_16;

                    basement =
                      haskellPackagesOld.basement_0_0_6;

                    foundation =
                      haskellPackagesOld.foundation_0_0_19;

                    # Most of these fixes are due to certain dependencies being
                    # hidden behind a conditional compiler version directive, so
                    # they aren't included by default in the default Hackage
                    # package set (which was generated for `ghc-8.4.3`)
                    base-compat-batteries =
                      pkgsNew.haskell.lib.addBuildDepends
                        haskellPackagesOld.base-compat-batteries
                        [ haskellPackagesNew.bifunctors
                          haskellPackagesNew.fail
                        ];

                    cborg =
                      pkgsNew.haskell.lib.addBuildDepends
                        haskellPackagesOld.cborg
                        [ haskellPackagesNew.fail
                          haskellPackagesNew.semigroups
                        ];

                    contravariant =
                      pkgsNew.haskell.lib.addBuildDepends
                        haskellPackagesOld.contravariant
                        [ haskellPackagesNew.fail
                          haskellPackagesNew.semigroups
                        ];

                    dhall =
                      pkgsNew.haskell.lib.addBuildDepends
                        haskellPackagesOld.dhall
                        [ haskellPackagesNew.doctest
                          haskellPackagesNew.mockery
                        ];

                    megaparsec =
                      pkgsNew.haskell.lib.addBuildDepend
                        haskellPackagesOld.megaparsec
                        haskellPackagesNew.fail;

                    generic-deriving =
                      pkgsNew.haskell.lib.dontCheck
                        haskellPackagesOld.generic-deriving;

                    prettyprinter =
                      pkgsNew.haskell.lib.addBuildDepend
                        haskellPackagesOld.prettyprinter
                        haskellPackagesNew.semigroups;

                    transformers-compat =
                      pkgsNew.haskell.lib.addBuildDepend
                        haskellPackagesOld.transformers-compat
                        haskellPackagesNew.generic-deriving;

                    # For some reason, `Cabal-1.22.5` does not respect the
                    # `buildable: False` directive for the executable section
                    # even when configured with `-f -cli`.  Fixing this requires
                    # patching out the executable section of `wcwidth` in order
                    # to avoid pulling in some extra dependencies which cause a
                    # a dependency cycle.
                    wcwidth =
                      pkgsNew.haskell.lib.appendPatch
                        haskellPackagesOld.wcwidth ./wcwidth.patch;
                  };

              in
                pkgsNew.lib.composeExtensions
                  (old.overrides or (_: _: {}))
                  extension;
          }
        );
      };
    };
  };

  nixpkgs = fetchNixpkgs {
    rev = "1d4de0d552ae9aa66a5b8dee5fb0650a4372d148";

    sha256 = "09qx58dp1kbj7cpzp8ahbqfbbab1frb12sh1qng87rybcaz0dz01";

    outputSha256 = "0xpqc1fhkvvv5dv1zmas2j1q27mi7j7dgyjcdh82mlgl1q63i660";
  };

  pkgs = import nixpkgs {
    config = {};
    overlays =
          [ overlayShared overlayCabal2nix ]
      ++  (if compiler == "ghc7103" then [ overlayGHC7103 ] else []);
  };

  overlayStaticLinux = pkgsNew: pkgsOld: {
    cabal_patched_src = pkgsNew.fetchFromGitHub {
      owner = "nh2";
      repo = "cabal";
      rev = "748f07b50724f2618798d200894f387020afc300";
      sha256 = "1k559m291f6spip50rly5z9rbxhfgzxvaz64cx4jqpxgfhbh2gfs";
    };

    Cabal_patched_Cabal_subdir = pkgsNew.stdenv.mkDerivation {
      name = "cabal-dedupe-src";
      buildCommand = ''
        cp -rv ${pkgsNew.cabal_patched_src}/Cabal/ $out
      '';
    };

    haskell = pkgsOld.haskell // {
      lib = pkgsOld.haskell.lib // {
        useFixedCabal = drv: pkgsNew.haskell.lib.overrideCabal drv (old: {
            setupHaskellDepends =
              (old.setupHaskellDepends or []) ++ [
                pkgsNew.haskell.packages."${compiler}".Cabal_patched
              ];

            libraryHaskellDepends =
              (old.libraryHaskellDepends or []) ++ [
                pkgsNew.haskell.packages."${compiler}".Cabal_patched
              ];
          }
        );

      statify = drv:
        pkgsNew.lib.foldl pkgsNew.haskell.lib.appendConfigureFlag
          (pkgsNew.haskell.lib.disableLibraryProfiling
            (pkgsNew.haskell.lib.disableSharedExecutables
              (pkgsNew.haskell.lib.useFixedCabal
                 (pkgsNew.haskell.lib.justStaticExecutables drv)
              )
            )
          )
          [ "--enable-executable-static"
            "--extra-lib-dirs=${pkgsNew.gmp6.override { withStatic = true; }}/lib"
            "--extra-lib-dirs=${pkgsNew.zlib.static}/lib"
            "--extra-lib-dirs=${pkgsNew.ncurses.override { enableStatic = true; }}/lib"
          ];
      };

      packages = pkgsOld.haskell.packages // {
        "${compiler}" = pkgsOld.haskell.packages."${compiler}".override (old: {
            overrides =
              let
                extension =
                  haskellPackagesNew: haskellPackagesOld: {
                    Cabal_patched =
                      haskellPackagesNew.callCabal2nix
                        "Cabal"
                        pkgsNew.Cabal_patched_Cabal_subdir
                        { };

                    dhall-static =
                        pkgsNew.haskell.lib.statify haskellPackagesOld.dhall;

                    dhall-bash-static =
                        pkgsNew.haskell.lib.statify haskellPackagesOld.dhall-bash;

                    dhall-json-static =
                        pkgsNew.haskell.lib.statify haskellPackagesOld.dhall-json;

                    dhall-text-static =
                        pkgsNew.haskell.lib.statify haskellPackagesOld.dhall-text;
                  };

              in
                pkgsNew.lib.composeExtensions
                  (old.overrides or (_: _: {}))
                  extension;
          }
        );
      };
    };
  };

  nixpkgsStaticLinux = fetchNixpkgs {
    owner = "nh2";

    rev = "925aac04f4ca58aceb83beef18cb7dae0715421b";

    sha256 = "0zkvqzzyf5c742zcl1sqc8009dr6fr1fblz53v8gfl63hzqwj0x4";

    outputSha256 = "1zr8lscjl2a5cz61f0ibyx55a94v8yyp6sjzjl2gkqjrjbg99abx";
  };

  pkgsStaticLinux = import nixpkgsStaticLinux {
    config = {};
    overlays = [ overlayShared overlayStaticLinux ];
    system = "x86_64-linux";
  };

  # Derivation that trivially depends on the current directory so that Hydra's
  # pull request builder always posts a GitHub status on each revision
  pwd = pkgs.runCommand "pwd" { here = ../.; } "touch $out";

  makeTarball = name:
    pkgsStaticLinux.releaseTools.binaryTarball rec {
      src = pkgsStaticLinux.pkgsMusl.haskell.packages."${compiler}"."${name}-static";

      installPhase = ''
        releaseName=${name}
        ${pkgsStaticLinux.coreutils}/bin/install --target-directory "$TMPDIR/inst/bin" -D $src/bin/*
      '';
    };

in
  rec {
    inherit pwd;

    tarball-dhall = makeTarball "dhall";

    tarball-dhall-bash = makeTarball "dhall-bash";

    tarball-dhall-json = makeTarball "dhall-json";

    tarball-dhall-text = makeTarball "dhall-text";

    inherit (pkgs.haskell.packages."${compiler}") dhall dhall-bash dhall-json dhall-text;

    inherit (pkgs.releaseTools) aggregate;

    shell-dhall = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".dhall).env;

    shell-dhall-bash = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".dhall-bash).env;

    shell-dhall-json = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".dhall-json).env;

    shell-dhall-text = (pkgs.haskell.lib.doBenchmark pkgs.haskell.packages."${compiler}".dhall-text).env;

    test-dhall =
      pkgs.mkShell
        { buildInputs =
            [ (pkgs.haskell.packages."${compiler}".ghcWithPackages
                (pkgs: [ pkgs.dhall ])
              )
            ];
        };
  }
