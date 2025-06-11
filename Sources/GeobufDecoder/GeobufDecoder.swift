//
//  GeobufDecoder.swift
//  GeobufDecoder
//
//  Created by Uros Krkic on 3.6.2025.
//

import Foundation

///
/// Converter from MapBox's Geobuf representation to GeoJSON.
///
/// **DEPENDENCIES:**
/// - `SwiftProtobuf` library: `https://github.com/apple/swift-protobuf.git`
/// - `geobuf.pb` - Auto-generated Swift protobuf file, based on MapBox's `geobuf.proto` file using:
/// - `protoc --swift_out=. geobuf.proto`
///
/// ⚠️ Mapbox’s Geobuf library does not provide native support to convert `DataMessage` to GeoJSON in Swift.
/// It requires manual serialization of `DataMessage` to GeoJSON representation.
///
/// `DataMessage` is a Protobuf representation of vector features (not directly usable by MapKit).
/// The features must be extracted and re-encoded into proper GeoJSON syntax.
///
/// **NOTE:** ⚠️ `GeometryCollection` currently not supported.
///
public struct GeobufDecoder {
	
	private var parseStringAsType = false
	private var trimStringPropertiesValues = false
	private var verbose = false
	
	private static let trimCharacterSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\""))
	
	/// Initializes the decoder with custom configuration.
	///
	/// - Parameters:
	///   - parseStringAsType: If `true`, attempts to parse string values into native types (`Int`, `Double`, `Bool`) when possible, otherwise `String`.
	///                        For example, a string `"42"` will be decoded as an `Int`, `"3.14"` as a `Double`, and `"true"` as a `Bool`.
	///                        If `false` (default), all string values are kept as-is.
	///   - trimStringPropertiesValues: If `true`, trims leading and trailing whitespace and quotation marks (`"`) from all string properties values during decoding.
	///                                 Useful for cleaning up input from loosely structured data sources.
	///                                 For example, `"\"value\""` will be decoded as `"value"`.
	///                                 If `false` (default), no trimming applied.
	///   - verbose: If `true`, enables verbose logging or debug output during decoding, helpful for development or troubleshooting.
	///
	public init(parseStringAsType: Bool = false, trimStringPropertiesValues: Bool = false, verbose: Bool = false) {
		self.parseStringAsType = parseStringAsType
		self.trimStringPropertiesValues = trimStringPropertiesValues
		self.verbose = verbose
	}
	
	// MARK: - Decoders
	
	/// Create a GeoJSON from a Geobuf file.
	///
	/// - Parameters:
	///   - geobufFile: URL to a Geobuf file.
	///   - partial: If `false` (the default), this method will check
	///     ``Message/isInitialized`` after decoding to verify that all required
	///     fields are present. If any are missing, this method fails.
	public func decode(geobufFile: URL, partial: Bool = false) -> GeoJSON? {
		guard let data = try? Data(contentsOf: geobufFile) else { return nil }
		return decode(data: data)
	}
	
	/// Create a GeoJSON from a Data.
	///
	/// - Parameters:
	///   - data: Data representation of a Geobuf.
	///   - partial: If `false` (the default), this method will check
	///     ``Message/isInitialized`` after decoding to verify that all required
	///     fields are present. If any are missing, this method fails.
	public func decode(data: Data, partial: Bool = false) -> GeoJSON? {
		do {
			let decodedDataMessage = try DataMessage(serializedBytes: data, partial: partial)
			return decode(dataMessage: decodedDataMessage)
		} catch {
			print("ERROR: Geobuf decoding error: \(error) -> \(error.localizedDescription)")
			print("-----> Consider using 'partial' argument.")
			return nil
		}
	}
	
	/// Create a GeoJSON from already deserialized Geobuf to DataMessage.
	///
	/// - Parameters:
	///   - dataMessage: deserialized Geobuf to `DataMessage`.
	public func decode(dataMessage: DataMessage) -> GeoJSON {
		if verbose {
			print("########################################################")
			print("Has-Dimensions: \(dataMessage.hasDimensions)")
			print("Dimensions: \(dataMessage.dimensions)")
			print("Has-Precision: \(dataMessage.hasPrecision)")
			print("Precision: \(dataMessage.precision)")
			print("Keys: \(dataMessage.keys)")
			print("Custom-Props: \(dataMessage.featureCollection.customProperties)")
			print("Values: \(dataMessage.featureCollection.values)")
			print("########################################################")
			print("Geobuf (Protobuf) DataMessage:\n\(dataMessage)")
			print("########################################################")
		}
		
		switch dataMessage.dataType {
		case .featureCollection(let fc):
			var features = [GeoJSON.Feature]()
			fc.features.forEach { feat in
				let feature = buildFeature(feat: feat, dataMessage: dataMessage)
				features.append(feature)
			}
			var featureCollection = GeoJSON.FeatureCollection(features: features)
			featureCollection.customProperties = buildProperties(indexes: fc.customProperties, keys: dataMessage.keys, values: fc.values)
			return GeoJSON.featureCollection(featureCollection)
		case .feature(let feat):
			var feature = buildFeature(feat: feat, dataMessage: dataMessage)
			feature.customProperties = buildProperties(indexes: feat.customProperties, keys: dataMessage.keys, values: feat.values)
			return GeoJSON.feature(feature)
		case .geometry(let geom):
			var geometry = buildGeometry(geom: geom, dataMessage: dataMessage)
			geometry.customProperties = buildProperties(indexes: geom.customProperties, keys: dataMessage.keys, values: geom.values)
			return GeoJSON.geometry(geometry)
		case .none:
			return GeoJSON.empty()
		}
	}
}

