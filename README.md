# What is sivablue?

Good question... sivablue is a smaller and more simple version of Bluefin OS which aims to just give me the tools I need to do a pentest within the best part of an hour. If you have internet, you can be up and running in an hour or so.

This is still in early ish development, but I'd consider it moving out of beta at this point.

I'd suggest trying this on a VM first to get a feel for things, but the goal is to be a daily driver. 

## Documentation:

Full documentation is a work in progress. It's relatively simple however since the image is pre-configured for you. Documentation will mainly cover how to make the most out of your image. Distrobox, Distroshelf, and Podman Desktop are massive hacks if you don't know your CLI tooling that well.

I recommend reading the welcome message and running those commands to get setup.

## Download and Install:

| Image Flavour | Download | Checksum |
|---------------|----------|----------|
| Standard |[Download](https://download.sivablue.uk/sivablue-stable-x86_64.iso)|[Checksum](https://download.sivablue.uk/sivablue-stable-x86_64.iso-CHECKSUM)|
| Nvidia |[Download](https://download.sivablue.uk/sivablue-nvidia-stable-x86_64.iso)|[Checksum](https://download.sivablue.uk/sivablue-nvidia-stable-x86_64.iso-CHECKSUM)|

Simply follow the live install instructions, restart, and you should be good to go. The ISO build will install most of the flatpaks, but some are not installed. These will be installed in the background so please be patient in waiting for them to install.

If you don't want to use the live ISOs and want to use a non-live anaconda iso, then close the [ISO repository](https://github.com/Sir-Mudkip/Sivablue-iso) and run `./hack/non-live-iso-build.sh` and pass "nvidia" if you want to build the nvidia flavour.
