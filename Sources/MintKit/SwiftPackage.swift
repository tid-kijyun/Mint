import Foundation
import PathKit
import SwiftCLI

struct SwiftPackage: Decodable {

    let name: String
    let products: [Product]
    let targets: [Target]

    init(directory: Path) throws {

        let content: String
        do {
            content = try Task.capture("swift", arguments: ["package", "dump-package"], directory: directory.string).stdout
        } catch let error as CaptureError {
            let captureResult = error.captured
            let message = captureResult.stderr.isEmpty ? captureResult.stdout : captureResult.stderr
            throw MintError.packageReadError("Couldn't dump package:\n\(message)")
        }

        guard let json = content.firstIndex(of: "{"),
            let data = content[json...].data(using: .utf8) else {
            throw MintError.packageReadError("Couldn't parse package dump:\n\(content)")
        }

        do {
            self = try JSONDecoder().decode(SwiftPackage.self, from: data)
        } catch {
            throw MintError.packageReadError("Couldn't decode package dump:\n\(error)")
        }
    }

    struct Product: Decodable {

        let name: String
        let isExecutable: Bool
        let targetNames: [String]

        enum CodingKeys: String, CodingKey {
            case name
            case type
            case productType = "product_type"
            case targets
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            if container.contains(.productType) {
                // <= Swift 4.2
                let type = try container.decode(String.self, forKey: .productType)
                isExecutable = type == "executable"
            } else {
                // > Swift 5.0

                enum ProductCodingKeys: String, CodingKey {
                    case executable
                    case library
                }

                let typeContainer = try container.nestedContainer(keyedBy: ProductCodingKeys.self, forKey: .type)
                isExecutable = typeContainer.contains(.executable)
            }
            targetNames = try container.decode([String].self, forKey: .targets)
        }
    }

    struct Target: Decodable {

        let name: String
        let resources: [Resource]
        let dependencies: [Dependency]

        enum CodingKeys: String, CodingKey {
            case name
            case resources
            case type
            case dependencies
        }

        enum ResourceCodingKeys: String, CodingKey {
            case path
            case rule
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            resources = try container.decode([Resource].self, forKey: .resources)
            dependencies = try container.decode([Dependency].self, forKey: .dependencies)
        }
    }

    struct Resource: Decodable {

        let path: String

        enum CodingKeys: String, CodingKey {
            case path
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decode(String.self, forKey: .path)
        }
    }

    struct Dependency: Decodable {

        let byName: [String]

        enum CodingKeys: String, CodingKey {
            case byName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            byName = try container.decode([String?].self, forKey: .byName).compactMap { $0 }
        }
    }
}
