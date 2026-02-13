os:
  @nix run '.#colmena' -- apply-local --sudo

clean args="7d":
  @sudo nix profile wipe-history --older-than {{args}} --profile /nix/var/nix/profiles/system
  @sudo nix-collect-garbage --delete-old
  @nix-collect-garbage --delete-old
