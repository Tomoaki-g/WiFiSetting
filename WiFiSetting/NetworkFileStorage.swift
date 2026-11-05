//
//  NetworkFileStorage.swift
//  WiFiSetting
//
//  Created by takemoto on 2026/11/05.
//

import Foundation

struct WiFiSavedState: Codable {
    var networks: [WiFiDemoStore.Network]
    var connectedID: String?
    var isEnabled: Bool
}

struct NetworkFileStorage {
    private let fileURL: URL
    
    init() throws {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        fileURL = directory.appendingPathComponent("networks.json")
    }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func saveState(_ state: WiFiSavedState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
    
    func loadState() throws -> WiFiSavedState? {
        let data: Data
        
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WiFiSavedState.self, from: data)
        } catch {
            // 以前の配列形式も読み込む。次の保存時に新形式へ移行する。
            if let networks = try? decoder.decode([WiFiDemoStore.Network].self, from: data) {
                return WiFiSavedState(networks: networks, connectedID: nil, isEnabled: true)
            }
            throw error
        }
    }
}
