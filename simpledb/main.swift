//
//  main.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

enum UserAction: String {
  case insert = "1"
  case insertLargeText = "2"
  case search = "3"
  case exit = "4"
}

fileprivate let packageRootPath = URL(fileURLWithPath: #file)
  .pathComponents
  .dropFirst()
  .dropLast(2)
  .joined(separator: "/")

var encyclopedia: SimpleDB!


class Program {
  static func openDBConnection() {
    print(packageRootPath)
    do {
      let dbFilePath = URL(string: "/\(packageRootPath)/encyclopedia.simpledb")!
      let db: SimpleDB = try BTreeSimpleDB.open(filePath: dbFilePath.path)
      encyclopedia = db
    } catch {
      print(error)
    }
  }

  static func importData() {
    let importFilePath = URL(string: "/\(packageRootPath)/import.txt")!
    let lineReader = TextFileReader(url: importFilePath)!
    var imported = 0
    while true {
      guard let line = lineReader.nextLine() else {
        break
      }
      do {
        try autoreleasepool {
          let word = line.trimmingCharacters(in: .whitespacesAndNewlines)
          try encyclopedia.insert(word, for: word)
        }
      } catch {
        print(error)
      }
      imported += 1
    }
    print("\n✅ All words imported: \(imported)!")
  }

  static func main() {
    while(true) {

      print("Welcome to English encyclopedia\n")
      print("1. Insert new word/phrase...")
      print("2. Insert a Lorem ipsum large text...")
      print("3. Search for word/phrase...")
      print("4. Exit\n")

      print("Please enter your action [1-4]: ")
      let action = readLine()

      guard let actionString = action,
        let userAction = UserAction(rawValue: actionString) else {
        continue
      }

      switch userAction {
      case .insert:
        processInsertion()
      case .insertLargeText:
        processInsertionLargeText()
      case .search:
        processSearching()
      case .exit:
        exit(0)
      }

      toBeContinue()
    }
  }

  static func processInsertion() {
    print("\nPlease enter the word/phrase: ")
    let word = readLine()
    print("\nPlease enter the explanation: ")
    let explanation = readLine()

    if let key = word {
      do {
        try encyclopedia.insert(explanation ?? "", for: key)
      } catch {
        print(error)
      }
    }
  }

  static func processInsertionLargeText() {
    print("\nPlease enter the keyword for this large text: ")
    let word = readLine()

    if let key = word {
      do {
        try encyclopedia.insert(TEXT.LOREM_IPSUM_TEXT, for: key)
      } catch {
        print(error)
      }
    }
  }

  static func processSearching() {
    print("\nPlease enter the word/phrase: ")
    let word = readLine()

    if let w = word {
      do {
        if let explanation = try encyclopedia.content(for: w) {
          print("\n✅ The word \"\(w)\" means: \"\(explanation)\"")
        } else {
          print("\n❌ No result for the word \"\(w)\"\n")
        }
      } catch {
        print(error)
      }
    }
  }

  static func toBeContinue() {
    print("\nPress enter to continue...\n")
    readLine()
  }
}

Program.openDBConnection()
//Program.importData()
Program.main()


