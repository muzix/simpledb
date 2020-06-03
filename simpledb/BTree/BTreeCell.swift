//
//  BTreeCellPage.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

struct BTreeCell {
  var numChildPage: UInt32

  var numEntryPage: UInt32

  var entryOffset: UInt32

  var key: String

  static var cellSize: UInt32 {
    return 12 + 4 + 1024
  }

  func getBuffer() throws -> FixedSizeBuffer {
    let buffer = FixedSizeBuffer(length: Int(BTreeCell.cellSize))
    let writer = buffer.writer

    try writer.writeUInt32(numChildPage)
    try writer.writeUInt32(numEntryPage)
    try writer.writeUInt32(entryOffset)
    try writer.writeASCIIString(key)

    return buffer
  }
}

extension BTreeCell {
  init(data: Data) throws {
    let buffer = FixedSizeBuffer(data: data)
    let reader = buffer.reader
    self.numChildPage = try reader.readUInt32()
    self.numEntryPage = try reader.readUInt32()
    self.entryOffset = try reader.readUInt32()
    self.key = try reader.readASCIIString()
  }
}
