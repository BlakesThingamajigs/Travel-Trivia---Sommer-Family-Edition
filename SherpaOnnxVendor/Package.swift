// swift-tools-version:5.9
import PackageDescription

// Prebuilt on-device TTS engine (sherpa-onnx + ONNX Runtime), hosted as a
// GitHub Release asset rather than vendored in git — the combined static
// library is tens of MB per architecture slice, well past what belongs in
// git history. arm64-only Simulator slice: x86_64 was dropped since
// Simulator on Apple Silicon covers current needs.
let package = Package(
    name: "SherpaOnnxVendor",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SherpaOnnxBinary", targets: ["SherpaOnnxBinary"])
    ],
    targets: [
        .binaryTarget(
            name: "SherpaOnnxBinary",
            url: "https://github.com/BlakesThingamajigs/Travel-Trivia---Sommer-Family-Edition/releases/download/sherpa-onnx-vendor-v1/sherpa-onnx-combined.xcframework.zip",
            checksum: "cf83488471d72402f4feb0fc6d08c24a9dd016cca866f49b7239e0e715468db8"
        )
    ]
)