// MARK: - Build helpers

private extension GeobufDecoder {
	static func parseString(_ input: String, trim: Bool = false) -> GeoJSON.AnyCodable {
		if let boolValue = Bool(input) {
			return GeoJSON.AnyCodable(boolValue)
		} else if let intValue = Int(input) {
			return GeoJSON.AnyCodable(intValue)
		} else if let doubleValue = Double(input) {
			return GeoJSON.AnyCodable(doubleValue)
		} else {
			if trim {
				return GeoJSON.AnyCodable(trimQuotes(input))
			}
			return GeoJSON.AnyCodable(input)
		}
	}
	
	static func trimQuotes(_ input: String) -> String {
		return input.trimmingCharacters(in: trimCharacterSet)
	}
	
	func buildStringProperty(_ value: String) -> GeoJSON.AnyCodable {
		if parseStringAsType {
			return GeobufDecoder.parseString(value, trim: trimStringPropertiesValues)
		}
		if trimStringPropertiesValues {
			return GeoJSON.AnyCodable(GeobufDecoder.trimQuotes(value))
		}
		return GeoJSON.AnyCodable(value)
	}
	
	func buildProperties(indexes: [UInt32], keys: [String], values: [DataMessage.Value]) -> [String: GeoJSON.AnyCodable] {
		var dict: [String: GeoJSON.AnyCodable] = [:]

		for i in stride(from: 0, to: indexes.count, by: 2) {
			let keyIndex = Int(indexes[i])
			let valueIndex = Int(indexes[i + 1])

			guard keyIndex < keys.count, valueIndex < values.count else {
				continue // or handle error
			}
			
			let key = keys[keyIndex]
			let value = values[valueIndex]
			
			var anyValue: GeoJSON.AnyCodable?
			if let valueType = value.valueType {
				switch valueType {
				case .stringValue(let val):
					anyValue = buildStringProperty(val)
				case .doubleValue(let val):
					anyValue = GeoJSON.AnyCodable(val)
				case .posIntValue(let val):
					anyValue = GeoJSON.AnyCodable(Int(val))
				case .negIntValue(let val):
					anyValue = GeoJSON.AnyCodable(Int(val))
				case .boolValue(let val):
					anyValue = GeoJSON.AnyCodable(val)
				case .jsonValue(let val):
					if let jsonData = val.data(using: .utf8) {
						do {
							if let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
								anyValue = GeoJSON.AnyCodable(dictionary)
							}
						} catch {
							if verbose {
								print("Failed to parse JSON dict: \(error) --> \(val) ==> Fallback as String representation.")
							}
							anyValue = buildStringProperty(val)
						}
					}
				}
				
				dict[key] = anyValue
			}
		}
		return dict
	}
	
	func buildGeometry(geom: DataMessage.Geometry, dataMessage: DataMessage) -> GeoJSON.Geometry {
		var geometry: GeoJSON.Geometry
		switch geom.type {
		case .point:
			let coords = GeobufDecoder.buildLevel1NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision)
			geometry = GeoJSON.Geometry(coords: .point(coords))
		case .multipoint:
			let coords = GeobufDecoder.buildLevel2NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision)
			geometry = GeoJSON.Geometry(coords: .multiPoint(coords))
		case .linestring:
			let coords = GeobufDecoder.buildLevel2NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision)
			geometry = GeoJSON.Geometry(coords: .lineString(coords))
		case .multilinestring:
			let coords = GeobufDecoder.buildLevel3NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision, closed: false)
			geometry = GeoJSON.Geometry(coords: .multiLineString(coords))
		case .polygon:
			let coords = GeobufDecoder.buildLevel3NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision, closed: true)
			geometry = GeoJSON.Geometry(coords: .polygon(coords))
		case .multipolygon:
			let coords = GeobufDecoder.buildLevel4NestingCoords(geometry: geom, dimensions: dataMessage.dimensions, precision: dataMessage.precision)
			geometry = GeoJSON.Geometry(coords: .multiPolygon(coords))
		case .geometrycollection:
			// Currently not supported
			geometry = GeoJSON.Geometry(coords: .point([]))
			break
		}
		return geometry
	}
	
	func buildFeature(feat: DataMessage.Feature, dataMessage: DataMessage) -> GeoJSON.Feature {
		if verbose {
			print("Feature-ID: \(feat.id)")
			print("Feature-Props: \(feat.properties)")
			print("Feature-Values: \(feat.values)")
			print("========================================================")
		}
		var feature = GeoJSON.Feature(id: feat.id.isEmpty ? nil : feat.id)
		feature.properties = buildProperties(indexes: feat.properties, keys: dataMessage.keys, values: feat.values)
		feature.geometry = buildGeometry(geom: feat.geometry, dataMessage: dataMessage)
		return feature
	}
}

