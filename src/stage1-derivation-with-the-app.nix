{
  # Use system nixpkgs version as the starting point. If you want, you could force pin it to a single commit using
  # spell like:
  #
  # let
  #   pkgs = fetchTarball {
  #     url = "https://github.com/NixOS/nixpkgs/archive/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee.tar.gz";
  #     hash = "sha256-00000000000000000000000000000000000000000000";
  #   };
  # in
  #
  # ...but that shouldn't be required in this example.
  pkgs ? import <nixpkgs> { },

  # These variables are set on the command line
  appVersion,
  appBinary,
  appConfigFile,
}:
let
  inherit (pkgs) lib; # read it as "alias `pkgs.lib` to `lib`"
in
pkgs.stdenvNoCC.mkDerivation rec {
  # Note that we're using stdenvNoCC - one of the assumptions for this recipe is that the application binary has
  # already been built.

  # Define the name and the version - these are required. Since the assumption is that neither the application nor
  # the resulting derivation will ever be uploaded anywhere you can put whatever here
  name = "fake-app";
  version = appVersion;

  # Use the ./build/ directory as the source
  src = ./build;

  nativeBuildInputs = with pkgs; [
    # https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook
    # https://wiki.nixos.org/wiki/Packaging/Binaries
    # This hook will modify the target binary, changing its hashes (if you care about these).
    autoPatchelfHook

    # Script that creates a wrapper script for the actual binary
    # See: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
    makeWrapper
  ];

  # Define runtime dependencies that autoPatchelfHook will unconditionally include in the rpath, without us having to
  # invoke it manually
  runtimeDependencies = with pkgs; [
    glibc # Reminder that glibc does not support being linked statically
    libaio # The dynamically loaded library our application uses
  ];

  # Skip the build phase since one of the assumptions is that the application is not using Nix to produce the binary.
  # The autoPatchelfHook will update the rpath within the binary.
  dontBuild = true;

  # Copy the files into the derivation build output directory, and then run various hooks. If the app did not read the
  # config file we could just chuck the binary into `$out/bin/` and call it a day.
  # Docs: https://nixos.org/manual/nixpkgs/stable/#ssec-install-phase
  #
  # NOTE: Our fake application basically does `fopen("config-file.conf", "r")`, i.e. it requires the configuration
  # file to be in the current working directory. This derivation is also creating a wrapper script that will reset
  # the working directory to the one in /nix/store, but the wrapper script is technically optional.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,libexec}/

    # Copy the files into derivation output. As noted above, this phase could boil down to just these commands if we
    # did not burden ourselves with that requirement to have config file in the same working directory as the app.
    cp  "${appBinary}"      $out/libexec/
    cp  "${appConfigFile}"  $out/libexec/
    chmod +x  "$out/libexec/${appBinary}"

    # Create the (optional-) wrapper script to make sure its working directory is set to the
    # read-only `/nix/store/$something/libexec/` to let the app naively fopen() its placeholder configuration file.
    #
    # NOTE: The "-wrapper" suffix is there just to help distinguish the two - it is not required.
    makeWrapper  "$out/libexec/${appBinary}"  "$out/bin/${appBinary}-wrapper"  --chdir $out/libexec/

    runHook postInstall
  '';

  meta = {
    # Point it to the main binary within the $out/bin/ directory in case somebody wanted to do  [$] nix run [..]
    # This is not necessary for the derivation to function, but it may help out a bit.
    # Docs: https://nixos.org/manual/nixpkgs/stable/#var-meta-mainProgram
    mainProgram = "${appBinary}-wrapper";

    # Mark that the binary was built outside of a Nix derivation. Not required to build the derivation.
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];

    # Mark the derivation as Unfree, and doing so will require the 'export NIXPKGS_ALLOW_UNFREE=1' environment
    # variable to be set to build the derivation. Setting the license is not necessary for the derivation to be
    # built, but since one of the assumptions of this example was that the application is non-public, we should
    # mark it so.
    # Docs: https://nixos.org/manual/nixpkgs/stable/#lib.licenses.unfree-unfree
    license = lib.licenses.unfree;
  };
}
