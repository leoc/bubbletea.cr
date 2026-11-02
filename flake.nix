{
  description = "Crystal bindings for Bubble Tea, Lip Gloss, Bubbles and Glamour";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      version = "0.1.0";
    in
    {
      packages = forAll (pkgs: rec {
        # The Go c-shared library: lib/libbubbletea_go.so + include/libbubbletea_go.h
        libbubbletea-go = pkgs.buildGoModule {
          pname = "libbubbletea-go";
          inherit version;
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.fileFilter (f: !(f.hasExt "so" || f.hasExt "h")) ./go;
          };
          modRoot = "go";
          vendorHash = "sha256-i24NrEuuO3GQ1JlFys35IgByAiwgqbXbzt2ddpAVv74=";
          env.CGO_ENABLED = "1";
          buildPhase = ''
            runHook preBuild
            go build -buildmode=c-shared -trimpath \
              -ldflags "-s -w -extldflags -Wl,-soname,libbubbletea_go.so" \
              -o libbubbletea_go.so .
            runHook postBuild
          '';
          doCheck = false;
          installPhase = ''
            runHook preInstall
            install -Dm755 libbubbletea_go.so -t $out/lib
            install -Dm644 libbubbletea_go.h -t $out/include
            runHook postInstall
          '';
          meta = {
            description = "Bubble Tea, Lip Gloss, Bubbles and Glamour as a C shared library";
            license = pkgs.lib.licenses.mit;
          };
        };
        default = libbubbletea-go;
      });

      checks = forAll (
        pkgs:
        let
          lib = self.packages.${pkgs.stdenv.hostPlatform.system}.libbubbletea-go;
          crystalCheck =
            name: script:
            pkgs.stdenv.mkDerivation {
              name = "bubbletea-cr-${name}";
              src = pkgs.lib.cleanSource ./.;
              nativeBuildInputs = [ pkgs.crystal ];
              BUBBLETEA_LIB_DIR = "${lib}/lib";
              dontConfigure = true;
              buildPhase = ''
                runHook preBuild
                export HOME=$TMPDIR CRYSTAL_CACHE_DIR=$TMPDIR/crystal-cache
                ${script}
                runHook postBuild
              '';
              installPhase = "touch $out";
            };
        in
        {
          inherit lib;
          specs = crystalCheck "specs" "crystal spec --order random";
          examples = crystalCheck "examples" ''
            mkdir -p bin
            for f in examples/*.cr; do
              echo "build $f"
              crystal build --no-codegen "$f"
            done
          '';
          format = crystalCheck "format" "crystal tool format --check src spec examples";
        }
      );

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.go
            pkgs.gopls
            pkgs.crystal
            pkgs.shards
            pkgs.gnumake
          ];
          shellHook = ''
            echo "bubbletea.cr: 'make lib' builds go/build/libbubbletea_go.so, 'make spec' runs the specs"
          '';
        };
      });

      formatter = forAll (pkgs: pkgs.nixfmt);
    };
}
