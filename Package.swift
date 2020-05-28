// swift-tools-version:5.2

///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import PackageDescription

let package = Package(
    name: "SwiftyDropbox",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "SwiftyDropbox",
            targets: ["SwiftyDropbox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.0.0")),
    ],
    
    targets: [
        .target(
            name: "SwiftyDropbox-ObjC",
            dependencies: [],
            path: "Source/SwiftyDropbox-ObjC"
        ),
        .target(
            name: "SwiftyDropbox",
            dependencies: ["SwiftyDropbox-ObjC", "Alamofire"],
            path: "Source/SwiftyDropbox"
        )
    ]
)
