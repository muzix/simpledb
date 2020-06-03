//
//  BTreeNode.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

enum BTreeNodeError: Error {
  case wrongPageTypeFlag
  case wrongNumberOfKeys
}

final class BTreeNode {
  private let pageNum: UInt32
  private(set) var page: BTreeNodePage!
  private let fileHandle: RandomAccessFile
  private let writer: PageWriter
  private let reader: PageReader
  private let btreeOrder: Int
  private let pageSize: Int

  var numberOfKeys: Int {
    return Int(page.numberOfKeys)
  }

  init(pageNum: UInt32,
       page: BTreeNodePage,
       btreeOrder: Int,
       pageSize: Int,
       fileHandle: RandomAccessFile,
       writer: PageWriter,
       reader: PageReader) {
    self.pageNum = pageNum
    self.page = page
    self.btreeOrder = btreeOrder
    self.pageSize = pageSize
    self.fileHandle = fileHandle
    self.writer = writer
    self.reader = reader
  }

  var pageType: BTreeNodePageType {
    return BTreeNodePageType(rawValue: page.pageTypeFlag)!
  }

  var pageStatus: BTreePageStatus {
    return BTreePageStatus(rawValue: page.pageStatusFlag)!
  }

  var databaseHeader: SimpleDBHeader {
    return try! SimpleDBHeader.read(from: fileHandle)
  }

  func insert(_ value: String, key: String) throws {

    let newKey = key.lowercased()

    // Find position for the new key
    var indexForNewKey = 0
    if let cells = page.cells {
      let numberOfCells = cells.count
      var keyExisted = false
      while indexForNewKey < numberOfCells {
        let theKey = cells[indexForNewKey].key.lowercased()
        if theKey >= newKey {
          if theKey == newKey { keyExisted = true }
          break
        }
        indexForNewKey += 1
      }

      if indexForNewKey < numberOfCells && keyExisted {
        //TODO update cell's entry
        return
      }
    }

    switch pageType {
    case .leaf:
      var newPage = page!
      if newPage.cells == nil {
        newPage.cells = [BTreeCell]()
      }

      let numEntryPage = databaseHeader.lastFreeEntryPage
      var entryOffset: UInt32 = 0
      if numEntryPage != 0 {
        let entryPageData = try reader.readPage(at: UInt32(numEntryPage))
        let entryPage = try BTreeEntryPage(data: entryPageData)
        entryOffset = UInt32(entryPage.content.count)
      }

      try writeEntryIntoPageLinkedList(value: value)

      let newCell = BTreeCell(numChildPage: 0,
                              numEntryPage: numEntryPage == 0 ? 2 : numEntryPage,
                              entryOffset: entryOffset,
                              key: key)
      newPage.cells?.insert(newCell, at: indexForNewKey)
      newPage.numberOfKeys += 1
      try writer.write(page: newPage, at: Int(pageNum))
      page = newPage

    case .nonleaf:
      var numChildPage: UInt32 = 0
      if let cells = page.cells {
        if indexForNewKey < cells.count {
          numChildPage = cells[indexForNewKey].numChildPage
        } else if indexForNewKey == cells.count {
          numChildPage = page.numRightMostChildPage
        }
      }
      if numChildPage == 0 {
        throw BTreeNodeError.wrongPageTypeFlag
      }
      let childData = try reader.readPage(at: numChildPage)
      let childNodePage = try BTreeNodePage(data: childData)
      let childNode = BTreeNode(pageNum: numChildPage,
                                page: childNodePage,
                                btreeOrder: btreeOrder,
                                pageSize: pageSize,
                                fileHandle: fileHandle,
                                writer: writer, reader: reader)
      try childNode.insert(value, key: key)
      if childNode.numberOfKeys > btreeOrder - 1 {
        try splitChildNode(childNodeIndexInParent: indexForNewKey,
                           childNode: childNode,
                           childPageNum: Int(numChildPage))
      }
    }

  }

  private func readEntry(numEntryPage: Int, entryOffset: Int) throws -> BTreeEntry {
    var entryBuffer = [UInt8]()
    var nextEntryPageNum = numEntryPage
    var nextEntryOffset = Int(entryOffset)
    while nextEntryPageNum != 0 {
      let entryPageData = try reader.readPage(at: UInt32(nextEntryPageNum))
      let entryPage = try BTreeEntryPage(data: entryPageData)
      entryBuffer += Array(entryPage.content[nextEntryOffset..<entryPage.content.endIndex])
      nextEntryOffset = 0
      nextEntryPageNum = Int(entryPage.numNextEntryPage)
    }

    let entryData = Data(bytes: &entryBuffer, count: entryBuffer.count)
    let theEntry = try BTreeEntry(data: entryData)

    return theEntry
  }

  private func writeEntryIntoPageLinkedList(value: String) throws {
    let lastFreeEntryPageNum: Int = Int(databaseHeader.lastFreeEntryPage)

    let newEntry = BTreeEntry(val: value)
    let entryBufferBytes = try newEntry.getBuffer().data.bytes

    try appendEntry(entryBufferBytes, lastFreeEntryPageNum: lastFreeEntryPageNum)
  }

