import Foundation
import Compression

/// Minimal read-only ZIP reader (stored + deflate), enough for .docx / .pptx containers.
struct ZipArchive {
    enum ZipError: Error {
        case notAZipFile
        case corrupted
        case unsupportedCompression(UInt16)
    }

    private struct Entry {
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let bytes: [UInt8]
    private let entries: [String: Entry]

    var entryNames: [String] { Array(entries.keys) }

    init(data: Data) throws {
        let bytes = [UInt8](data)
        self.bytes = bytes
        guard bytes.count >= 22 else { throw ZipError.notAZipFile }

        // End of central directory record.
        var eocd: Int?
        var index = bytes.count - 22
        let lowerBound = max(0, bytes.count - 22 - 65_535)
        while index >= lowerBound {
            if Self.u32(bytes, index) == 0x0605_4b50 { eocd = index; break }
            index -= 1
        }
        guard let eocd else { throw ZipError.notAZipFile }

        let count = Int(Self.u16(bytes, eocd + 10))
        var pointer = Int(Self.u32(bytes, eocd + 16))
        var entries: [String: Entry] = [:]

        for _ in 0..<count {
            guard pointer + 46 <= bytes.count, Self.u32(bytes, pointer) == 0x0201_4b50 else {
                throw ZipError.corrupted
            }
            let method = Self.u16(bytes, pointer + 10)
            let compressedSize = Int(Self.u32(bytes, pointer + 20))
            let uncompressedSize = Int(Self.u32(bytes, pointer + 24))
            let nameLength = Int(Self.u16(bytes, pointer + 28))
            let extraLength = Int(Self.u16(bytes, pointer + 30))
            let commentLength = Int(Self.u16(bytes, pointer + 32))
            let localOffset = Int(Self.u32(bytes, pointer + 42))
            let nameStart = pointer + 46
            guard nameStart + nameLength <= bytes.count else { throw ZipError.corrupted }
            let nameBytes = Array(bytes[nameStart..<(nameStart + nameLength)])
            let name = String(bytes: nameBytes, encoding: .utf8)
                ?? String(bytes: nameBytes, encoding: .isoLatin1)
                ?? ""
            entries[name] = Entry(method: method, compressedSize: compressedSize,
                                  uncompressedSize: uncompressedSize, localHeaderOffset: localOffset)
            pointer = nameStart + nameLength + extraLength + commentLength
        }
        self.entries = entries
    }

    func data(for name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, Self.u32(bytes, header) == 0x0403_4b50 else {
            throw ZipError.corrupted
        }
        let nameLength = Int(Self.u16(bytes, header + 26))
        let extraLength = Int(Self.u16(bytes, header + 28))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard end <= bytes.count else { throw ZipError.corrupted }
        let payload = Array(bytes[start..<end])

        switch entry.method {
        case 0:
            return Data(payload)
        case 8:
            return try Self.inflate(payload, expectedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedCompression(entry.method)
        }
    }

    /// Raw DEFLATE via Apple's Compression framework (COMPRESSION_ZLIB is raw deflate, RFC 1951).
    private static func inflate(_ source: [UInt8], expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        guard !source.isEmpty else { throw ZipError.corrupted }
        var destination = [UInt8](repeating: 0, count: expectedSize)
        let written = source.withUnsafeBufferPointer { src -> Int in
            destination.withUnsafeMutableBufferPointer { dst -> Int in
                compression_decode_buffer(dst.baseAddress!, expectedSize,
                                          src.baseAddress!, source.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { throw ZipError.corrupted }
        return Data(destination.prefix(written))
    }

    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        guard offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1]) << 8
        let b2 = UInt32(bytes[offset + 2]) << 16
        let b3 = UInt32(bytes[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
