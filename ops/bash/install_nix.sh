#!/usr/bin/env bash


#sh <(curl -L https://nixos.org/nix/install) --no-daemon --yes
# RUN BASE_URL='https://raw.githubusercontent.com/ES-Nix/get-nix/' \
# 	&& SHA256=5443257f9e3ac31c5f0da60332d7c5bebfab1cdf \
# 	&& NIX_RELEASE_VERSION='2.10.2' \
# 	&& curl -fsSL "${BASE_URL}""$SHA256"/get-nix.sh | sh -s -- ${NIX_RELEASE_VERSION} \
# 	&& . "$HOME"/.nix-profile/etc/profile.d/nix.sh \
# 	&& . ~/."$(ps -ocomm= -q $$)"rc \
# 	&& export TMPDIR=/tmp \
# 	&& nix flake --version
# 	echo "$HOME"/.nix-profile/bin >> $GITHUB_PATH
