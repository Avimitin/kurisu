{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    python3
    # Download stuff
    git
    curl
  ];

  programs.vim.enable = true;

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
