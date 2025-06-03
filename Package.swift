// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GeobufDecoder",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GeobufDecoder",
            targets: ["GeobufDecoder"]
		)
    ],
	dependencies: [
		// 1.29.0 was the version at the time of writing
		.package(
			url: "https://github.com/apple/swift-protobuf.git",
			from: "1.29.0"
		)
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GeobufDecoder",
			dependencies: [
				.product(name: "SwiftProtobuf", package: "swift-protobuf")
			],
			resources: [
				.process("Resources")
			]
		),
		.testTarget(
			name: "GeobufDecoderTests",
			dependencies: ["GeobufDecoder"]
		)
    ]
)
