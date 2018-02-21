# pixivwall

Bring your moe to your desktop! This Windows app automatically downloads and sets wallpapers from today's pixiv ranking.

**Currently only Windows is supported.**

## Prerequisites

* Node.js
* GNU make (cygwin works well)
* [windows-build-tools](https://github.com/felixrieseberg/windows-build-tools)
* imagemagick
* waifu2x

## Install

```sh
cd path\to\pixivwall
npm install
"%ProgramFiles(x86)%\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"
make
mkdir log images
cd battery-status
npm install
cd ..
npm start
# TODO: write
```
