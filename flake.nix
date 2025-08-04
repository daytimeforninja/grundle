{
  description = "grundle - Convert GTD markdown todos to CalDAV VTODO format";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-gleam.url = "github:arnarg/nix-gleam";
  };

  outputs = { self, nixpkgs, flake-utils, nix-gleam }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-gleam.overlays.default ];
        };
      in
      {
        packages = {
          default = pkgs.buildGleamApplication {
            src = ./.;
            # pname and version automatically read from gleam.toml
            # target = "erlang"; # default
            
            meta = with pkgs.lib; {
              description = "Convert GTD-style markdown todos to CalDAV-compatible VTODO format";
              homepage = "https://github.com/your-username/grundle";
              license = licenses.mit;
              maintainers = [ /* your maintainer info */ ];
              platforms = platforms.unix;
            };
          };
          grundle = self.packages.${system}.default;
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
          program = "${self.packages.${system}.default}/bin/grundle";
        };
      });
}