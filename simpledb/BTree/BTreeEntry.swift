//
//  BTreeEntry.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

struct BTreeEntry {
  let val: String

  func getBuffer() throws -> FixedSizeBuffer {
    let valLength = val.ASCIIBytes().count
    
    let buffer = FixedSizeBuffer(length: 4 + valLength)
    let writer = buffer.writer

    try writer.writeUInt32(UInt32(valLength))
    try writer.writeASCIIString(val, size: valLength)

    return buffer
  }
}

extension BTreeEntry {
  init(data: Data) throws {
    let buffer = FixedSizeBuffer(data: data)
    let reader = buffer.reader

    let lenVal = try reader.readUInt32()
    self.val = try reader.readASCIIString(ofSize: Int(lenVal))
  }
}
