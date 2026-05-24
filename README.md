# Recipe: Package non-nixpkgs native app into a container using dependencies from nixpkgs

This repository contains an example on how to package a non-nixpkgs application into a container with following
complications:

* The application is not present in nixpkgs and never will be - simulates a private application,
* The application is compiled down to native code - simulated using a simple hello-world C application,
* The application compilation process is decoupled from Nix derivation,
* The application uses dynamically-loaded shared libraries from system that cannot be linked statically - for example
  due to licensing requirements,

I've encountered this problem several times when packaging propietary stuff, and I'm sure I'm not the only one, so
this repo contains a recipe how to do it.

## What's required

TBD

## How this works

TBD

## License

This repository is available under MIT license. See file `LICENSE`.
