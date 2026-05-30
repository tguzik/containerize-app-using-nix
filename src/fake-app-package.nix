{
  pkgs ? import <nixpkgs> { },

  # Parameter with the name of the executable with our fake application. This parameter is set in the command line
  # call, but we're defaulting it anyway for the sake of the example.
  ourBinary ? "app.bin",

  ...
}:
pkgs.stdenvNoCC.mkDerivation rec {
  # Note that we're using stdenvNoCC - one of the assumptions for this recipe is that the application binary has
  # already been built.

  # Define the name and the version - these are required. Since the assumption is that neither the application nor
  # the resulting derivation will ever be uploaded anywhere you can put whatever here
  name = "fake-app";
  version = "1.0-fake";

  # Use current directory as the source
  src = ./.;

  # Skip the build phase since one of the assumptions is that the application is not using Nix to produce the binary.
  dontBuild = true;

  nativeBuildInputs = with pkgs; [
    # https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook
    # This hook will modify the target binary.
    autoPatchelfHook
  ];

  # Define runtime dependencies, including the runtime library path
  runtimeDependencies = with pkgs; [
    glibc # Reminder that glibc does not support being linked statically
    libaio # The dynamically loaded library our application uses
  ];

  # Move the binary into the Nix store output directory
  installPhase = ''
    mkdir -p  $out/bin
    cp  ${ourBinary}  $out/bin/
    chmod +x  $out/bin/${ourBinary}
  '';
}
