# Development shell for grundle
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    gleam
    erlang
    git
    
    # Optional development tools
    vscode
    gitAndTools.gh  # GitHub CLI
  ];
  
  shellHook = ''
    echo "🫛 grundle development environment"
    echo ""
    echo "Available commands:"
    echo "  gleam run -- --help    # Test CLI"
    echo "  gleam check            # Type check"
    echo "  gleam test             # Run tests"
    echo "  gleam build            # Build project"
    echo ""
    echo "Git workflow:"
    echo "  git add ."
    echo "  git commit -m 'message'"
    echo "  git push"
  '';
}