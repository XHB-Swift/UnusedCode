//
//  Model.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/11/1.
//

import Foundation

public let PBX_FILE_TYPE_C_H = "sourcecode.c.h"
public let PBX_FILE_TYPE_C_OBJC = "sourcecode.c.objc"

extension String {
    
    public static let add =        "+"
    public static let minus =      "-"
    public static let lRBkt =      "("
    public static let rRBkt =      ")"
    public static let asterisk =   "*"
    public static let colon =      ":"
    public static let comma =      ","
    public static let semicolon =  ";"
    public static let slash =      "/"
    public static let lAgBkt =     "<"
    public static let rAgBkt =     ">"
    public static let quotation =  "\""
    public static let poundSign =  "#"
    public static let lBrace =     "{"
    public static let rBrace =     "}"
    public static let lSqrBkt =    "["
    public static let rSqrBkt =    "]"
    public static let question =   "?"
    public static let upArrow =    "^"
    
    
    public static let interface = "@interface"
    public static let implementation = "@implementation"
    public static let end = "@end"
    public static let `protocol` = "@protocol"
    public static let `optional` = "@optional"
    public static let required = "@required"
    public static let selector = "@selector"
    public static let property = "@property"
    public static let newLine = "\n"
    public static let space = " "
    
    public static let optr_symbols = [
        add, minus, lRBkt, rRBkt, asterisk, colon, comma, semicolon, slash, lAgBkt,
        rAgBkt, quotation, poundSign, lBrace, rBrace, lSqrBkt, rSqrBkt, question, upArrow
    ]
    
    public static let all_symbols = optr_symbols + [space]
}

public class ObjCSourceCodeSymbolManager {
    
    public static let manager = ObjCSourceCodeSymbolManager()
    public let objc_source_code_symbols: CharacterSet
    
    private init() {
        var optrSymbolStr = ""
        String.optr_symbols.forEach { optrSymbol in
            optrSymbolStr.append(optrSymbol)
        }
        var optrSymbols = CharacterSet(charactersIn: optrSymbolStr)
        optrSymbols.formUnion(.whitespacesAndNewlines)
        objc_source_code_symbols = optrSymbols
    }
    
    public func createSourceCodeTokens(from content: String) -> [String] {
        if content.isEmpty { return [] }
        let scanner = Scanner(string: content)
        var tokens = Array<String>()
        
        while !scanner.isAtEnd {
            for objcSymbol in String.optr_symbols {
                if scanner.scanString(objcSymbol) != nil {
                    tokens.append(objcSymbol)
                }
            }
            
            if let result = scanner.scanUpToCharacters(from: objc_source_code_symbols) {
                tokens.append(result)
            }
        }
        return tokens
    }
}

public protocol PbxObjectType: Hashable, Codable {
    
    var isa: String { set get }
}

public struct PbxSourceFile: PbxObjectType {
    
    public var isa = ""
    public var path = ""
    public var lastKnownFileType = ""
}

/// MARK: Objective-C类，协议和方法结构定义

public struct ObjCBlock: Hashable {
    
    // void(^)(BOOL isTokenFailed, NSString *info)
    // "void", "^", "BOOL", "isTokenFailed", "NSString", "*", "info"
    
    public var name = ""
    public var returnType = ""
    public var paramList = Array<String>()
    
    public static func == (lhs: ObjCBlock, rhs: ObjCBlock) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
}

