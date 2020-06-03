//
//  SimpleDBHeader.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

struct SimpleDBHeader: SimpleDBPage {
  static let databaseHeaderSize: Int = 36

  let headerLabel = "SimpleDB" // 8 bytes header label
  let fileFormatVersion: UInt32
  var numberOfPages: UInt32
  var numberOfKeys: UInt32
  let pageSize: UInt32
  let btreeOrder: UInt32
  var numRootPage: UInt32
  var lastFreeEntryPage: UInt32

  func getBuffer(pageSize: UInt32) throws -> FixedSizeBuffer {
    let buffer = FixedSizeBuffer(length: Int(pageSize))

    let writer = buffer.writer

    try writer.writeASCIIString(headerLabel, size: 8)
    try writer.writeUInt32(fileFormatVersion)
    try writer.writeUInt32(numberOfPages)
    try writer.writeUInt32(numberOfKeys)
    try writer.writeUInt32(pageSize)
    try writer.writeUInt32(btreeOrder)
    try writer.writeUInt32(numRootPage)
    try writer.writeUInt32(lastFreeEntryPage)

    return buffer
  }

  static func read(from fileHandle: RandomAccessFile) throws -> SimpleDBHeader {
    let headerData = try fileHandle.read(offset: 0, len: databaseHeaderSize)
    let buffer = FixedSizeBuffer(data: headerData)
    let dataReader = buffer.reader

    let _ = try dataReader.readASCIIString(ofSize: 8)
    let fileFormatVersion = try dataReader.readUInt32()
    let numberOfPages = try dataReader.readUInt32()
    let numberOfKeys = try dataReader.readUInt32()
    let pageSize = try dataReader.readUInt32()
    let btreeOrder = try dataReader.readUInt32()
    let numRootPage = try dataReader.readUInt32()
    let lastFreeEntryPage = try dataReader.readUInt32()

    return .init(fileFormatVersion: fileFormatVersion,
                 numberOfPages: numberOfPages,
                 numberOfKeys: numberOfKeys,
                 pageSize: pageSize,
                 btreeOrder: btreeOrder,
                 numRootPage: numRootPage,
                 lastFreeEntryPage: lastFreeEntryPage)
  }
}
