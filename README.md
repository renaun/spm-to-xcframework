# spm-to-xcframework

## What's it?
This little tool creates xcframework from library targets inside SPM packages. Only supports .library(type: .dynamic) targets at the moment.

## Install
Just pull the package and build from the source with this command: `swift build -c release`. Then you will find it in `.build/release` folder. You can download a version from releases page too.

## How to use?

To create xcframework for a package run

```
spm-to-xcframework ~/MySPMRoot
```

```
USAGE: spm-to-xcframework [<path>] [--libraries <libraries>] [--frameworks <frameworks>] [--output <output>] [--list] [--platforms <platforms>] [--verbose] [--disable-library-evolution] [--objc] [--clean] [--keep-build-products]

ARGUMENTS:
  <path>                  The path to the Package.swift file (default: ./)

OPTIONS:
  -l, --libraries <libraries>
                          (Optional) Specific libraries to package. Default is to build all of them with -scheme <PackageName>-Package 
  -f, --frameworks <frameworks>
                          Paths to folders with linked frameworks the package expects to find during building. (default: [])
  -o, --output <output>   The output directory defaults to ./xcframework inside the path folder. 
  --list                  Just list package name and possible library targets to build 
  --platforms <platforms> Defaults to both .ios, and .simulator, other platforms not support yet. (default: [spm_to_xcframework.Platform(name: "ios", destination: "-destination generic/platform=iOS", sdk:
                          "iphoneos", buildFolder: "Release-iphoneos"), spm_to_xcframework.Platform(name: "simulator", destination: "-destination \'generic/platform=iOS Simulator\'", sdk: "iphonesimulator",
                          buildFolder: "Release-iphonesimulator")])
  -v, --verbose
  --disable-library-evolution
                          Sets BUILD_LIBRARY_FOR_DISTRIBUTION to NO, typically you want this YES for any dynamic libraries to use in iOS applications. Defaults to YES. 
  --objc                  Include to generate xcframework with ObjC compability modulemap and -Swift.h files. 
  --clean
  --keep-build-products
  -h, --help              Show help information.
```

## Limitations
For now only the packages that has swift code supported. Binary packages and objective-c packages are not supported.