public class ObjCMethod: Hashable, CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var methodProtoType = "\(type.rawValue) (\(returnType))"
        methodProtoType.append("\(tokenParamInfos.map{ $0.debugDescription }.joined(separator: " "))")
        if isUncertainParams {
            methodProtoType.append(", ...")
        }
        return methodProtoType
    }
    
    
    public static func == (lhs: ObjCMethod, rhs: ObjCMethod) -> Bool {
        return lhs.signature == rhs.signature
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(signature)
    }
    
    public enum MethodType: String {
        case unknown = ""
        case `class` = "+"
        case instance = "-"
    }
    
    public struct MethodToken: CustomDebugStringConvertible {
        
        public var token = "" //例： setObject
        public var type  = "" //例： id
        public var param = "" //例： object
        public var isBlockType = false
        
        // setObject:(id)object
        public var debugDescription: String {
            return !type.isEmpty ? "\(token)\(String.colon)(\(type))\(param)" : token
        }
    }
    
    ///默认使用
    public var isUsed = true
    ///是否为不定参数方法
    public var isUncertainParams = false
    ///类方法和实例方法
    public var type: MethodType = .unknown
    ///方法签名，例：- (void)setObject:(id)object forKey:(NSString *)key --> setObject:forKey:
    public var signature = ""
    ///返回类型
    public var returnType = ""
    ///方法碎片，例：- (void)setObject:(id)object forKey:(NSString *)key;
    public var tokenParamInfos = Array<MethodToken>()
    
    ///判断OC方法是否有参
    private var hasParams: Bool {
        let tokenCount = tokenParamInfos.count
        if tokenCount > 1 {
            return true
        }else if tokenCount == 1 {
            let token = tokenParamInfos.first
            return token?.param != nil && token?.param != ""
        }else {
            return false
        }
    }
    
    public func serializedSignature() {
        if !tokenParamInfos.isEmpty {
            if tokenParamInfos.count == 1 {
                signature = tokenParamInfos.first!.token
            }else {
                var tokens = tokenParamInfos
                while !tokens.isEmpty {
                    let token = tokens.removeFirst()
                    signature.append("\(token.token)\(token.type.isEmpty ? String.space : String.colon)")
                }
            }
        }
    }
    
    public func checkIsInvoked(in tokens: [String]) -> Bool {
        if tokens.isEmpty { return false }
        if signature.isEmpty { return false }
        
        //保留前一个匹配到的字符
        var previousToken = ""
        //@selector调用
        var isInSelector = false
        
        //[]调用，=0时表示匹配完成
        var sqrtBktCount = 0
        // %2 = 0时表示匹配完成
        var sqrtBktAppearedCount = 0
        //是否正在解析[]调用规则
        var isParsingSqrtBktInvoking = false
        //当前匹配的方法token是否有参数
        var matchedMethodHasColon = false
        //上一个token是否为:
        var isLastMatchedTokenColon = false
        
        //条件简写：?:
        var psSimpleCount = 0
        var isInSimple = false
        
        //当前方法是否有参数
        let hasParamToken = hasParams
        
        //是否匹配到了block参数
        var matchedBlock = false
        //回溯匹配，主要是针对block出现[]调用，先把block的内容保存起来再重新扫描
        var blockContentTokens = Array<String>()
        //block可能不止一个
        var blockContentTokenGroups = Array<Array<String>>()
        
        var detectedMethodFormat = Array<String>()
        for token in tokens {
            //@selector调用
            if isInSelector {
                if token == .colon {
                    if hasParamToken {
                        detectedMethodFormat.append(previousToken)
                    }else {
                        isInSelector = false
                        previousToken = ""
                        detectedMethodFormat.removeAll()
                        continue
                    }
                }else if token == .rRBkt {
                    isInSelector = false
                    let matchedMethodFormat: String
                    if hasParamToken {
                        matchedMethodFormat = detectedMethodFormat.joined(separator: ":").appending(":")
                    }else {
                        detectedMethodFormat.append(previousToken)
                        matchedMethodFormat = detectedMethodFormat.first ?? ""
                    }
                    detectedMethodFormat.removeAll()
                    if matchedMethodFormat == signature {
                        return true
                    }else {
                        continue
                    }
                }else {
                    previousToken = token
                }
                continue
            }
            if token == .selector {
                isInSelector = true
                detectedMethodFormat.removeAll()
                continue
            }
            //通用调用中匹配到block内容，先存起来
            if matchedBlock {
                blockContentTokens.append(token)
                if token == .rBrace {
                    matchedBlock = false
                    isLastMatchedTokenColon = false
                    blockContentTokenGroups.append(blockContentTokens)
                    blockContentTokens.removeAll()
                }
                continue
            }
            //通用调用
            if token == .lSqrBkt {
                if isInSimple {
                    psSimpleCount += 1
                }
                if sqrtBktCount == 0 {
                    matchedMethodHasColon = false
                }
                sqrtBktCount += 1
                sqrtBktAppearedCount += 1
                isParsingSqrtBktInvoking = true
                if sqrtBktCount > 1 { //出现了嵌套调用
                    detectedMethodFormat.removeAll()
                }
            }else if token == .rSqrBkt {
                
                if isInSimple {
                    psSimpleCount -= 1
                }
                sqrtBktCount -= 1
                sqrtBktAppearedCount += 1
                if !matchedMethodHasColon { //如果当前匹配的方法不是有参数的，将]前面的token捕获
                    detectedMethodFormat.append(previousToken)
                }
                //说明什么都没匹配到
                if detectedMethodFormat.isEmpty {
                    sqrtBktCount = 0
                    sqrtBktAppearedCount = 0
                    detectedMethodFormat.removeAll()
                    matchedMethodHasColon = false
                    isParsingSqrtBktInvoking = false
                    continue
                }
                let matchedMethodFormat = detectedMethodFormat.joined()
                //结束匹配[]，重置
                matchedMethodHasColon = false
                if matchedMethodFormat == signature {
                    return true
                }else {
                    detectedMethodFormat.removeAll()
                    continue
                }
                
            }else if token == .colon {
                if isInSimple && psSimpleCount == 0 {
                    isInSimple = false
                    matchedMethodHasColon = false
                    detectedMethodFormat.removeAll()
                    continue
                }
                
                matchedMethodHasColon = true
                isLastMatchedTokenColon = true
                if previousToken == .quotation || previousToken == "respondsToSelector" {
                    detectedMethodFormat.removeAll()
                    continue
                }
                if hasParamToken { //匹配的方法是有参数，则继续匹配
                    detectedMethodFormat.append("\(previousToken):")
                }else { //匹配的方法是无参数，但匹配到了:，说明这个方法不是目标方法，退出匹配
                    sqrtBktCount = 0
                    sqrtBktAppearedCount = 0
                    detectedMethodFormat.removeAll()
                    matchedMethodHasColon = false
                    isParsingSqrtBktInvoking = false
                    continue
                }
            }else if token == .question {
                isInSimple = true
            }else if token == .upArrow { //匹配到了block，常见出现位置：:^
                matchedBlock = isLastMatchedTokenColon
            }else {
                if !isParsingSqrtBktInvoking { continue }
                if isLastMatchedTokenColon { //上一个是:符号，跳过本次的token捕获
                    isLastMatchedTokenColon = false
                    continue
                }
                previousToken = token
            }
        }
        //上面匹配完一轮之后没有true，检查是否有block块可回溯内容
        if !blockContentTokenGroups.isEmpty {
            for tokens in blockContentTokenGroups {
                let check = checkIsInvoked(in: tokens)
                if check { return true }
            }
        }
        return false
    }
    
    public static func parse(from tokens: [String]) -> ObjCMethod? {
        if tokens.isEmpty { return nil }
        var bracketCount = 0
        //是否正在匹配括号的内容
        var isParsingBracket = false
        var prevoiusToken = ""
        let hasParamsMehtod = tokens.contains(.colon)
        var isParsingParamsType = false
        var isParsingParamsName = false
        var types = Array<String>()
        let method = ObjCMethod()
        var methodToken = MethodToken()
        for token in tokens {
            
            if (token == .minus || token == .add) && method.type == .unknown {
                method.type = (token == .minus) ? .instance : .class
            }else if token == .lRBkt {
                // - ((void)(^)(NSString *))block;
                bracketCount += 1
                isParsingBracket = true
            }else if token == .rRBkt {
                bracketCount -= 1
                if bracketCount == 0 {
                    var typeString = ""
                    if types.count == 1 {
                        typeString = types.first!
                    }else {
                        if !methodToken.isBlockType {
                            while !types.isEmpty {
                                let type = types.removeFirst()
                                let isLAgBkt = type == .lAgBkt
                                let isRAgBkt = type == .rAgBkt
                                let isAgBkt = (isLAgBkt || isRAgBkt)
                                if isAgBkt {
                                    let _ = typeString.removeLast()
                                }
                                typeString.append("\(type)")
                                if !isLAgBkt {
                                    typeString.append("\(String.space)")
                                }
                            }
                        }else {
                            while !types.isEmpty {
                                let type = types.removeFirst()
                                typeString.append(type)
                            }
                        }
                        let _ = typeString.removeLast()
                    }
                    if method.returnType.isEmpty {
                        method.returnType = typeString
                    }else {
                        if methodToken.isBlockType {
                            methodToken.type = typeString.appending(String.rRBkt)
                        }else {
                            methodToken.type = typeString
                        }
                    }
                    if isParsingParamsType {
                        isParsingParamsType = false
                        isParsingParamsName = true
                    }
                    isParsingBracket = false
                    types.removeAll()
                }
            }else if isParsingBracket {
                if token == .upArrow {
                    methodToken.isBlockType = true
                    types.append(contentsOf: [.lRBkt, token, .rRBkt, .lRBkt])
                }else {
                    types.append(token)
                    if !String.all_symbols.contains(token) && methodToken.isBlockType {
                        types.append(.space)
                    }
                }
            }else if token == .colon {
                isParsingParamsType = true
                methodToken.token = prevoiusToken
            }else if token == .semicolon {
                break
            }else if token == .comma { //匹配到逗号
                if !isParsingBracket { //不是在括号里面匹配到的，说明这个方法是个尾随多参方法，此时的匹配可认为已经结束
                    method.isUncertainParams = true
                    break
                }
            }else {
                if !method.returnType.isEmpty {
                    prevoiusToken = token
                    if !hasParamsMehtod { //此方法是无参数
                        methodToken.token = token
                        method.tokenParamInfos.append(methodToken)
                        methodToken = MethodToken()
                        break
                    }
                }
                if isParsingParamsName {
                    methodToken.param = token
                    isParsingParamsName = false
                    method.tokenParamInfos.append(methodToken)
                    methodToken = MethodToken()
                }
            }
        }
        method.serializedSignature()
        return method
    }
}

