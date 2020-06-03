//
//  FixedSizeBuffer.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

func sizeOf<T>(_ value: T.Type) -> Int {
  return MemoryLayout<T>.size
}

enum FixedSizeBufferError: Error {
  case overflow
}

/**
 * Take inspiration from https://github.com/kasei/swift-fixed-size-buffer
 */
class FixedSizeBuffer {
  let length: Int
  fileprivate var _data: Data

  var data: Data {
    return _data
  }

  var startIndex: Int {
    return data.startIndex
  }

  var endIndex: Int {
    return data.endIndex
  }

  init(length: Int) {
    self.length = length
    self._data = Data(repeating: 0, count: length)
  }

  init(data: Data) {
    self.length = data.count
    self._data = data
  }

  var reader: BufferReader {
    return .init(self)
  }

  var writer: BufferWriter {
    return .init(self)
  }

}

class BufferCursor {
  let buffer: FixedSizeBuffer
  fileprivate var offset: Int

  init(_ buffer: FixedSizeBuffer) {
    self.buffer = buffer
    self.offset = buffer.startIndex
  }

  var remainingBytes: Int {
    return buffer.length - (offset - buffer.startIndex)
  }

  func reset() {
    offset = buffer.startIndex
  }

  func seek(_ offset: Int) throws {
    guard offset >= buffer.startIndex && offset < buffer.endIndex else {
      throw FixedSizeBufferError.overflow
    }
    self.offset = buffer.startIndex + offset
  }

  func getOffset() -> Int {
    return offset - buffer.startIndex
  }
}

class BufferReader: BufferCursor {

  func readFixedWidthInteger<T: FixedWidthInteger>() throws -> T {
    let size = sizeOf(T.self)

    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    defer {
      offset += size
    }

    let startIndex = offset
    let endIndex = startIndex + size

    return buffer._data[startIndex..<endIndex].fixedWidthInteger()
  }

  func readByte() throws -> UInt8 {
    return try readFixedWidthInteger()
  }

  func readUInt16() throws -> UInt16 {
    return try readFixedWidthInteger()
  }

  func readUInt32() throws -> UInt32 {
    return try readFixedWidthInteger()
  }

  func readUInt64() throws -> UInt64 {
    return try readFixedWidthInteger()
  }

  func readASCIIString(ofSize size: Int) throws -> String {
    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }
    
    defer {
      offset += size
    }

    let startIndex = offset
    let endIndex = startIndex + size

    return buffer._data[startIndex..<endIndex].stringASCII ?? ""
  }

  func readUTF8String(ofSize size: Int) throws -> String {
    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    defer {
      offset += size
    }

    let startIndex = offset
    let endIndex = startIndex + size

    return buffer._data[startIndex..<endIndex].stringUTF8 ?? ""
  }

  func readASCIIString() throws -> String {
    // read string size from first 4 bytes (UInt32)
    let size = try readUInt32()

    return try readASCIIString(ofSize: Int(size))
  }

  func readUTF8String() throws -> String {
    // read string size from first 4 bytes (UInt32)
    let size = try readUInt32()

    return try readUTF8String(ofSize: Int(size))
  }
}

class BufferWriter: BufferCursor {
  private func write<T: FixedWidthInteger>(_ value: T) throws {
    let size = sizeOf(T.self)

    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    defer {
      offset += size
    }

    var val = value.bigEndian
    withUnsafeBytes(of: &val) { (valPtr) in
      let startIndex = offset
      let endIndex = startIndex + size
      let range: Range<Int> = startIndex..<endIndex
      buffer._data.replaceSubrange(range, with: valPtr.baseAddress!, count: size)
    }
  }

  func writeByte(_ value: UInt8) throws {
    try write(value)
  }

  func writeUInt16(_ value: UInt16) throws {
    try write(value)
  }

  func writeUInt32(_ value: UInt32) throws {
    try write(value)
  }

  func writeUInt64(_ value: UInt64) throws {
    try write(value)
  }

  func writeASCIIString(_ value: String, size: Int) throws {
    let chars = value.ASCIIBytes()
    let size = chars.count

    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    for index in 0..<size {
      try write(chars[index])
    }
  }

  /**
   * Write length of string as UInt32 first, followed by the actual content of ASCII string
   */
  func writeASCIIString(_ value: String) throws {
    let chars = value.ASCIIBytes()

    let valueSize = chars.count
    let totalSize = valueSize + sizeOf(UInt32.self)

    guard totalSize <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    try write(UInt32(valueSize))

    for c in chars {
      try write(c)
    }
  }

  func writeBuffer(_ aBuffer: FixedSizeBuffer) throws {
    let size = aBuffer.length

    guard size <= remainingBytes else {
      throw FixedSizeBufferError.overflow
    }

    defer {
      offset += size
    }

    aBuffer.data.withUnsafeBytes { (ptr) in
      let startIndex = offset
      let endIndex = startIndex + size
      let range: Range<Int> = startIndex..<endIndex
      buffer._data.replaceSubrange(range, with: ptr.baseAddress!, count: size)
    }
  }
}

/**
 * Read fixed width integer from data or aligned subdata.
 * This method bypass misaligned memory by copying the bytes to the new value.
 * (https://stackoverflow.com/questions/38023838/round-trip-swift-number-types-to-from-data)
 */
func readUnalignedFixedWidthInteger<T: FixedWidthInteger>(_ data: Data) -> T {
  var value: T = 0

  let bytesCopied = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }

  assert(bytesCopied == MemoryLayout<T>.size)

  return value.bigEndian
}

/**
 * Read fixed width integer from data.
 * This method will crash if data memory is not aligned (data was obtained as a slice of another Data)
 */
func readAlignedFixedWidthInteger<T: FixedWidthInteger>(_ data: Data) -> T {
  return T(bigEndian: data.withUnsafeBytes {
    $0.load(as: T.self)
  })
}

extension Data {

  var bytes : [UInt8] {
    return [UInt8](self)
  }

  func fixedWidthInteger<T: FixedWidthInteger>() -> T {
    return readUnalignedFixedWidthInteger(self)
  }

  var uint8: UInt8 {
    return fixedWidthInteger()
  }

  var uint16: UInt16 {
    return fixedWidthInteger()
  }

  var uint32: UInt32 {
    return fixedWidthInteger()
  }

  var uint64: UInt64 {
    return fixedWidthInteger()
  }

  var stringASCII: String? {
    get {
      return NSString(data: self, encoding: String.Encoding.ascii.rawValue) as String?
    }
  }

  var stringUTF8: String? {
    get {
      return NSString(data: self, encoding: String.Encoding.utf8.rawValue) as String?
    }
  }
}

extension String {

  func ASCIIBytes() -> [UInt8] {
    return self.utf8.map { UInt8($0) }
  }

}


