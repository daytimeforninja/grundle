{
  description = "grundle - Convert GTD markdown todos to CalDAV VTODO format";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        grundle = pkgs.stdenv.mkDerivation rec {
          pname = "grundle";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            gleam
            erlang
          ];

          buildPhase = ''
            gleam export erlang-shipment
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp -r build/erlang-shipment $out/lib/grundle
            
            # Create wrapper script
            cat > $out/bin/grundle << 'EOF'
#!/bin/bash
exec ${pkgs.erlang}/bin/erl -noshell -pa $out/lib/grundle/*/ebin -s grundle main -s init stop -- "$@"
EOF
            chmod +x $out/bin/grundle
          '';

          meta = with pkgs.lib; {
            description = "Convert GTD-style markdown todos to CalDAV-compatible VTODO format";
            homepage = "https://github.com/your-username/grundle";
            license = licenses.mit;
            maintainers = [ /* your maintainer info */ ];
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = grundle;
          grundle = grundle;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gleam
            erlang
            git
          ];
          
          shellHook = ''
            echo "🫛 grundle development environment"
            echo "Available commands:"
            echo "  gleam run -- --help"
            echo "  gleam check"
            echo "  gleam test"
          '';
        };

        apps.default = {
          type = "app";
          program = "${grundle}/bin/grundle";
        };
      });
}