  private func appendEntry(_ content: [UInt8],
                           lastFreeEntryPageNum: Int) throws {
    // Insert new entry right after the last free entry page offset
    var entryPageToModify: BTreeEntryPage!
    var numEntryPageToModify: Int = lastFreeEntryPageNum
    if lastFreeEntryPageNum == 0 {
      entryPageToModify = BTreeEntryPage(content: [], numNextEntryPage: 0)
      numEntryPageToModify = try writer.append(page: entryPageToModify)
    } else {
      let lastEntryPageData = try reader.readPage(at: UInt32(lastFreeEntryPageNum))
      entryPageToModify = try BTreeEntryPage(data: lastEntryPageData)
    }

    entryPageToModify.content += content

    let availableSizeForContent = BTreeEntryPage.availableSizeForContent(pageSize: UInt32(pageSize))
    if entryPageToModify.content.count > availableSizeForContent {
      let remainingContent = Array(entryPageToModify.content[availableSizeForContent..<entryPageToModify.content.endIndex])
      entryPageToModify.content = Array(entryPageToModify.content[0..<availableSizeForContent])

      // Create empty next entry for the remaining
      let nextEmptyEntryPage = BTreeEntryPage(content: [], numNextEntryPage: 0)
      let nextEmptyEntryPageNum = try writer.append(page: nextEmptyEntryPage)

      // Link current entry to the next entry
      entryPageToModify.numNextEntryPage = UInt32(nextEmptyEntryPageNum)
      try writer.write(page: entryPageToModify, at: numEntryPageToModify)

      try appendEntry(remainingContent, lastFreeEntryPageNum: nextEmptyEntryPageNum)
    } else {
      try writer.write(page: entryPageToModify, at: numEntryPageToModify)
      var newDatabaseHeader = databaseHeader
      newDatabaseHeader.lastFreeEntryPage = UInt32(numEntryPageToModify)
      try writer.write(page: newDatabaseHeader, at: 0)
    }
  }

  /**
   * Child node will be divided into 2 nodes. The middle cell will be moved up to this current node.
   */
  private func splitChildNode(childNodeIndexInParent: Int,
                              childNode: BTreeNode,
                              childPageNum: Int) throws {
    let middleIndex: Int = childNode.numberOfKeys / 2

    guard let childCells = childNode.page.cells else {
      throw BTreeNodeError.wrongPageTypeFlag
    }

    guard middleIndex < childCells.count else {
      throw BTreeNodeError.wrongNumberOfKeys
    }

    // This cell will be moved up later in this method
    var middleCell = childCells[middleIndex]

    var newLeftPage = childNode.page!
    newLeftPage.numberOfKeys = UInt32(middleIndex)
    newLeftPage.numRightMostChildPage = middleCell.numChildPage
    newLeftPage.cells?.removeLast(childNode.numberOfKeys - middleIndex)

    // Write left page to same slot before
    try writer.write(page: newLeftPage, at: childPageNum)

    var newRightPage = childNode.page!
    newRightPage.numberOfKeys = UInt32(childNode.numberOfKeys - (middleIndex + 1))
    newRightPage.cells?.removeFirst(middleIndex + 1)

    let numRightPage = try writer.append(page: newRightPage)

    // Move middle cell into current node
    middleCell.numChildPage = UInt32(childPageNum)
    var newNode = self.page!
    newNode.numberOfKeys += 1
    newNode.cells?.insert(middleCell, at: childNodeIndexInParent)

    if childNodeIndexInParent + 1 < newNode.cells!.count {
      newNode.cells?[childNodeIndexInParent + 1].numChildPage = UInt32(numRightPage)
    } else {
      newNode.numRightMostChildPage = UInt32(numRightPage)
    }

    // Update current node data back to file
    try writer.write(page: newNode, at: Int(pageNum))

    page = newNode
  }
}

extension BTreeNode {
  func search(for key: String) throws -> String? {
    guard let cells = page.cells else { return nil }

    let allKeys = cells.map { $0.key }.joined(separator: ", ")
    print("\nThis node has \(allKeys) key")

    let searchKey = key.lowercased()

    var matchIndex = 0
    while matchIndex < cells.count {
      let theKey = cells[matchIndex].key.lowercased()

      if theKey == searchKey {
        let numEntryPage = cells[matchIndex].numEntryPage
        let entryOffset = cells[matchIndex].entryOffset
        let theEntry = try readEntry(numEntryPage: Int(numEntryPage), entryOffset: Int(entryOffset))
        return theEntry.val
      } else if theKey > searchKey {
        break
      }

      matchIndex += 1
    }

    var nextChildPage: UInt32 = 0

    if matchIndex < cells.count {
      nextChildPage = cells[matchIndex].numChildPage
    } else {
      nextChildPage = page.numRightMostChildPage
    }

    if nextChildPage != 0 {
      // Get page data of the next child
      let childPageData = try reader.readPage(at: nextChildPage)
      let childNodePage = try BTreeNodePage(data: childPageData)
      let childNode = BTreeNode(pageNum: nextChildPage,
                                page: childNodePage,
                                btreeOrder: btreeOrder,
                                pageSize: pageSize,
                                fileHandle: fileHandle,
                                writer: writer, reader: reader)

      return try childNode.search(for: key)
    }

    return nil
  }
}
