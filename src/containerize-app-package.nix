{
  pkgs ? import <nixpkgs> { },
  pkgsLinux64 ? import <nixpkgs> { system = "x86_64-linux"; },

  # These variables are set on the command line
  ourBinary,
  ourImageName,
  ourImageVersion,
}:
let
  # The derivation defined in the other file. We could inline the configuration into this file (yay for Nix being a
  # pure functional language), but to lower the cognitive complexity we'll just import it from the other file.
  derivationWithApplication = import ./fake-app-package.nix {
    inherit ourBinary;
  };
in
# Docs: https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildImage
pkgs.dockerTools.buildImage {
  # The resulting image will contain the tag/version, which is controllable through this attribute.
  name = ourImageName;

  # The resulting image will contain the tag/version, which is controllable through this attribute. If we did not
  # set it explicitly like we do in the next line, Nix would set it to the hash of the derivation -- this is fine
  # on its own, but the scripting in this repo is significantly simpler if we just set it to a pre-defined value.
  tag = ourImageVersion;

  # Run the container under given uid/gid, to comply with the best practice not to run processes in the container
  # namespace as the fake root user. The specific values do not matter very much - these are far enough from the
  # default user (usually 1000/1000) to avoid issues.
  uid = 2137;
  gid = 2137;

  # The derivation we want to put into the container
  copyToRoot = [
    # Include our derivation in the container image, the star of the show, including all of its dependencies
    derivationWithApplication

    # Include additional packages in the image. You can pick your own - these are just to improve the user experience
    # in case somebody wanted to shell into the container:
    pkgsLinux64.bash
    pkgsLinux64.coreutils-full
  ];

  # Commands to run when building the image. These are mostly up to the specific application. In this case we're just
  # being petty and creating a specific directory (/app/) symlinks to our application.
  runAsRoot = ''
    mkdir -p  /app
    ln -s  ${derivationWithApplication}/bin/${ourBinary}  /app/${ourBinary}
  '';

  # Default runtime configuration embedded in the container
  config = {
    WorkingDir = "/app";
    Cmd = [ "/app/${ourBinary}" ];
  };
}
