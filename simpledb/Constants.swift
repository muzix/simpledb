//
//  Constants.swift
//  simpledb
//
//  Created by muzix on 9/8/19.
//  Copyright © 2019 muzix. All rights reserved.
//

import Foundation

struct GLB {
  static let FLAG_NON_LEAF_PAGE: UInt8 = 0x02
  static let FLAG_LEAF_PAGE: UInt8 = 0x05

  static let FLAG_ACTIVE_PAGE: UInt8 = 0x01
  static let FLAG_INACTIVE_PAGE: UInt8 = 0x00

  static let BTREE_NODE_PAGE_HEADER_SIZE: Int = 10
}
