{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    python3
    # editor
    vim
    # Download stuff
    git
    curl
  ];

  nix.settings = {
    # Simplify the Nix command line
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    auto-optimise-store = true;
  };
}
