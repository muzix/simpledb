//
//  BTree.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

enum BTreeError: Error {
  case numberOfKeyMismatch
}

class BTree {

  private let order: Int
  private let pageSize: Int
  private(set) var rootNodePageNum: UInt32
  private let fileHandle: RandomAccessFile
  private let writer: PageWriter
  private let reader: PageReader

  private(set) var root: BTreeNode

  init(order: Int,
       pageSize: Int,
       rootNodePageNum: UInt32,
       rootNode: BTreeNodePage,
       fileHandle: RandomAccessFile,
       writer: PageWriter,
       reader: PageReader) {
    self.order = order
    self.pageSize = pageSize
    self.rootNodePageNum = rootNodePageNum
    self.fileHandle = fileHandle
    self.writer = writer
    self.reader = reader
    self.root = BTreeNode(pageNum: rootNodePageNum,
                          page: rootNode,
                          btreeOrder: order,
                          pageSize: pageSize,
                          fileHandle: fileHandle,
                          writer: writer,
                          reader: reader)
  }

  func insert(_ value: String, for key: String) throws {
    try root.insert(value, key: key)

    if root.numberOfKeys > order - 1 {
      try splitRoot()
    }
  }

  func content(for key: String) throws -> String? {
    let value = try root.search(for: key)
    return value
  }

  private func splitRoot() throws {
    let middleIndex: Int = root.numberOfKeys / 2

    guard let middleCell = root.page.cells?[middleIndex] else {
      throw BTreeError.numberOfKeyMismatch
    }

    var leftChildPage = root.page!
    leftChildPage.numberOfKeys = UInt32(middleIndex)
    leftChildPage.numRightMostChildPage = middleCell.numChildPage
    if middleCell.numChildPage == 0 {
      leftChildPage.pageTypeFlag = BTreeNodePageType.leaf.rawValue
    } else {
      leftChildPage.pageTypeFlag = BTreeNodePageType.nonleaf.rawValue
    }
    let numberOfCellsToKeep = middleIndex
    leftChildPage.cells?.removeLast(Int(root.numberOfKeys) - numberOfCellsToKeep)

    let numLeftChild = try writer.append(page: leftChildPage)

    var rightChildPage = root.page!
    rightChildPage.numberOfKeys = UInt32(root.numberOfKeys) - UInt32(middleIndex + 1)
    rightChildPage.cells?.removeFirst(middleIndex + 1)
    if middleCell.numChildPage == 0 {
      rightChildPage.pageTypeFlag = BTreeNodePageType.leaf.rawValue
    } else {
      rightChildPage.pageTypeFlag = BTreeNodePageType.nonleaf.rawValue
    }

    let numRightChild = try writer.append(page: rightChildPage)

    var newRootPage = root.page!
    newRootPage.pageTypeFlag = BTreeNodePageType.nonleaf.rawValue
    newRootPage.numberOfKeys = 1
    newRootPage.numRightMostChildPage = UInt32(numRightChild)
    var newCell = middleCell
    newCell.numChildPage = UInt32(numLeftChild)
    newRootPage.cells = [newCell]

    try writer.write(page: newRootPage, at: Int(rootNodePageNum))

    root = BTreeNode(pageNum: rootNodePageNum,
                     page: newRootPage,
                     btreeOrder: order,
                     pageSize: pageSize,
                     fileHandle: fileHandle,
                     writer: writer,
                     reader: reader)
  }
}
