{
  inputs,
  pkgs,
  self,
  config,
  ...
}:
{
  imports = [
    self.homeModules.tools

    inputs.nvim.homeModules.nvim
  ];

  config = {
    news.display = "silent";

    nixpkgs.config.allowUnfree = true;

    nix.package = pkgs.nix;
    # Simply run nix run k#hello to run temporary programs
    nix.registry.k.to = {
      type = "path";
      path = "${config.home.homeDirectory}/kurisu";
    };

    home = {
      username = "avimitin";
      homeDirectory = "/home/avimitin";
      stateVersion = "25.11";
    };

    kurisu = {
      hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
      };
    };

    programs.avimitin-nvim = {
      enable = true;
      treesitter-grammars = [
        # builtins
        "bash"
        "cpp"
        "css"
        "comment"
        "diff"
        "gitcommit"
        "typst"
        "llvm"
        "regex"
        "ruby"
        "python"
        "rust"
        "scala"
        "nix"
        "yaml"
        "meson"

        pkgs.tree-sitter-grammars.tree-sitter-lean
      ];
    };
  };
}