public class ObjCProtocol: Hashable {
    
    public var name = ""
    public var methods = Set<ObjCMethod>()
    
    public static func == (lhs: ObjCProtocol, rhs: ObjCProtocol) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

public class ObjCClassCategory: Hashable, CustomDebugStringConvertible {
    
    public var name = ""
    public var className = ""
    public var methods = Array<ObjCMethod>()
    
    public var debugDescription: String {
        var line1 = "\(String.interface) \(className) (\(name))"
        for method in methods {
            line1 = "\(line1)\n\(method)"
        }
        return "\(line1)\n\(String.end)"
    }
    
    public static func == (lhs: ObjCClassCategory, rhs: ObjCClassCategory) -> Bool {
        return (lhs.className == rhs.className) && (lhs.name == rhs.name)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(className)
        hasher.combine(name)
    }
    
    public func parseMethod(from tokens: [String]) {
        if let method = ObjCMethod.parse(from: tokens) {
            methods.append(method)
        }
    }
    
    public static func parse(tokens: [String]) -> ObjCClassCategory? {
        if tokens.isEmpty { return nil }
        var isCategoryDelcared = false
        var previousToken = ""
        var objcClassCategory: ObjCClassCategory?
        for token in tokens {
            if token == .lRBkt {
                isCategoryDelcared = true
                objcClassCategory = ObjCClassCategory()
                objcClassCategory?.className = previousToken
            }else if isCategoryDelcared {
                isCategoryDelcared = false
                objcClassCategory?.name = token
            }
            previousToken = token
        }
        return objcClassCategory
    }
}

public class ObjCProperty: Hashable, CustomDebugStringConvertible {
    
