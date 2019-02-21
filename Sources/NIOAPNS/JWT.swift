//
//  JWT.swift
//  Kyle Browning
//
//  Created by Kyle Browning on 1/10/19.
//

import Foundation

public struct JWT: Codable {

    private struct Payload: Codable {
        /// iss
        public let teamID: String
        
        /// iat
        public let issueDate: Int
        
        enum CodingKeys: String, CodingKey {
            case teamID = "iss"
            case issueDate = "iat"
        }
    }
    private struct Header: Codable {
        /// alg
        let algorithm: String = "ES256"
        
        /// kid
        let keyID: String
        
        enum CodingKeys: String, CodingKey {
            case keyID = "kid"
            case algorithm = "alg"
        }
    }
    
    private let header: Header
    
    private let payload: Payload
    
    public init(keyID: String, teamID: String, issueDate: Date, expireDuration: TimeInterval) {
        header = Header(keyID: keyID)
        let iat = Int(issueDate.timeIntervalSince1970.rounded())
        payload = Payload(teamID: teamID, issueDate: iat)
    }
    
    /// Combine header and payload as digest for signing.
    public func digest() throws -> String {
        let headerString = try JSONEncoder().encode(header.self).base64EncodedURLString()
        let payloadString = try JSONEncoder().encode(payload.self).base64EncodedURLString()
        return "\(headerString).\(payloadString)"
    }
    
    /// Sign digest with SigningMode. Use the result in your request authorization header.
    public func sign(with signingMode: SigningMode) throws -> String {
        // TODO: Dont force unwrap, and properly throw errors
        let digest = try self.digest()
        let fixedDigest = sha256(message: digest.data(using: .utf8)!)
        var signature: Data
        switch signingMode {
        case .file(let filepath):
            let fileSigner = FileSigner(url: URL.init(fileURLWithPath: filepath))!
            signature = try! fileSigner.sign(digest: fixedDigest)
        case .data(let data):
            let dataSigner = DataSigner(data: data)!
            signature = try! dataSigner.sign(digest: fixedDigest)
        case .custom(let signer):
            signature = try! signer.sign(digest: fixedDigest)
        }

        return digest + "." + signature.base64EncodedURLString()
    }
}
