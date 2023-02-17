//
//  File.swift
//
//
//  Created by Ilia Sazonov on 2/17/23.
//

import Foundation
import Vapor
import SwiftOracle

// This is a more robust Basic Authenticator, It relies on storing hashed passowrds and salts in the database.
struct UserAuthenticator2: AsyncBasicAuthenticator {
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
            let sqlStr = "select 1 as authed from app_users2 where username = :u and passwd_hash = dbms_crypto.hash(utl_i18n.string_to_raw(:p || passwd_salt, 'AL32UTF8'), 6)"
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

struct UserController2: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let protected = routes.grouped(UserAuthenticator2())
        protected.get("me2") { req -> String in
            let user = try req.auth.require(User.self)
            return "Success"
        }
    }
}
