//
//  RandomAccessFile.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

protocol RandomAccessFile {
  func close() throws
  func seek(pos: UInt64) throws
  func getFilePointer() -> UInt64
  func write(_ data: Data) throws
  func read(offset: UInt64, len: Int) throws -> Data
}

class RandomAccessFileImpl: RandomAccessFile {
  private let fileHandle: FileHandle

  init?(filePath: String) {
    guard let fileHandle = FileHandle(forUpdatingAtPath: filePath) else {
      return nil
    }
    self.fileHandle = fileHandle
  }

  func write(_ data: Data) throws {
    fileHandle.write(data)
//    fileHandle.synchronizeFile()
  }

  func read(offset: UInt64, len: Int) throws -> Data {
    fileHandle.seek(toFileOffset: offset)
    return fileHandle.readData(ofLength: len)
  }

  func close() throws {
    fileHandle.closeFile()
  }

  func seek(pos: UInt64) throws {
    fileHandle.seek(toFileOffset: pos)
  }

  func getFilePointer() -> UInt64 {
    return fileHandle.offsetInFile
  }

  func availableData() -> Data {
    return fileHandle.availableData
  }
}
