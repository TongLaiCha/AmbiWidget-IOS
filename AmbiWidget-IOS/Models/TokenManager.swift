//
//  TokenModel.swift
//  AmbiWidget-IOS
//
//  Created by Brandon Yuen on 27/11/2018.
//  Copyright © 2018 tonglaicha. All rights reserved.
//

import Foundation

enum TokenManagerError: Error {
	case noResultData(errorMessage: String)
	case resultHasError(errorMessage: String)
	case dataEncodingError(errorMessage: String)
	case jsonDecodingError(errorMessage: String)
}

class TokenManager {
	
	private init(){}
	
	private static let tokenUrl = "https://api.ambiclimate.com/oauth2/token"
	
	//
	// Authorises the app with an authCode by calling the Authentication API Endpoint
	//
	static func authenticateAndSaveTokens(with authCode: String, completion: @escaping (Error?, String?) -> Void) {
		
		// Construct & encode the redirect URL
		let queryString = "client_id=\(APISettings.clientID)&redirect_uri=\(APISettings.callbackURL)&code=\(authCode)&client_secret=\(APISettings.clientSecret)&grant_type=authorization_code"
		let url = URL(string: tokenUrl + "?" + queryString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)!
		
		print(">>> [URL] \(url)")
		
		// Authenticate in a background task and save access & refresh tokens
		URLSession.shared.dataTask(with: url) { (data, response, error) in
			do {
				if let error = error {
					throw error
				}
				struct Result: Codable {
					let refresh_token: String?
					let access_token: String?
					let expires_in: Int?
					let error: String?
				}
				
				// Decode retrieved data with JSONDecoder
				guard let data = data else { throw TokenManagerError.noResultData(errorMessage: "No result data found.")}
				let result = try JSONDecoder().decode(Result.self, from: data)
				print("<<< \(result)")
				
				// If there is an error in the result
				if let error = result.error {
					throw TokenManagerError.resultHasError(errorMessage: error)
				}
				
				// If the refresh or access tokens are not in the result
				guard let refreshToken = result.refresh_token, let accessToken = result.access_token, let expiresIn = result.expires_in else {
					throw TokenManagerError.noResultData(errorMessage: "No tokens found in result data.")
				}
				
				// Save tokens to user defaults
				try saveTokenToUserDefaults(token: Token(code: refreshToken, type: .refreshToken))
				try saveTokenToUserDefaults(token: Token(code: accessToken, type: .accessToken, expiresIn: expiresIn))
				
				completion(nil, nil)
				
			} catch {
				completion(error, String(describing: self))
			}
		}.resume()
	}
	
	//
	// Gets a new access token (UNTESTED) <<<<<<<<<<<<<<<<<<<<<
	//
	static func getNewAccessToken(with refreshTokenCode: String, completion: @escaping (Error?, String?) -> Void) {
		print("[getNewAccessToken]")
		
		// Construct & encode the redirect URL
		let queryString = "client_id=\(APISettings.clientID)&redirect_uri=\(APISettings.callbackURL)&refresh_token=\(refreshTokenCode)&client_secret=\(APISettings.clientSecret)&grant_type=refresh_token"
		let url = URL(string: tokenUrl + "?" + queryString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)!
		
		print(">>> [URL] \(url)")
		
		// Authenticate in a background task and save access & refresh tokens
		URLSession.shared.dataTask(with: url) { (data, response, error) in
			do {
				if let error = error {
					throw error
				}
				struct Result: Codable {
					let access_token: String?
					let expires_in: Int?
					let error: String?
				}
				
				// Decode retrieved data with JSONDecoder
				guard let data = data else { throw TokenManagerError.noResultData(errorMessage: "No result data found.")}
				let result = try JSONDecoder().decode(Result.self, from: data)
				print("<<< \(result)")
				
				// If there is an error in the result
				if let error = result.error {
					throw TokenManagerError.resultHasError(errorMessage: error)
				}
				
				// If the refresh or access tokens are not in the result
				guard let accessToken = result.access_token, let expiresIn = result.expires_in else {
					throw TokenManagerError.noResultData(errorMessage: "No access token or expiricy time found in result data.")
				}
				
				// Save tokens to user defaults
				try saveTokenToUserDefaults(token: Token(code: accessToken, type: .accessToken, expiresIn: expiresIn))
				
				completion(nil, nil)
				
			} catch {
				completion(error, String(describing: self))
			}
			}.resume()
	}
	
	//
	// Saves a token to UserDefaults based on it's Type
	//
	static func saveTokenToUserDefaults(token: Token) throws {
		let tokenAsJson = try token.asJson()
		UserDefaults.standard.set(tokenAsJson, forKey: token.type.defaultsKey)
		print("Saved '\(token.type)': \(token.code)")
	}
	
	//
	// Loads a Token from userDefaults based on it's type
	// returns nil if token could not be loaded (i.e. doesn't exist)
	//
	static func loadTokenFromUserDefaults(with tokenType: TokenType) throws -> Token? {
		
		// Load token from UserDefaults as Json, if unable to load, return nil for Token?
		guard let tokenAsJson = UserDefaults.standard.string(forKey: tokenType.defaultsKey) else {
			return nil
		}
		
		// Encode jsonString to Data
		guard let data = tokenAsJson.data(using: .utf8) else {
			throw TokenManagerError.dataEncodingError(errorMessage: "Could not encode json \(tokenAsJson) to Data")
		}
		
		// Decode the Data to a Token
		let token = try JSONDecoder().decode(Token.self, from: data)
		
		print("Loaded '\(tokenType)': '\(token.code)'")
		
		return token
	}
}