//
//  TestFeatureCollections.swift
//  GeobufDecoder
//
//  Created by Uros Krkic on 3.6.2025.
//

import Testing
import GeobufDecoder

struct FeatureCollectionsTests {
	/// Must set `partial: true` due to some missing required fields for Point feature. Not know what fields are missing.
	@Test func allGeometriesTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "All_Geometries-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData, partial: true)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	@Test func multiPolygonTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "MultiPolygon-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	@Test func polygonTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "Polygon-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	@Test func multiLineStringTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "MultiLineString-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	@Test func lineStringTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "LineString-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	@Test func multiPointTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "MultiPoint-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
	
	/// Must set `partial: true` due to some missing required fields. Not know what fields are missing.
	@Test func pointTest() async throws {
		let pbfData = ResourceLoader.loadData(named: "Point-FC", withExtension: "pbf")
		#expect(pbfData != nil)
		
		if let pbfData {
			let geojson = decoder.decode(data: pbfData, partial: true)
			#expect(geojson != nil)
			print("GeoJSON:\n\(geojson?.jsonString ?? "N/A")")
		}
	}
}
