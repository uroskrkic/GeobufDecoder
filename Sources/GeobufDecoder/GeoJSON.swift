//
//  GeoJSON.swift
//  GeobufDecoder
//
//  Created by Uros Krkic on 3.6.2025.
//

import Foundation


///
/// GeoJSON representation.
///
/// **NOTE:** ⚠️ `GeometryCollection` currently not supported.
///
public enum GeoJSON: Encodable {
	case featureCollection(GeoJSON.FeatureCollection)
	case feature(GeoJSON.Feature)
	case geometry(GeoJSON.Geometry)
	
	enum CodingKeys: String, CodingKey {
		case type
	}
	
	enum GeoJSONType: String, Codable {
		case featureCollection
		case feature
		case point
		case multiPoint
		case lineString
		case multiLineString
		case polygon
		case multiPolygon
	}
	
	// MARK: - Codable
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(GeoJSONType.self, forKey: .type)

		switch type {
		case .featureCollection:
			self = .featureCollection(try GeoJSON.FeatureCollection(from: decoder))
		case .feature:
			self = .feature(try GeoJSON.Feature(from: decoder))
		default:
			self = .geometry(try GeoJSON.Geometry(from: decoder))
		}
	}

	public func encode(to encoder: Encoder) throws {
		switch self {
		case .featureCollection(let fc):
			try fc.encode(to: encoder)
		case .feature(let f):
			try f.encode(to: encoder)
		case .geometry(let g):
			try g.encode(to: encoder)
		}
	}
	
	/// Null-object pattern
	public static func empty() -> GeoJSON {
		GeoJSON.geometry(Geometry(coords: .point([])))
	}
}

// MARK: - JSON conversion

public extension GeoJSON {
	/**
	 Returns GeoJSON Data which can be directly used in `MKGeoJSONDecoder`
	 ```
	 let decoder = MKGeoJSONDecoder()
	 if let jsonData = geojson?.jsonData, let features = try? decoder.decode(jsonData) as [MKGeoJSONObject] {
		 print("MapKit Features: \(features)")
	 } else {
		 print("Error decoding features")
	 }
	 */
	var jsonData: Data? {
		let jsonEncoder = JSONEncoder()
		return try? jsonEncoder.encode(self)
	}
	
	/**
	 Returns GeoJSON pretty-printed String. !!! Performance intensive call.
	 ```
	 if let geojsonString = geojson?.jsonString {
		 print("GeoJSON:\n\(geojsonString)")
	 } else {
		 print("Error decoding features")
	 }
	 */
	var jsonString: String? {
		let jsonEncoder = JSONEncoder()
		jsonEncoder.outputFormatting = [.prettyPrinted]
		guard let data = try? jsonEncoder.encode(self) else { return nil }
		return String(data: data, encoding: .utf8)
	}
}

// MARK: - GeoJSON types

public extension GeoJSON {
	struct FeatureCollection: Codable {
		let type: String = "FeatureCollection"
		var features: [Feature]
		var customProperties: [String: AnyCodable]?		// root level properties
		
		enum CodingKeys: String, CodingKey {
			case type, features
		}
		
		struct DynamicCodingKeys: CodingKey {
			var stringValue: String
			init(stringValue: String) {
				self.stringValue = stringValue
			}

			var intValue: Int? = nil
			init?(intValue: Int) {
				return nil	// only string keys supported
			}
		}
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(type, forKey: .type)
			try container.encode(features, forKey: .features)

