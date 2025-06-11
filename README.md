# GeobufDecoder

> **Version 1.1.2**

> Language: Swift

`GeobufDecoder` is a Swift Package that enables decoding of [Geobuf](https://github.com/mapbox/geobuf) `DataMessage` objects into standard [GeoJSON](https://geojson.org/) format. It provides a native Swift solution for working with Geobuf-encoded vector data on iOS and macOS platforms.


## 📚 Background

[Geobuf](https://github.com/mapbox/geobuf) is a compact binary format for encoding geographic data, leveraging Google’s Protocol Buffers for efficient serialization. It is particularly useful for reducing the size of geographic datasets (e.g., GeoJSON) during network transfer.

However, iOS does not natively support decoding Geobuf files. While Mapbox provides a `.proto` file (`geobuf.proto`) that describes the binary schema, there is no official Swift implementation for decoding this structure into usable formats like GeoJSON.

The `GeobufDecoder` package fills this gap by:
- Decoding Geobuf `DataMessage` Protobufs using `SwiftProtobuf`.
- Mapping the decoded binary data to valid GeoJSON objects.
- Allowing you to overlay the resulting features directly on `MKMapView` (via `MKGeoJSONDecoder`), or use them in your custom data pipelines.


## 📦 Dependencies

- [`SwiftProtobuf`](https://github.com/apple/swift-protobuf): Used for decoding the raw `DataMessage` from binary Protobuf into structured Swift types. (Version `1.29.0` at the time of writing.)
- `geobuf.proto`: This proto file is based on the Protobuf schema provided by [Mapbox’s geobuf repository](https://github.com/mapbox/geobuf/blob/master/geobuf.proto). It is used to make auto-generated Swift protobuf file `geobuf.pb.swift` using: `protoc --swift_out=. geobuf.proto`. Both files are included in this package.


## ✅ Features

- Decode Geobuf (`DataMessage`) binary data into valid GeoJSON structures
- Supports all core GeoJSON geometries: Point, MultiPoint, LineString, MultiLineString, Polygon, MultiPolygon as well as Feature and FeatureCollection
- Extracts and maps feature properties
- Fully written in Swift, no need for Objective-C or bridging C++ libraries
- Can be used with `MKGeoJSONDecoder`, `MapKit`, or any GIS-compatible toolchain

⚠️ `GeometryCollection` is currently not supported.


## 🚀 Usage

```swift
import GeobufDecoder

let dataMessage: DataMessage = try DataMessage(serializedData: geobufData)
let decoder = GeobufDecoder()
let geojson = decoder.decode(dataMessage: dataMessage)

// or

let url = URL("<URL to a Geobuf file>")
let decoder = GeobufDecoder()
let geojson = decoder.decode(geobufFile: url)

// or

let data = try? Data("<Geobuf data>")
let decoder = GeobufDecoder()
let geojson = decoder.decode(data: data)

// `geojson` of type `GeoJSON`
// Use `geojson` (FeatureCollection or Features or Geometry)

// There are two handy properties of `GeoJSON`:
// var jsonData: Data? -> ready to use with `MKGeoJSONDecoder`
// var jsonString: String? -> print/debug purpose (not performant)

// MapKit usage:

 let decoder = MKGeoJSONDecoder()
 if let jsonData = geojson?.jsonData, let features = try? decoder.decode(jsonData) as [MKGeoJSONObject] {
	 print("MapKit Features: \(features)")
 } else {
	 print("Error decoding features")
 }
 
```

## ⚙️ Configuration

### Initialization

You can customize the behavior of the decoder using the `init(parseStringAsType:trimStringPropertiesValues:verbose:)` initializer.

The available parameters control how input values are interpreted and cleaned up during decoding.

```swift
public init(
    parseStringAsType: Bool = false,
    trimStringPropertiesValues: Bool = false,
    verbose: Bool = false
)
```

#### Parameters:

##### `parseStringAsType (default: false)`

When enabled, the decoder attempts to automatically parse string values into native types.

For example:

- "42" → `Int`
- "3.14" → `Double`
- "true" / "false" → `Bool`

This is useful when input data uses strings to represent numbers or booleans.

##### `trimStringPropertiesValues (default: false)`

If enabled, leading and trailing whitespace and quotation marks (") are removed from all decoded string properties.

Useful for cleaning up inconsistent or loosely formatted input data.

For example, `"\"value\""` will be decoded as `"value"`.

##### `verbose (default: false)`

Enables detailed logging during decoding. Helps with debugging and understanding how the input is processed.

### Decoding

You can decode an input into a GeoJSON object using the following methods:

- `public func decode(geobufFile: URL, partial: Bool = false) -> GeoJSON?`
- `public func decode(data: Data, partial: Bool = false) -> GeoJSON?`
- `public func decode(dataMessage: DataMessage) -> GeoJSON`

⚠️ `partial (default: false)` flag controls whether decoding should enforce validation of required fields.

- If set to `false` (default), the method checks that all required fields in the Protobuf message are fully initialized by calling `isInitialized`. If any required field is missing, decoding fails and returns nil.
- If set to `true`, the method skips the `isInitialized` check, allowing decoding to proceed even if some required fields are missing.

Use `partial` flag with caution — it can result in incomplete or malformed GeoJSON output if the input file is invalid.

For more info, check `SwiftProtobuf/Message+BinaryAdditions/init(serializedBytes:extensions:partial:options)` and `SwiftProtobuf/Message/isInitialized`.

## 🧩 Installation

Add the package to your `Package.swift`:

`.package(url: "https://github.com/uroskrkic/GeobufDecoder.git", from: "1.1.2")`

Then add `GeobufDecoder` as a dependency to your target.

## 📝 License

This project uses Mapbox’s `geobuf.proto` and is subject to its licensing. All Swift code in this package is licensed under the MIT License.

## 👥 Credits

- Based on the Geobuf format developed by Mapbox.
- Swift decoding powered by `SwiftProtobuf`.
