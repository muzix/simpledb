//
//  BTreeNodePage.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

enum BTreeNodePageType: UInt8 {
  case nonleaf = 0x02
  case leaf = 0x05
}

enum BTreePageStatus: UInt8 {
  case active = 0x01
  case inactive = 0x02
}

/**
 * B-Tree Node Page
 */
struct BTreeNodePage: SimpleDBPage {

  /**
   * Page Type Flag
   *  - Non-leaf page: 2 (0x02)
   *  - Leaf page: 5 (0x05)
   */
  var pageTypeFlag: UInt8

  var pageStatusFlag: UInt8

  var numberOfKeys: UInt32

  var numRightMostChildPage: UInt32

  var cells: [BTreeCell]?

  func getBuffer(pageSize: UInt32) throws -> FixedSizeBuffer {
    let buffer = FixedSizeBuffer(length: Int(pageSize))

    let headerWriter = buffer.writer

    try headerWriter.writeByte(pageTypeFlag)
    try headerWriter.writeByte(pageStatusFlag)
    try headerWriter.writeUInt32(numberOfKeys)
    try headerWriter.writeUInt32(numRightMostChildPage)

    let cellWriter = buffer.writer
    // Move cursor to beginning of cell content section
    try cellWriter.seek(GLB.BTREE_NODE_PAGE_HEADER_SIZE)

    if let cells = self.cells {
      for cell in cells {
        let cellBuffer = try cell.getBuffer()
        try cellWriter.writeBuffer(cellBuffer)
      }
    }

    return buffer
  }
}

extension BTreeNodePage {
  init(data: Data) throws {
    let buffer = FixedSizeBuffer(data: data)
    let reader = buffer.reader

    self.pageTypeFlag = try reader.readByte()
    self.pageStatusFlag = try reader.readByte()
    self.numberOfKeys = try reader.readUInt32()
    self.numRightMostChildPage = try reader.readUInt32()

    var cells = [BTreeCell]()
    var index = 0
    var curOffset = reader.getOffset()
    while index < numberOfKeys {
      let cell = try BTreeCell(data: buffer.data[curOffset..<curOffset + Int(BTreeCell.cellSize)])
      cells.append(cell)
      index += 1
      curOffset += Int(BTreeCell.cellSize)
    }

    self.cells = cells.count == 0 ? nil : cells
  }
}
