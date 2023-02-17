//
//  File.swift
//  
//
//  Created by Ilia Sazonov on 2/17/23.
//

import Foundation
import Vapor
import SwiftOracle

struct User: Authenticatable {
    var name: String
}

// This is a very "basic" Basic Authenticator, It relies on storing passowrds as clear text in the database. DO NOT use this in production!
struct UserAuthenticator: AsyncBasicAuthenticator {
    typealias User = App.User

    func authenticate(
        basic: BasicAuthorization,
        for request: Request
    ) async throws {
        if isAuthenticated(basicAuth: basic, for: request) {
            request.auth.login(User(name: "vapor"))
        }
    }
    
    func isAuthenticated(basicAuth: BasicAuthorization, for req: Request) -> Bool {
        req.logger.debug("starting user authentication in the database")
        // getting the connection pool descriptor from the request
        let conn = req.oraConnPool.pool.getConnection(tag: "")
        // making sure to return the connection upon exit
        defer {
            req.oraConnPool.pool.returnConnection(conn: conn)
        }
        
        let cursor: SwiftOracle.Cursor
        do {
            cursor = try conn.cursor()
            let sqlStr = "select 1 as authed from app_users where username = :u and passwd = :p"
            req.logger.debug("executing a query")
            try cursor.execute(sqlStr, params: [":u": BindVar(basicAuth.username), ":p": BindVar(basicAuth.password)])
            // fetch the data
            guard let row = cursor.fetchOneSwifty(), row["AUTHED"]?.int == 1 else {
                req.logger.debug("username and password combination did not match any record in the database")
                return false
            }
            req.logger.debug("username and password matched to a record in the database")
            return true // authenticated
        } catch {
            req.logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            return false
        }
    }
    
}

struct UserController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let protected = routes.grouped(UserAuthenticator())
        protected.get("me") { req -> String in
            let user = try req.auth.require(User.self)
            return "Success"
        }
    }
}
