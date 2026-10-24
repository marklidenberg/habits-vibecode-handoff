import Compression
import Foundation

/// gzip (RFC 1952) over the raw deflate of `Compression`
enum Gzip {
    struct Corrupt: Error {}

    static func isGzip(_ data: Data) -> Bool {
        data.count >= 18 && data[data.startIndex] == 0x1f && data[data.startIndex + 1] == 0x8b
    }

    static func compress(_ data: Data) -> Data {
        var out = Data([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff])
        out.append(deflate(data))
        out.append(littleEndian(crc32(data)))
        out.append(littleEndian(UInt32(truncatingIfNeeded: data.count)))
        return out
    }

    static func decompress(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard isGzip(data), bytes[2] == 8 else { throw Corrupt() }

        let flags = bytes[3]
        var at = 10
        if flags & 4 != 0 { at += 2 + Int(bytes[at]) + Int(bytes[at + 1]) << 8 }
        if flags & 8 != 0 { at = (bytes[at...].firstIndex(of: 0) ?? bytes.count) + 1 }
        if flags & 16 != 0 { at = (bytes[at...].firstIndex(of: 0) ?? bytes.count) + 1 }
        if flags & 2 != 0 { at += 2 }
        guard at <= bytes.count - 8 else { throw Corrupt() }

        let trailer = bytes[(bytes.count - 8)...].map(UInt32.init)
        let crc = trailer[0] | trailer[1] << 8 | trailer[2] << 16 | trailer[3] << 24
        let size = Int(trailer[4] | trailer[5] << 8 | trailer[6] << 16 | trailer[7] << 24)
        let out = try inflate(Data(bytes[at..<(bytes.count - 8)]), size: size)
        guard crc32(out) == crc else { throw Corrupt() }
        return out
    }

    static func deflate(_ data: Data) -> Data {
        let capacity = data.count + 1024
        var out = Data(count: capacity)
        let written = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_encode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        return out.prefix(written)
    }

    static func inflate(_ data: Data, size: Int) throws -> Data {
        if size == 0 { return Data() }
        var out = Data(count: size)
        let written = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!, size,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Corrupt() }
        return out
    }

    static let table: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 != 0 ? 0xedb8_8320 ^ (c >> 1) : c >> 1 }
    }

    static func crc32(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { c, byte in table[Int((c ^ UInt32(byte)) & 0xff)] ^ (c >> 8) }
    }

    static func littleEndian(_ n: UInt32) -> Data {
        Data([UInt8(n & 0xff), UInt8(n >> 8 & 0xff), UInt8(n >> 16 & 0xff), UInt8(n >> 24 & 0xff)])
    }
}
