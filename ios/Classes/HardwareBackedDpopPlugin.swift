import Flutter
import CryptoKit
import Security

public class HardwareBackedDpopPlugin: NSObject, FlutterPlugin {
  private let dpopKeyTag = "com.example.hardware_backed_dpop.es256".data(using: .utf8)!

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hardware_backed_dpop",
      binaryMessenger: registrar.messenger()
    )
    let instance = HardwareBackedDpopPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getOrCreateBinding":
      getOrCreateBinding(result: result)
    case "getExistingBinding":
      getExistingBinding(result: result)
    case "signJwsSigningInput":
      signJwsSigningInput(call: call, result: result)
    case "deleteBinding":
      deleteBinding(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getOrCreateBinding(result: @escaping FlutterResult) {
    do {
      let key = try getOrCreateDpopPrivateKey()
      result(try buildDpopBinding(from: key))
    } catch {
      result(
        FlutterError(
          code: "DPOP_BINDING_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func getExistingBinding(result: @escaping FlutterResult) {
    do {
      guard let key = try getExistingDpopPrivateKey() else {
        result(nil)
        return
      }
      result(try buildDpopBinding(from: key))
    } catch {
      result(
        FlutterError(
          code: "DPOP_BINDING_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func signJwsSigningInput(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let signingInput = args["signingInput"] as? String,
          !signingInput.isEmpty else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "signingInput is required",
          details: nil
        )
      )
      return
    }

    do {
      let key = try getOrCreateDpopPrivateKey()
      var error: Unmanaged<CFError>?
      guard let signature = SecKeyCreateSignature(
        key,
        .ecdsaSignatureMessageX962SHA256,
        signingInput.data(using: .utf8)! as CFData,
        &error
      ) as Data? else {
        throw error?.takeRetainedValue() ?? NSError(
          domain: NSOSStatusErrorDomain,
          code: Int(errSecInternalError)
        )
      }
      let jose = try derEcdsaSignatureToJose(signature, outputLength: 64)
      result(base64URLEncode(jose))
    } catch {
      result(
        FlutterError(
          code: "DPOP_SIGN_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func deleteBinding(result: @escaping FlutterResult) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: dpopKeyTag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess || status == errSecItemNotFound {
      result(true)
    } else {
      result(
        FlutterError(
          code: "DPOP_DELETE_ERROR",
          message: "Failed to delete DPoP key (status: \(status))",
          details: nil
        )
      )
    }
  }

  private func getExistingDpopPrivateKey() throws -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: dpopKeyTag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnRef as String: true,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    switch status {
    case errSecSuccess:
      return item as! SecKey
    case errSecItemNotFound:
      return nil
    default:
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func getOrCreateDpopPrivateKey() throws -> SecKey {
    if let existing = try getExistingDpopPrivateKey() {
      return existing
    }

    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      .privateKeyUsage,
      &error
    ) else {
      throw error?.takeRetainedValue() ?? NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecInternalError)
      )
    }

    var attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: dpopKeyTag,
        kSecAttrAccessControl as String: accessControl,
      ],
    ]

#if !targetEnvironment(simulator)
    var secureEnclaveAttributes = attributes
    secureEnclaveAttributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
    if let key = SecKeyCreateRandomKey(secureEnclaveAttributes as CFDictionary, &error) {
      return key
    }
#endif

    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw error?.takeRetainedValue() ?? NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecInternalError)
      )
    }
    return key
  }

  private func buildDpopBinding(from privateKey: SecKey) throws -> [String: Any] {
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecInternalError),
        userInfo: [NSLocalizedDescriptionKey: "Unable to derive DPoP public key"]
      )
    }

    var error: Unmanaged<CFError>?
    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw error?.takeRetainedValue() ?? NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecInternalError)
      )
    }
    guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "Invalid P-256 public key representation"]
      )
    }

    let x = publicKeyData.subdata(in: 1..<33)
    let y = publicKeyData.subdata(in: 33..<65)
    let jwk: [String: String] = [
      "kty": "EC",
      "crv": "P-256",
      "x": base64URLEncode(x),
      "y": base64URLEncode(y),
    ]

    return [
      "rawPublicKey": base64URLEncode(publicKeyData),
      "jkt": computeJwkThumbprint(jwk),
      "jwk": jwk,
    ]
  }

  private func computeJwkThumbprint(_ jwk: [String: String]) -> String {
    let crv = jwk["crv"]!
    let kty = jwk["kty"]!
    let x = jwk["x"]!
    let y = jwk["y"]!
    let canonical = "{\"crv\":\"\(crv)\",\"kty\":\"\(kty)\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
    let digest = SHA256.hash(data: canonical.data(using: .utf8)!)
    return base64URLEncode(Data(digest))
  }

  private func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private func derEcdsaSignatureToJose(_ der: Data, outputLength: Int) throws -> Data {
    guard !der.isEmpty, der[der.startIndex] == 0x30 else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "Invalid DER ECDSA signature"]
      )
    }

    let sequenceInfo = try readASN1Length(der, offset: 1)
    var offset = sequenceInfo.nextOffset

    guard der[offset] == 0x02 else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "Invalid DER ECDSA signature (missing r)"]
      )
    }
    let rInfo = try readASN1Length(der, offset: offset + 1)
    let rRange = rInfo.nextOffset..<(rInfo.nextOffset + rInfo.length)
    let rData = der.subdata(in: rRange)
    offset = rRange.upperBound

    guard der[offset] == 0x02 else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "Invalid DER ECDSA signature (missing s)"]
      )
    }
    let sInfo = try readASN1Length(der, offset: offset + 1)
    let sRange = sInfo.nextOffset..<(sInfo.nextOffset + sInfo.length)
    let sData = der.subdata(in: sRange)

    let componentLength = outputLength / 2
    return try unsignedFixedLength(rData, size: componentLength) +
      unsignedFixedLength(sData, size: componentLength)
  }

  private func readASN1Length(_ data: Data, offset: Int) throws -> (length: Int, nextOffset: Int) {
    let first = Int(data[offset])
    if (first & 0x80) == 0 {
      return (first, offset + 1)
    }

    let byteCount = first & 0x7F
    guard byteCount > 0, byteCount <= 4 else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "Invalid ASN.1 length"]
      )
    }

    var length = 0
    for index in 0..<byteCount {
      length = (length << 8) | Int(data[offset + 1 + index])
    }
    return (length, offset + 1 + byteCount)
  }

  private func unsignedFixedLength(_ data: Data, size: Int) throws -> Data {
    let trimmed = data.drop { $0 == 0 }
    if trimmed.count > size {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "ECDSA component exceeds expected length"]
      )
    }
    return Data(repeating: 0, count: size - trimmed.count) + trimmed
  }
}
