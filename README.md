# ohos-git

This project will build Git for the OpenHarmony platform and release prebuilt packages.

## Get prebuilt packages
Go to the [release page](https://github.com/Harmonybrew/ohos-git/releases).

## Build from source
Run the build.sh script on a Linux x64 server to cross-compile Git for OpenHarmony (e.g., on Ubuntu 24.04 x64).
```sh
sudo apt update && sudo apt install -y build-essential autoconf gettext file unzip jq
./build.sh
```
