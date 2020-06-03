//
//  simpledb.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

enum SimpleDBError: Error {
  case invalidFilePath
  case writeInvalidPageSize
}

protocol PageReader {
  func readPage(at pageNumber: UInt32) throws -> Data
}

protocol PageWriter {
  func write(page: SimpleDBPage, at pageNumber: Int) throws
  @discardableResult func append(page: SimpleDBPage) throws -> Int
  func writeDatabaseHeader(_ page: SimpleDBHeader) throws
  var nextPageNumber: Int? { get }
}

enum SimpleDBPageAccessError: Error {
  case pageOverflow
  case invalidNumberOfPagesInHeader
}

final class SimpleDBPageAccess: PageReader, PageWriter {
  let fileHandle: RandomAccessFile
  private let pageSize: UInt32
  private var cachedPage = [Int: Data]()

  var nextPageNumber: Int? {
    // get next page number
    guard let header = try? SimpleDBHeader.read(from: fileHandle) else {
      return nil
    }
    let nextPageNumber = header.numberOfPages
    return Int(nextPageNumber)
  }

  init(fileHandle: RandomAccessFile, pageSize: UInt32) {
    self.fileHandle = fileHandle
    self.pageSize = pageSize
  }

  func readPage(at pageNumber: UInt32) throws -> Data {
    if let cached = cachedPage[Int(pageNumber)] {
      return cached
    }
//    print("\nRead page: \(pageNumber)")
    let offset = pageNumber * pageSize
    try fileHandle.seek(pos: UInt64(offset))
    let data = try fileHandle.read(offset: UInt64(offset), len: Int(pageSize))
    cachedPage[Int(pageNumber)] = data
    return data
  }

  func write(page: SimpleDBPage, at pageNumber: Int) throws {
//    print("\nWrite page: \(pageNumber)")
    let dataToWrite = try page.getBuffer(pageSize: pageSize)
    let offset = pageNumber * Int(pageSize)
    try fileHandle.seek(pos: UInt64(offset))
    try fileHandle.write(dataToWrite.data)
    cachedPage[pageNumber] = dataToWrite.data
  }

  func writeDatabaseHeader(_ page: SimpleDBHeader) throws {
    try write(page: page, at: 0)
  }

  @discardableResult func append(page: SimpleDBPage) throws -> Int {
    // get next page number
    var header = try SimpleDBHeader.read(from: fileHandle)
    let nextPageNumber = header.numberOfPages

    // append the actual page
    try write(page: page, at: Int(nextPageNumber))

    // Increase number of pages and write it back to file's header
    header.numberOfPages += 1
    try write(page: header, at: 0)

    return Int(nextPageNumber)
  }
}

protocol SimpleDBPage {
  func getBuffer(pageSize: UInt32) throws -> FixedSizeBuffer
}

protocol SimpleDB {
  static func open(filePath: String) throws -> Self
  func insert(_ value: String, for key: String) throws
  func content(for key: String) throws -> String?
  func delete(key: String) throws
}

final class BTreeSimpleDB: SimpleDB {

  private let filePath: String
  private var fileHandle: RandomAccessFile!
  private var pageWriter: PageWriter!
  private var pageReader: PageReader!

  private var databaseHeader: SimpleDBHeader!

  private var btree: BTree!

  init(filePath: String,
       fileHandle: RandomAccessFile,
       pageWriter: PageWriter,
       pageReader: PageReader) {
    self.fileHandle = fileHandle
    self.filePath = filePath
    self.pageWriter = pageWriter
    self.pageReader = pageReader
  }

  init(filePath: String) throws {
    self.filePath = filePath

    // Create master file
    try createMasterFileIfNeeded()

    // Read database header from file
    try readDatabaseHeader()

    print(self.databaseHeader)
    print("\n")

    initSimpleDBPageFileAccess()

    try initBtree()
  }

  static func open(filePath: String) throws -> BTreeSimpleDB {
    let db = try BTreeSimpleDB(filePath: filePath)
    return db
  }

  private func createMasterFileIfNeeded() throws {
    // Check file exist at path
    if FileManager.default.fileExists(atPath: filePath) == false {
      // Create new file
      FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

      try createFileHandle()

      try writeDatabaseHeaderAndRootNode()

    } else {
      try createFileHandle()
    }
  }

  private func createFileHandle() throws {
    // Initialize file random access to read database header data
    guard let fileHandle = RandomAccessFileImpl(filePath: filePath) else {
      throw SimpleDBError.invalidFilePath
    }

    self.fileHandle = fileHandle
  }

  private func initSimpleDBPageFileAccess() {
    let simpleDbFileAccess = SimpleDBPageAccess(fileHandle: fileHandle,
                                                pageSize: databaseHeader.pageSize)

    self.pageWriter = simpleDbFileAccess
    self.pageReader = simpleDbFileAccess
  }

  private func writeDatabaseHeaderAndRootNode() throws {
    let pageSize: UInt32 = 16 * 1024  // 4KB page size
    let btreeOrder: Int = 15
    let header = SimpleDBHeader(fileFormatVersion: 1,
                                numberOfPages: 1,
                                numberOfKeys: 0,
                                pageSize: pageSize,
                                btreeOrder: UInt32(btreeOrder), // maximum 10 childrens per node
                                numRootPage: 1,
                                lastFreeEntryPage: 0)

    try fileHandle.seek(pos: 0)

    // Temporary pageWriter to write the header and the root empty node only
    let pageWriter = SimpleDBPageAccess(fileHandle: fileHandle, pageSize: pageSize)

    try pageWriter.writeDatabaseHeader(header)

    let rootEmptyNode = BTreeNodePage(
      pageTypeFlag: GLB.FLAG_LEAF_PAGE,
      pageStatusFlag: GLB.FLAG_ACTIVE_PAGE,
      numberOfKeys: 0,
      numRightMostChildPage: 0
    )

    try pageWriter.append(page: rootEmptyNode)
  }

  private func readDatabaseHeader() throws {
    self.databaseHeader = try SimpleDBHeader.read(from: fileHandle)
  }

  private func initBtree() throws {
    let numRootPage = databaseHeader.numRootPage
    let rootPageData = try pageReader.readPage(at: numRootPage)
    let rootPage = try BTreeNodePage(data: rootPageData)
    self.btree = BTree(order: Int(databaseHeader.btreeOrder),
                       pageSize: Int(databaseHeader.pageSize),
                       rootNodePageNum: numRootPage,
                       rootNode: rootPage,
                       fileHandle: fileHandle,
                       writer: pageWriter,
                       reader: pageReader)
  }

  func insert(_ value: String, for key: String) throws {
    try btree.insert(value, for: key)

    // Refresh btree
    try initBtree()

    // Refresh database header
    try readDatabaseHeader()

     print("✅ Inserted key: \(key) and value: \(value)\n!")
  }

  func content(for key: String) throws -> String? {
    return try btree.content(for: key)
  }

  func delete(key: String) throws {

  }
}
