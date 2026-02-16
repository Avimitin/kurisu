{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    # dufs is a simple http server for me to upload credential and secrets
    dufs
    # editor
    vim
    # Download stuff
    git
    curl
    aria2
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    # Simplify the Nix command line
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