// MARK: - Coordinates extraction helpers

private extension GeobufDecoder {
	/// Starting from the first element, it denotes number of elements after it.
	///
	/// For input: `[1, 6, 1, 8, 3, 16, 3, 14, 1, 18, 2, 11, 1, 1, 12, 1, 16]`
	///
	/// Grouping logic:
	/// - 1 -> take one element after -> 6 (6 pairs in coords flat array)
	/// - 1 -> take one element after -> 8 (8 pairs in coords flat array)
	/// - 3 -> take three elements after -> 16, 3, 14 (array or 3 subarrays where each contains pairs (16, 3, 14) in coords flat array)
	/// - ...
	///
	/// Output is: `[[6], [8], [16, 3, 14], [18], [11, 1], [12], [16]]`
	static func groupByPairsGroups(from input: [Int]) -> [[Int]] {
		var result: [[Int]] = []
		var index = 0

		while index < input.count {
			let count = input[index]
			index += 1
			guard index + count <= input.count else { break }
			let group = Array(input[index..<index + count])
			result.append(group)
			index += count
		}

		return result
	}
	
	/// `MultiPolygon` coordinates
	static func buildLevel4NestingCoords(geometry: DataMessage.Geometry, dimensions: UInt32, precision: UInt32) -> [[[[Double]]]] {
		var lengths: [Int] = []
		/// Special case if a multipolygon has only one polygon, `geometry.lengths` is empty.
		if geometry.lengths.isEmpty {
			/// Artifitially add a polygon.
			lengths = [1, 1, geometry.coords.count / Int(dimensions)]
		} else {
			lengths = geometry.lengths.map { Int($0) }
		}
		
		let totalCount = lengths[0]
		lengths.removeFirst()
		
		let groupedLengths = groupByPairsGroups(from: lengths)
		
		if totalCount != groupedLengths.count {
			print("ERROR: Total count differs from available nesting pairs.")
			return []
		}
		
		// Extract the coordinates from coords flat array, based on grouping calculated in "groupByPairsGroups()".
		// A group in coords flat array starts (first two elements) with coordinates values. The rest of elements for the group
		// are relative to the first two elements, and must be calculated.
		// As the values are Int64, they must be divided by precision, to get decimal values.
		func extractCoordinates(groupings: [[Int]], from coords: [Int64], dimensions: UInt32, precision: UInt32, closed: Bool = true) -> [[[[Double]]]] {
			var result: [[[[Double]]]] = []
			let dimension = Int(dimensions)
			let precision: Double = pow(10, Double(precision))
			var index = 0

			for group in groupings {
				var outerRing: [[[Double]]] = []
				for pairs in group {
					var ring: [[Double]] = []
					var valueLong: Int64 = 0
					var valueLat: Int64 = 0
					for _ in 0 ..< pairs {
						guard index + 1 < coords.count else { break }
						var currentGroup: [Double] = []
						valueLong += coords[index]
						valueLat += coords[index + 1]
						let decimalLong = Double(valueLong) / precision
						let decimalLat = Double(valueLat) / precision
						currentGroup.append(decimalLong)
						currentGroup.append(decimalLat)
						index += dimension
						ring.append(currentGroup)
					}
					if closed {
						ring.append(ring[0])
					}
					outerRing.append(ring)
				}
				result.append(outerRing)
			}
			return result
		}
		return extractCoordinates(groupings: groupedLengths, from: geometry.coords, dimensions: dimensions, precision: precision)
	}
	
