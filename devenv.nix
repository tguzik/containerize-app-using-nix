# Definition of the DevEnv shell
# This shell is here just to ensure the tooling is present at expected versions, DevEnv itself is not required to
# do the thing.
{ pkgs, ... }:
{
  # See full reference at https://devenv.sh/reference/options/

  # https://devenv.sh/languages/
  languages = {
    nix = {
      enable = true;
      lsp.package = pkgs.nixd;
    };
  };

  # https://devenv.sh/packages/
  # https://search.nixos.org/packages
  packages = with pkgs; [
    git
    go-task
    gnupg

    # Tooling for the recipe itself
    podman # https://podman.io/ # Program for managing pods, containers and container images

    # Tooling to for the compilation of the simulated native application
    gcc # https://gcc.gnu.org/ # GNU Compiler Collection

    # Simulated dynamically-loaded library
    libaio # LGPL # https://lse.sourceforge.net/io/aio.html # Library for asynchronous I/O in Linux
  ];

  git-hooks.hooks = {
    # Basics
    gitlint.enable = true;
    no-commit-to-branch.enable = false;
    trufflehog.enable = true;

    # Keep nix files nice and tidy
    deadnix.enable = true;
    nixfmt.enable = true;
    shellcheck.enable = true;
    statix.enable = true;

    # Keep Github Actions nice and tidy
    actionlint.enable = true;
    zizmor.enable = true;

    # Additional formatters
    clang-format.enable = true;
    markdownlint = {
      enable = true;
      settings.configuration = {
        MD013 = {
          line_length = 120;
        };
        MD033 = false;
        MD034 = false;
      };
    };
    yamllint = {
      enable = true;
      settings.configuration = ''
        extends: relaxed
        rules:
          line-length:
            max: 180
      '';
    };
  };

  enterShell = ''
    export LD_LIBRARY_PATH="${pkgs.libaio}/lib/;$LD_LIBRARY_PATH"
    echo "Setting LD_LIBRARY_PATH to '$LD_LIBRARY_PATH'"
  '';

  enterTest = ''
    # Do nothing
  '';
}