    public var name = ""
    public var type = ""
    public var isUsed = true
    public var isObjectType = false
    public var modifiers = Array<String>() // nonatomic strong assign
    
    public var debugDescription: String {
        return "\(String.property) (\(modifiers.joined(separator: ","))) \(type) \(isObjectType ? String.asterisk : "")\(name)"
    }
    
    public static func == (lhs: ObjCProperty, rhs: ObjCProperty) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func parse(tokens: Array<String>) -> ObjCProperty? {
        if tokens.isEmpty { return nil }
        let newProperty = ObjCProperty()
        var isInBkt = false
        var isInType = false
        var isInName = false
        var modifier = ""
        for token in tokens {
            
            if token == .lRBkt && !isInBkt {
                isInBkt = true
            }else if token == .comma && isInBkt {
                newProperty.modifiers.append(modifier)
            }else if token == .rRBkt && isInBkt {
                newProperty.modifiers.append(modifier)
                isInBkt = false
                modifier = ""
                isInType = true
                continue
            }else if isInBkt {
                modifier = token
            }
            
            if isInType && !isInName && (token != .lAgBkt || token != .rAgBkt) {
                newProperty.type = token
                isInName = true
                continue
            }
            if isInType && token == .lAgBkt {
                isInName = false
            }
            if isInType && token == .rAgBkt {
                isInName = true
                continue
            }
            if isInName && token != .asterisk && token != .semicolon {
                newProperty.name = token
            }
            if token == .asterisk {
                newProperty.isObjectType = true
            }
            
        }
        return newProperty
    }
}

public class ObjCClass: Hashable, CustomDebugStringConvertible {
    
