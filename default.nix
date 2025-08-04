# Legacy Nix expression for grundle
{ lib, stdenv, gleam, erlang }:

stdenv.mkDerivation rec {
  pname = "grundle";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ gleam erlang ];

  buildPhase = ''
    gleam build
    gleam export erlang-shipment
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r build/erlang-shipment $out/lib/grundle
    
    # Create wrapper script (same as Makefile approach)
    cat > $out/bin/grundle << EOF
#!/usr/bin/env bash
GRUNDLE_LIB="$out/lib/grundle"
exec ${erlang}/bin/erl -noshell -pa "\$GRUNDLE_LIB"/*/ebin -s grundle main -s init stop -- "\$@"
EOF
    chmod +x $out/bin/grundle
  '';

  meta = with lib; {
    description = "Convert GTD-style markdown todos to CalDAV-compatible VTODO format";
    homepage = "https://github.com/your-username/grundle";
    license = licenses.mit;
    maintainers = [ /* your maintainer info */ ];
    platforms = platforms.unix;
  };
}