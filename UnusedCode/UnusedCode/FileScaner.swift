//
//  FileScaner.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/10/15.
//

import Foundation

private let File_Content_Annotation_Prefix_1 = "/*"
private let File_Content_Annotation_Suffix_2 = "*/"
private let File_Content_Annotation_Prefix_3 = "//"


public protocol FileScanerDelegate: AnyObject {
    
    func fileScanner(_ fileScanner: FileScaner, didFinish result: Result<Set<ObjCClass>, Error>)
}

//文件扫描器
public class FileScaner {
    
    public var path = ""
    public var fileName = ""
    public var scanMethod = false
    public var scanProperty = false
    public weak var delegate: FileScanerDelegate?
    
    private(set) var content = ""
    private(set) var lines = Array<String>()
    private(set) var tokens = Array<String>()
    private(set) var classes = Set<ObjCClass>()
    
    public init(content: String) {
        self.content = content
    }
    
    public func prepareContent() {
        if content.isEmpty { return }
        scanAnnotation()
        lines = content.components(separatedBy: CharacterSet.newlines).map { line in
            //确保可以正确获取到方法名
            if line.isEmpty || line.hasSuffix(.semicolon) || line.hasSuffix(.lBrace) { return line }
            var vline = line
            let _ = vline.removeLast()
            return vline
        }
        tokens = ObjCSourceCodeSymbolManager.manager.createSourceCodeTokens(from: content)
    }
    
    ///扫描清理注释
    private func scanAnnotation() {
        autoreleasepool {
            
            while (content.contains(File_Content_Annotation_Prefix_1)) {
                if let range1 = content.range(of: File_Content_Annotation_Prefix_1),
                   let range2 = content[range1.lowerBound ..< content.endIndex].range(of: File_Content_Annotation_Suffix_2) {
                    let annotationRange = range1.lowerBound ..< range2.upperBound
                    content = content.replacingCharacters(in: annotationRange, with: "")
                }
            }
            
            while (content.contains(File_Content_Annotation_Prefix_3)) {
                if let range1 = content.range(of: File_Content_Annotation_Prefix_3),
                   let range2 = content[range1.lowerBound ..< content.endIndex].range(of: "\n") {
                    let annotationRange = range1.lowerBound ..< range2.upperBound
                    content = content.replacingCharacters(in: annotationRange, with: "")
                }
            }
            
        }
    }
    
    //根据类名解析 @interface， @property和它的方法
    public func scanClassInfo(_ objcClass: ObjCClass) {
        
        var isInClass = false //标记当前是匹配类声明模式
        var isInCategory = false //标记当前是否为匹配分类模式
        var isInMethod = false //标记当前是否在匹配方法
        var isInImplementation = false //标记当前是否在类或分类声明实体
        var tmpObjcClassCategory: ObjCClassCategory?
        var methodTokens = Array<String>()
        for line in lines {
            if line.hasPrefix("\(String.poundSign)import") { continue } //排除掉#import
            let tokens = ObjCSourceCodeSymbolManager.manager.createSourceCodeTokens(from: line)
            if tokens.isEmpty { continue }
            //检测到@interface，可能是类声明，也可能是分类。Todo：暂不兼容类扩展
            if line.hasPrefix("\(String.interface) \(objcClass.name)") {
                if let _ = ObjCClass.parse(tokens: tokens) {
                    isInClass = true
                    continue
                }
                if let objcCategory = ObjCClassCategory.parse(tokens: tokens) {
                    isInCategory = true
                    objcClass.categories.append(objcCategory)
                    tmpObjcClassCategory = objcCategory
                    continue
                }
            }
            
            //检测到@implementation
            if line.hasPrefix("\(String.implementation) \(objcClass.name)") {
                isInImplementation = true
                continue
            }
            
            //开启扫描属性
            if scanProperty {
                if line.hasPrefix(.property) && (isInClass || isInCategory) {
                    objcClass.parseProperty(from: tokens)
                }
            }
            
            //开启扫描方法
            if scanMethod {
                if line.hasPrefix(.add) || line.hasPrefix(.minus) {
                    isInMethod = true
                    methodTokens.append(contentsOf: tokens)
                }else if isInMethod {
                    methodTokens.append(contentsOf: tokens)
                }
                
                if (line.hasSuffix(.semicolon) || line.hasSuffix(.lBrace)) && isInMethod {
                    isInMethod = false
                    if isInClass {
                        objcClass.parseMethod(from: methodTokens)
                    }else if isInCategory {
                        tmpObjcClassCategory?.parseMethod(from: methodTokens)
                    }
                    methodTokens.removeAll()
                }
            }
            
            //匹配到结束符
            if line.hasPrefix(.end) && (isInClass || isInCategory || isInImplementation) {
                if isInClass {
                    isInClass = false
                }else if isInCategory {
                    isInCategory = false
                }else if isInImplementation {
                    isInImplementation = false
                }
                continue
            }
        }
    }
    
