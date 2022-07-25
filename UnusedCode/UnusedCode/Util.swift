//
//  Util.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/9/23.
//

import Foundation
import CryptoKit
import CommonCrypto

extension String {
    
    public var hexStringToInt: Int {
        return Int(self, radix: 16) ?? 0
    }
    
    subscript(i: Int) -> Self? {
        if i >= count {
            return nil
        }
        if i == 0 {
            return String(self[startIndex])
        }
        if i == count - 1 {
            return String(self[endIndex])
        }
        
        let targetIndex = index(startIndex, offsetBy: i)
        return String(self[targetIndex])
    }
    
    subscript(r: Range<Int>) -> Self? {
        if r.lowerBound < 0 {
            return nil
        }
        if r.lowerBound >= count {
            return nil
        }
        if r.upperBound > count {
            return nil
        }
        let index0 = index(startIndex, offsetBy: r.lowerBound)
        let index1 = index(startIndex, offsetBy: r.upperBound)
        return String(self[index0..<index1])
    }
    
    subscript(r: NSRange) -> Self? {
        guard let rr = Range(r) else { return nil }
        return self[rr]
    }
    
    public var objectClassName: String? {
        
        guard let space = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String else { return nil }
        return "\(space.replacingOccurrences(of: "-", with: "_")).\(self)"
    }
    
    public var md5String: String {
        if isEmpty { return self }
        if #available(iOS 13.0, *) {
            guard let d = self.data(using: .utf8) else { return "" }
            return Insecure.MD5.hash(data: d).map {
                String(format: "%02hhx", $0)
            }.joined()
        }else {
            let data = Data(utf8)
            let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
                var array = Array<UInt8>(repeating: 0, count: Int(CC_MD5_BLOCK_BYTES))
                CC_MD5(bytes.baseAddress, CC_LONG(data.count), &array)
                return array
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }
    
}

extension JSONDecoder {
    
    public func jsonToModel<T: Codable>(_ modelType: T.Type, _ object: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
        return try decode(modelType, from: data)
    }
}

extension JSONEncoder {
    
    public func modelToJsonData<T: Codable>(_ model: T, _ options: JSONSerialization.ReadingOptions) throws -> Data {
        return try encode(model)
    }
    
    public func modelToJsonObject<T: Codable>(_ model: T, _ options: JSONSerialization.ReadingOptions) throws -> Any {
        let data = try encode(model)
        return try JSONSerialization.jsonObject(with: data, options: options)
    }
    
    public func modelToJsonString<T: Codable>(_ model: T,
                                              _ options: JSONSerialization.ReadingOptions,
                                              _ encoding: String.Encoding = .utf8) throws -> String {
        let data = try modelToJsonData(model, options)
        return String(data: data, encoding: encoding) ?? ""
    }
}