    public var name = ""
    public var superClass = ""
    public var methods = Array<ObjCMethod>()
    public var properties = Array<ObjCProperty>()
    public var protocols = Array<ObjCProtocol>()
    public var categories = Array<ObjCClassCategory>()
    
    public var isUsed = true
    
    public var debugDescription: String {
        
        var classProtoType = "\(String.interface) \(name) \(String.colon) \(superClass) \(String.newLine)"
        
        if !properties.isEmpty {
            for property in properties {
                classProtoType.append("\(property)\(String.semicolon)\(String.newLine)")
            }
        }
        
        if !methods.isEmpty {
            for method in methods {
                classProtoType.append("\(method)\(String.semicolon)\(String.newLine)")
            }
        }
        
        classProtoType.append("\(String.end)\(String.newLine)")
        
        return classProtoType
    }
    
    public static func == (lhs: ObjCClass, rhs: ObjCClass) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public func parseProperty(from tokens: [String]) {
        if let property = ObjCProperty.parse(tokens: tokens) {
            properties.append(property)
        }
    }
    
    public func parseMethod(from tokens: [String]) {
        if let method = ObjCMethod.parse(from: tokens) {
            methods.append(method)
        }
    }
    
    public static func parseName(from line: String) -> (className: String, superClassName: String) {
        if line.isEmpty { return (className: "", superClassName: "") }
        if !(line.hasPrefix(.interface) && line.contains(String.colon)) { return (className: "", superClassName: "") }
        let isDeclareClass = line.hasPrefix(.interface)
        let aline = line.replacingOccurrences(of: String.interface, with: "")
        let declareClassTokens = ObjCSourceCodeSymbolManager.manager.createSourceCodeTokens(from: aline)
        return (className: declareClassTokens.first ?? "", superClassName: (isDeclareClass ? declareClassTokens[1] : ""))
    }
    
    public static func parseInterface(from line: String) -> ObjCClass? {
        let name = parseName(from: line)
        if name.className.isEmpty || name.superClassName.isEmpty { return nil }
        let newClass = ObjCClass()
        newClass.name = name.className
        newClass.superClass = name.superClassName
        return newClass
    }
    
    public static func parse(tokens: [String]) -> ObjCClass? {
        var objcClass: ObjCClass?
        if tokens.isEmpty { return objcClass }
        var previousToken = ""
        var isClassDeclared = false
        for token in tokens {
            if token == .colon {
                isClassDeclared = true
                objcClass = ObjCClass()
                objcClass?.name = previousToken
            }else if isClassDeclared {
                isClassDeclared = false
                objcClass?.superClass = token
            }
            previousToken = token
        }
        return objcClass
    }
}