    /// 扫描文件所有类
    public func scanAllClasses() {
        do {
            // 匹配类声明：@interface Test: NSObject
            let range = NSRange(location: 0, length: content.count)
            let regx = try NSRegularExpression(pattern: "\(String.interface) [A-Za-z0-9]{1,}\\s{0,1}\\:\\s{0,1}[A-Za-z0-9]{1,}", options: .caseInsensitive)
            let macthes = regx.matches(in: content, options: [], range: range)
            if macthes.isEmpty { return }
            macthes.forEach { checkingResult in
                
                guard let matchedString = content[checkingResult.range] else { return }
                let matchedClassPart = matchedString.replacingOccurrences(of: String.interface, with: "")
                let tokens = ObjCSourceCodeSymbolManager.manager.createSourceCodeTokens(from: matchedClassPart)
                if tokens.isEmpty { return }
                let objcClass = ObjCClass()
                var didMatchSuperClassName = false
                var previousToken = ""
                for token in tokens {
                    if token == .colon {
                        objcClass.name = previousToken
                        didMatchSuperClassName = true
                        continue
                    }else if didMatchSuperClassName {
                        didMatchSuperClassName = false
                        objcClass.superClass = token
                        break
                    }
                    previousToken = token
                }
                classes.insert(objcClass)
            }
            if classes.isEmpty { return }
            delegate?.fileScanner(self, didFinish: .success(classes))
        } catch {
            delegate?.fileScanner(self, didFinish: .failure(error))
        }
    }
    
    /// 检测类是否已使用
    public func scanUsedClass(with name: String) -> Bool {
        let invoked_rule_1 = "[\(name)"
        let invoked_rule_2 = "\(name)."
        let invoked_rule_3 = "\(name) *"
        let invoked_rule_4 = "\(name)*"
        let invoked_rule_5 = ":\(name)"
        let invoked_rule_6 = ": \(name)"
        let invoked_rule_7 = "@\"\(name)\""
        return content.contains(invoked_rule_1) ||
               content.contains(invoked_rule_2) ||
               content.contains(invoked_rule_3) ||
               content.contains(invoked_rule_4) ||
               content.contains(invoked_rule_5) ||
               content.contains(invoked_rule_6) ||
               content.contains(invoked_rule_7)
    }
    
    /// 检测方法是否使用
    public func scanUsedMethod(with method: ObjCMethod) -> Bool {
        if method.tokenParamInfos.isEmpty { return false }
        if method.tokenParamInfos.count == 1 { //如果方法只有一个签名块不需要进行下面的循环检查，直接全局匹配返回
            return content.contains(method.signature)
        }
        guard let appearedLine = lines.filter({ $0.contains(method.tokenParamInfos.first!.token) }).first,
              let index = lines.firstIndex(of: appearedLine) else { return false }
        let appearedContent = Array<String>(lines[index..<lines.count]).joined()
        let tokens = ObjCSourceCodeSymbolManager.manager.createSourceCodeTokens(from: appearedContent)
        return method.checkIsInvoked(in: tokens)
    }
    
}

