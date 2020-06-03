//
//  BTreeEntryPage.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

struct BTreeEntryPage: SimpleDBPage {

  var content: [UInt8]

  var numNextEntryPage: UInt32

  static func availableSizeForContent(pageSize: UInt32) -> Int {
    return Int(pageSize) - 8
  }

  func getBuffer(pageSize: UInt32) throws -> FixedSizeBuffer {
    precondition(content.count <= BTreeEntryPage.availableSizeForContent(pageSize: pageSize))

    let buffer = FixedSizeBuffer(length: Int(pageSize))
    let writer = buffer.writer

    try writer.writeUInt32(UInt32(content.count))

    for byte in content {
      try writer.writeByte(byte)
    }

    try writer.seek(Int(pageSize) - 4)

    try writer.writeUInt32(numNextEntryPage)

    return buffer
  }
}

extension BTreeEntryPage {
  init(data: Data) throws {
    let pageSize = data.count
    let buffer = FixedSizeBuffer(data: data)
    let reader = buffer.reader

    let contentLength = try reader.readUInt32()
    self.content = [UInt8]()

    for _ in 0..<contentLength {
      let char = try reader.readByte()
      self.content.append(char)
    }

    try reader.seek(Int(pageSize) - 4)
    self.numNextEntryPage = try reader.readUInt32()
  }
}
