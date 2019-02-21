//
//  DataSigner.swift
//  NIOAPNS
//
//  Created by Kyle Browning on 2/21/19.
//

import Foundation
import CAPNSOpenSSL

public class DataSigner: Signer {
    private let opaqueKey: OpaquePointer

    public init?(data: Data) {
        let bio = BIO_new(BIO_s_mem())
        defer { BIO_free(bio) }

        let nullTerminatedData = data + Data(bytes: [0])
        _ = nullTerminatedData.withUnsafeBytes { key in
            return BIO_puts(bio, key)
        }

        let read: (UnsafeMutableRawPointer?) -> OpaquePointer? = { u in PEM_read_bio_ECPrivateKey(bio!, nil, nil, u) }

        let pointer: OpaquePointer?
        pointer = read(nil)

        BIO_free(bio!)

        if let pointer = pointer {
            self.opaqueKey = pointer
        } else {
            return nil
        }
    }

    deinit {
        EC_KEY_free(opaqueKey)
    }

    public func sign(digest: Data) throws -> Data  {
        let sig = digest.withUnsafeBytes { ptr in ECDSA_do_sign(ptr, Int32(digest.count), opaqueKey) }
        defer { ECDSA_SIG_free(sig) }

        var derEncodedSignature: UnsafeMutablePointer<UInt8>? = nil
        let derLength = i2d_ECDSA_SIG(sig, &derEncodedSignature)

        guard let derCopy = derEncodedSignature, derLength > 0 else {
            throw APNSSignatureError.invalidAsn1
        }

        var derBytes = [UInt8](repeating: 0, count: Int(derLength))

        for b in 0..<Int(derLength) {
            derBytes[b] = derCopy[b]
        }
        return Data(derBytes)
    }

    public func verify(digest: Data, signature: Data) -> Bool {
        var signature = signature
        let sig = signature.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UnsafeMutablePointer<ECDSA_SIG> in
            var copy = Optional.some(ptr)
            return d2i_ECDSA_SIG(nil, &copy, signature.count)
        }

        defer { ECDSA_SIG_free(sig) }

        let result = digest.withUnsafeBytes { ptr in
            return ECDSA_do_verify(ptr, Int32(digest.count), sig, opaqueKey)
        }

        return result == 1
    }
}