	/// `Polygon, MultiLineString` coordinates
	static func buildLevel3NestingCoords(geometry: DataMessage.Geometry, dimensions: UInt32, precision: UInt32, closed: Bool) -> [[[Double]]] {
		var lengths: [Int] = []
		/// Special case if a geometry a single polygon / line, `geometry.lengths` is empty.
		if geometry.lengths.isEmpty {
			/// Artifitially add a polygon / line.
			lengths = [1, 1, geometry.coords.count / Int(dimensions)]
		} else {
			/// Create lengths structure the same as for multipolygon.
			/// For instance [4, 4] will be mapped to [2, 1, 4, 1, 4]
			/// For instance [2, 2] will be mapped to [2, 1, 2, 1, 2]
			lengths.append(geometry.lengths.count)
			for ln in geometry.lengths {
				lengths.append(1)
				lengths.append(Int(ln))
			}
		}
		
		let totalCount = lengths[0]
		lengths.removeFirst()
		
		let groupedLengths = groupByPairsGroups(from: lengths)
		
		if totalCount != groupedLengths.count {
			print("ERROR: Total count differs from available nesting pairs.")
			return []
		}
		
		// Extract the coordinates from coords flat array, based on grouping calculated in "groupByPairsGroups()".
		// A group in coords flat array starts (first two elements) with coordinates values. The rest of elements for the group
		// are relative to the first two elements, and must be calculated.
		// As the values are Int64, they must be divided by precision, to get decimal values.
		func extractCoordinates(groupings: [[Int]], from coords: [Int64], dimensions: UInt32, precision: UInt32, closed: Bool) -> [[[Double]]] {
			var result: [[[Double]]] = []
			let dimension = Int(dimensions)
			let precision: Double = pow(10, Double(precision))
			var index = 0

			for group in groupings {
				for pairs in group {
					var combo: [[Double]] = []
					var valueLong: Int64 = 0
					var valueLat: Int64 = 0
					for _ in 0 ..< pairs {
						guard index + 1 < coords.count else { break }
						var currentGroup: [Double] = []
						valueLong += coords[index]
						valueLat += coords[index + 1]
						let decimalLong = Double(valueLong) / precision
						let decimalLat = Double(valueLat) / precision
						currentGroup.append(decimalLong)
						currentGroup.append(decimalLat)
						index += dimension
						combo.append(currentGroup)
					}
					if closed {
						combo.append(combo[0])
					}
					result.append(combo)
				}
			}
			return result
		}
		return extractCoordinates(groupings: groupedLengths, from: geometry.coords, dimensions: dimensions, precision: precision, closed: closed)
	}
	
