// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_rar",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-rar", targets: ["flutter_rar"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_rar_unrar",
            path: "Sources/flutter_rar_unrar",
            exclude: [
                "unrar/arccmt.cpp",
                "unrar/blake2sp.cpp",
                "unrar/cmdfilter.cpp",
                "unrar/cmdmix.cpp",
                "unrar/coder.cpp",
                "unrar/crypt1.cpp",
                "unrar/crypt2.cpp",
                "unrar/crypt3.cpp",
                "unrar/crypt5.cpp",
                "unrar/hardlinks.cpp",
                "unrar/log.cpp",
                "unrar/model.cpp",
                "unrar/recvol3.cpp",
                "unrar/recvol5.cpp",
                "unrar/suballoc.cpp",
                "unrar/uicommon.cpp",
                "unrar/uisilent.cpp",
                "unrar/ulinks.cpp",
                "unrar/unpack15.cpp",
                "unrar/unpack20.cpp",
                "unrar/unpack30.cpp",
                "unrar/unpack50.cpp",
                "unrar/unpack50frag.cpp",
                "unrar/unpackinline.cpp",
                "unrar/uowners.cpp",
                "unrar/win32stm.cpp",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("unrar"),
                .define("RARDLL"),
                .define("SILENT"),
                .define("_FILE_OFFSET_BITS", to: "64"),
                .define("_LARGEFILE_SOURCE"),
                .unsafeFlags([
                    "-O2",
                    "-std=c++14",
                    "-fexceptions",
                    "-frtti",
                ]),
            ]
        ),
        .target(
            name: "flutter_rar",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "flutter_rar_unrar",
            ],
            path: "Sources/flutter_rar"
        ),
    ]
)
