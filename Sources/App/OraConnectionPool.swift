//
//  OraConnectionPool.swift
//  
//
//  Created by Ilia Sazonov on 7/20/21.
//

import Foundation
import Vapor
import SwiftOracle

public struct OraConnectionPool {
    let pool: ConnectionPool
    
    init(tnsAlias: String, username: String, password: String, maxConn: Int) {
        let oracleService = OracleService(from_string: tnsAlias)
        pool = try! ConnectionPool(service: oracleService, user: username, pwd: password, maxConn: maxConn)
        pool.timeout = 180
        print("connection pool created with \(pool.openedCount) open connections")
    }
}

struct OraConnectionPoolKey: StorageKey {
    typealias Value = OraConnectionPool
}

public extension Application {
    var oraConnPool: OraConnectionPool {
        get {
            guard let pool = self.storage[OraConnectionPoolKey.self] else {
                fatalError("Connection Pool is not set up")
            }
            return pool
        }
        set {
            self.storage[OraConnectionPoolKey.self] = newValue
        }
    }
}


public extension Request {
    var oraConnPool: OraConnectionPool {
        guard let pool = self.application.storage[OraConnectionPoolKey.self] else {
            fatalError("Connection Pool is not set up")
        }
        return pool
    }
}
