//
//  ResourceLoader.swift
//  GeobufDecoder
//
//  Created by Uros Krkic on 3.6.2025.
//

import Foundation

public enum ResourceLoader {
    public static func loadData(named name: String, withExtension ext: String) -> Data? {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
