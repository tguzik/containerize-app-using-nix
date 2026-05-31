# Recipe: Containerize native app using tooling from nixpkgs

This repository contains an example on how to package a non-nixpkgs application into a container with following
complications:

* The application is not present in nixpkgs and never will be - simulates a private application,
* The application is compiled down to native code - simulated using a simple hello-world C application,
* The application compilation process is decoupled from Nix derivation,
* The application uses dynamically-loaded shared libraries from system that cannot be linked statically - for example
  due to licensing requirements,
* The result container, besides the app and its dependencies, must have basic shell.

I've encountered this problem several times when packaging propietary stuff, and I'm sure I'm not the only one, so
this repo contains a recipe how to do it.

## What's required

TBD

## How this works

TBD

## Compatibility with public GitHub Actions runners

This method is compatible with (runs under) public GitHub Actions runners, however there are some caveats:

* The [`pkgs.dockerTools.buildImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildImage) Nix
  function uses kvm device under the hood, which is not available on public GitHub Action runners:
  * Instead, this recipe uses the
    [`pkgs.dockerTools.buildLayeredImage`](https://nixos.org/manual/nixpkgs/stable/#ssec-pkgs-dockerTools-buildLayeredImage)
    function which does not have that requirement.
* Copies of the [`podman`](https://github.com/containers/podman) package obtained through Nix seem to be able to load
  the container image (`$ podman load`), but are blocked by runner's security profile from running any containers,
  even in rootless mode:
  * Considering the current security landscape around GitHub Actions security this is unfortunate, but understandable.
  * At the time of writing (2026-05-31) the `podman` binary shipped with the `ubuntu-latest` runner image does not have
    that limitation, so it is used in the CI workflow instead.

Using this recipe on self-hosted GitHub Actions runners is very likely to run into the same limitations as outlined
above, however with self-hosted runners you will have more tools in the toolbox to work around them.

## Running the workflow locally

This workflow can be ran locally within a [DevEnv](https://devenv.sh/) shell:

```shell
[$] devenv shell --profile local
[devenv$] task all
```

The `local` profile includes [`podman`](https://github.com/containers/podman) obtained through Nix. If your system
already has `podman` set up, you can skip that profile and use the default shell instead.

## License

This repository is available under MIT license. See the `LICENSE` file for details.