			// Inject customProperties at root
			if let customProperties = customProperties {
				var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
				for (key, value) in customProperties {
					guard CodingKeys(stringValue: key) == nil else {
						// Prevent overwriting existing keys like "type" or "features"
						continue
					}
					let dynamicKey = DynamicCodingKeys(stringValue: key)
					try dynamicContainer.encode(value, forKey: dynamicKey)
				}
			}
		}
	}

	struct Feature: Codable {
		let id: String?
		let type: String = "Feature"
		var geometry: Geometry?
		var properties: [String: AnyCodable]?
		var customProperties: [String: AnyCodable]?		// root level properties

		enum CodingKeys: String, CodingKey {
			case id, type, geometry, properties
		}
		
		struct DynamicCodingKeys: CodingKey {
			var stringValue: String
			init(stringValue: String) {
				self.stringValue = stringValue
			}

			var intValue: Int? = nil
			init?(intValue: Int) {
				return nil	// only string keys supported
			}
		}
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(id, forKey: .id)
			try container.encode(type, forKey: .type)
			try container.encode(geometry, forKey: .geometry)
			try container.encode(properties, forKey: .properties)

			// Inject customProperties at root
			if let customProperties = customProperties {
				var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
				for (key, value) in customProperties {
					guard CodingKeys(stringValue: key) == nil else {
						// Prevent overwriting existing keys like "type" or "features"
						continue
					}
					let dynamicKey = DynamicCodingKeys(stringValue: key)
					try dynamicContainer.encode(value, forKey: dynamicKey)
				}
			}
		}
	}
	
	struct Geometry: Codable {
		enum Coords {
			case point([Double])
			case lineString([[Double]])
			case polygon([[[Double]]])
			case multiPoint([[Double]])
			case multiLineString([[[Double]]])
			case multiPolygon([[[[Double]]]])
		}
		
		let coords: Coords
		var customProperties: [String: AnyCodable]?		// root level properties

		enum CodingKeys: String, CodingKey {
			case type, coordinates
		}
		
		struct DynamicCodingKeys: CodingKey {
			var stringValue: String
			init(stringValue: String) {
				self.stringValue = stringValue
			}

			var intValue: Int? = nil
			init?(intValue: Int) {
				return nil	// only string keys supported
			}
		}

		enum GeometryType: String, Codable {
			case point = "Point"
			case lineString = "LineString"
			case polygon = "Polygon"
			case multiPoint = "MultiPoint"
			case multiLineString = "MultiLineString"
			case multiPolygon = "MultiPolygon"
		}
		
		init(coords: Coords) {
			self.coords = coords
			self.customProperties = nil
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let type = try container.decode(GeometryType.self, forKey: .type)
			
			switch type {
			case .point:
				coords = .point(try container.decode([Double].self, forKey: .coordinates))
			case .lineString:
				coords = .lineString(try container.decode([[Double]].self, forKey: .coordinates))
			case .polygon:
				coords = .polygon(try container.decode([[[Double]]].self, forKey: .coordinates))
			case .multiPoint:
				coords = .multiPoint(try container.decode([[Double]].self, forKey: .coordinates))
			case .multiLineString:
				coords = .multiLineString(try container.decode([[[Double]]].self, forKey: .coordinates))
			case .multiPolygon:
				coords = .multiPolygon(try container.decode([[[[Double]]]].self, forKey: .coordinates))
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)

			switch self.coords {
			case .point(let coords):
				try container.encode(GeometryType.point, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			case .lineString(let coords):
				try container.encode(GeometryType.lineString, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			case .polygon(let coords):
				try container.encode(GeometryType.polygon, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			case .multiPoint(let coords):
				try container.encode(GeometryType.multiPoint, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			case .multiLineString(let coords):
				try container.encode(GeometryType.multiLineString, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			case .multiPolygon(let coords):
				try container.encode(GeometryType.multiPolygon, forKey: .type)
				try container.encode(coords, forKey: .coordinates)
			}
			
			// Inject customProperties at root
			if let customProperties = customProperties {
				var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
				for (key, value) in customProperties {
					guard CodingKeys(stringValue: key) == nil else {
						// Prevent overwriting existing keys like "type" or "features"
						continue
					}
					let dynamicKey = DynamicCodingKeys(stringValue: key)
					try dynamicContainer.encode(value, forKey: dynamicKey)
				}
			}
		}
	}
}

// MARK: - AnyCodable extension

public extension GeoJSON {
	struct AnyCodable: Codable {
		let value: Any

		public init(_ value: Any) {
			self.value = value
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			if let intVal = try? container.decode(Int.self) {
				value = intVal
			} else if let doubleVal = try? container.decode(Double.self) {
				value = doubleVal
			} else if let boolVal = try? container.decode(Bool.self) {
				value = boolVal
			} else if let stringVal = try? container.decode(String.self) {
				value = stringVal
			} else if let arrayVal = try? container.decode([AnyCodable].self) {
				value = arrayVal.map { $0.value }
			} else if let dictVal = try? container.decode([String: AnyCodable].self) {
				value = dictVal.mapValues { $0.value }
			} else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.singleValueContainer()

			switch value {
			case let int as Int: try container.encode(int)
			case let double as Double: try container.encode(double)
			case let bool as Bool: try container.encode(bool)
			case let string as String: try container.encode(string)
			case let array as [Any]:
				try container.encode(array.map { AnyCodable($0) })
			case let dict as [String: Any]:
				try container.encode(dict.mapValues { AnyCodable($0) })
			default:
				let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON value")
				throw EncodingError.invalidValue(value, context)
			}
		}
	}
}