	/// `MultiPoint, LineString` coordinates
	static func buildLevel2NestingCoords(geometry: DataMessage.Geometry, dimensions: UInt32, precision: UInt32) -> [[Double]] {
		let groupedLengths = [[geometry.coords.count / Int(dimensions)]]
		
		// Extract the coordinates from coords flat array, based on grouping calculated in "groupByPairsGroups()".
		// A group in coords flat array starts (first two elements) with coordinates values. The rest of elements for the group
		// are relative to the first two elements, and must be calculated.
		// As the values are Int64, they must be divided by precision, to get decimal values.
		func extractCoordinates(groupings: [[Int]], from coords: [Int64], dimensions: UInt32, precision: UInt32, closed: Bool = true) -> [[Double]] {
			var result: [[Double]] = []
			let dimension = Int(dimensions)
			let precision: Double = pow(10, Double(precision))
			var index = 0

			for group in groupings {
				for pairs in group {
					var valueLong: Int64 = 0
					var valueLat: Int64 = 0
					for _ in 0 ..< pairs {
						guard index + 1 < coords.count else { break }
						var currentGroup: [Double] = []
						valueLong += coords[index]
						valueLat += coords[index + 1]
						let decimalLong = Double(valueLong) / precision
						let decimalLat = Double(valueLat) / precision
						currentGroup.append(decimalLong)
						currentGroup.append(decimalLat)
						index += dimension
						result.append(currentGroup)
					}
				}
			}
			return result
		}
		return extractCoordinates(groupings: groupedLengths, from: geometry.coords, dimensions: dimensions, precision: precision)
	}
	
	/// `Point` coordinates
	static func buildLevel1NestingCoords(geometry: DataMessage.Geometry, dimensions: UInt32, precision: UInt32) -> [Double] {
		let groupedLengths = [[geometry.coords.count / Int(dimensions)]]
		
		// Extract the coordinates from coords flat array, based on grouping calculated in "groupByPairsGroups()".
		// A group in coords flat array starts (first two elements) with coordinates values. The rest of elements for the group
		// are relative to the first two elements, and must be calculated.
		// As the values are Int64, they must be divided by precision, to get decimal values.
		func extractCoordinates(groupings: [[Int]], from coords: [Int64], dimensions: UInt32, precision: UInt32, closed: Bool = true) -> [Double] {
			let precision: Double = pow(10, Double(precision))
			let index = 0
			var currentGroup: [Double] = []
			let valueLong: Int64 = coords[index]
			let valueLat: Int64 = coords[index + 1]
			let decimalLong = Double(valueLong) / precision
			let decimalLat = Double(valueLat) / precision
			currentGroup.append(decimalLong)
			currentGroup.append(decimalLat)
			return currentGroup
		}
		return extractCoordinates(groupings: groupedLengths, from: geometry.coords, dimensions: dimensions, precision: precision)
	}
}
