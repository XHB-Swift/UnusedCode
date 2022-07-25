//
//  ProjectScanner.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/10/29.
//

import Foundation
import OpenGL

public protocol ProjectScannerDelegate: AnyObject {
    
    func projectScanner(_ scanner: ProjectScanner, didFinishScanningAt path: String?, newRows: IndexSet)
    func projectScanner(_ scanner: ProjectScanner, didFinishScanningAt path: String?, shouldRefreshAt index: Int)
    func projectScanner(_ scanner: ProjectScanner, didFinishScanning unusedMethd: ObjCMethod)
    func projectScanner(willBeginStatistics scanner: ProjectScanner)
    func projectScanner(didFinishStatistics scanner: ProjectScanner)
    func projectScanner(didFinishScanningFile scanner: ProjectScanner)
}
 
//工程扫描
public class ProjectScanner: NSObject {
    
    private let fileManager = FileManager.default
    private let group = DispatchGroup()
    private let semephore = DispatchSemaphore(value: 1)
    private var projectTotalClasses = Array<ObjCClass>()
    private var projectTotalClassesGroups = Array<Array<ObjCClass>>()
    private var fileScanners = Array<FileScaner>()
    private var sourceCodeFiles = Set<PbxSourceFile>()
    //记录打开工程名
    private var projectName = ""
    //记录工程核心路径
    private var projectCorePath = ""
    //记录工程的.xcodeproj路径
    private var xcodeProjectPath = ""
    //记录工程的project.pbxproj信息
    private var projectFileInfo = Dictionary<String, Any>()
    
    private(set) var scanningFlag = false
    
    
    //将类总数分成5组处理
    public var threadCount = 3
    public var projectPath = ""
    public var shouldScanMethod = false
    public weak var scannerDelegate: ProjectScannerDelegate?
    
    public var totalClassesCount: Int {
        return projectTotalClasses.count
    }
    
    public var unusedClassesCount: Int = 0
    
    public func startScanning() {
        
        if projectPath.isEmpty || scanningFlag || projectTotalClasses.isEmpty { return }
        scanningFlag = true
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            
            let _ = strongSelf.group.wait(timeout: .distantFuture)
            strongSelf.scanUnusedClasses()
            let _ = strongSelf.group.wait(timeout: .distantFuture)
            
            if strongSelf.shouldScanMethod {
                
                let _ = strongSelf.group.wait(timeout: .distantFuture)
                strongSelf.scanUsedClassMethods()
                let _ = strongSelf.group.wait(timeout: .distantFuture)
                
                let _ = strongSelf.group.wait(timeout: .distantFuture)
                strongSelf.scanUnusedMethods()
                let _ = strongSelf.group.wait(timeout: .distantFuture)
            }
            
            
            DispatchQueue.main.async {
                print("Scanning finished")
                strongSelf.scannerDelegate?.projectScanner(didFinishScanningFile: strongSelf)
            }
        }
    }
    
    public func stopScanning() {
        let _ = semephore.wait(timeout: .distantFuture)
        scanningFlag = false
        let _ = semephore.signal()
    }
    
    public func totalClassName(at index: Int) -> ObjCClass? {
        return index < totalClassesCount ? projectTotalClasses[index] : nil
    }
    
    public func prepareScanning() {
        if projectPath.isEmpty || scanningFlag { return }
        scanningFlag = true
        scannerDelegate?.projectScanner(willBeginStatistics: self)
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.analysingCoreProject()
            strongSelf.analysingProjectSourceCodeFile()
            strongSelf.scanProjectClasses(at: strongSelf.projectCorePath)
            strongSelf.splitClassesToGroup()
            DispatchQueue.main.async {
                strongSelf.scanningFlag = false
                strongSelf.scannerDelegate?.projectScanner(didFinishStatistics: strongSelf)
            }
        }
    }
    
    private func splitClassesToGroup() {
        if totalClassesCount == 0 { return }
        let groupCount = totalClassesCount / threadCount
        let remainCount = totalClassesCount % threadCount
        for groupIdx in 0 ..< threadCount {
            var classesGroup = Array<ObjCClass>()
            let range = groupIdx * groupCount ..< (groupIdx + 1) * groupCount
            for index in range {
                if let objcClass = totalClassName(at: index) {
                    classesGroup.append(objcClass)
                }else {
                    print("missed index = \(index), totalClassesCount = \(totalClassesCount)")
                }
            }
            projectTotalClassesGroups.append(classesGroup)
        }
        if remainCount > 0 {
            for index in totalClassesCount - remainCount ..< totalClassesCount {
                projectTotalClassesGroups[0].append(projectTotalClasses[index])
            }
        }
        print("Grouping = \(projectTotalClassesGroups.count), files count = \(projectTotalClasses.count)")
    }
    
    private func analysingCoreProject() {
        do {
            let items = try fileManager.contentsOfDirectory(atPath: projectPath)
            for targetItem in items {
                let isTargetItem = targetItem.hasSuffix(".xcodeproj")
                if targetItem.hasSuffix(".xcworkspace") || isTargetItem {
                    
                    let path = "\(projectPath)/\(targetItem)"
                    if isTargetItem {
                        projectName = targetItem
                        projectCorePath = path.replacingOccurrences(of: ".xcodeproj", with: "")
                        xcodeProjectPath = path
                    }else {
                        projectName = targetItem.replacingOccurrences(of: ".xcworkspace", with: ".xcodeproj")
                        let contentPath = "\(path)/contents.xcworkspacedata"
                        let xmlData = try Data(contentsOf: URL(fileURLWithPath: contentPath))
                        let xmlParser = XMLParser(data: xmlData)
                        xmlParser.delegate = self
                        xmlParser.parse()
                    }
                    let projectFilePath = "\(xcodeProjectPath)/project.pbxproj"
                    let projectInfoData = try Data(contentsOf: URL(fileURLWithPath: projectFilePath))
                    let options = PropertyListSerialization.MutabilityOptions()
                    var format: PropertyListSerialization.PropertyListFormat = .binary
                    let projectInfo = try PropertyListSerialization.propertyList(from: projectInfoData, options: options, format: &format)
                    guard let dict = projectInfo as? [String : Any],
                          let object = dict["objects"] as? [String : Any] else { return }
                    projectFileInfo = object
                    return
                }
            }
        } catch {
            print("fetch items in path = \(projectPath), error = \(error)")
        }
    }
    
    private func analysingProjectSourceCodeFile() {
        if projectFileInfo.isEmpty { return }
        for (_, value) in projectFileInfo {
            if let dict = value as? [String : Any],
               let isa = dict["isa"] as? String,
               isa == "PBXFileReference",
               let fileType = dict["lastKnownFileType"] as? String,
               fileType == PBX_FILE_TYPE_C_H || fileType == PBX_FILE_TYPE_C_OBJC {
                do {
                    let sourceFile = try JSONDecoder().jsonToModel(PbxSourceFile.self, dict)
                    sourceCodeFiles.insert(sourceFile)
                } catch {
                    print("error = \(error)")
                }
            }
        }
    }
    
    private func scanProjectClasses(at path: String) {
        if path.isEmpty { return }
        do {
            let dirItems = try fileManager.contentsOfDirectory(atPath: path)
            if dirItems.isEmpty { return }
            for item in dirItems {
                if !scanningFlag { return }
                if item.hasSuffix(".xcassets") || item.hasSuffix(".bundle") || item.contains("Pods") { continue }
                var isDirectory = ObjCBool(false)
                let maybeFilePath = "\(path)/\(item)"
                let exist = fileManager.fileExists(atPath: maybeFilePath, isDirectory: &isDirectory)
                //非目标类型文件
                if exist && isDirectory.boolValue {
                    scanProjectClasses(at: maybeFilePath)
                }else {
                    //
                    if (item.hasSuffix(".h") || item.hasSuffix(".m")) && isTargetItem(item) {
                        let content = try String(contentsOfFile: maybeFilePath)
                        let fileScanner = FileScaner(content: content)
                        fileScanner.path = maybeFilePath
                        fileScanner.fileName = item
                        fileScanner.delegate = self
                        fileScanner.scanMethod = self.shouldScanMethod
                        fileScanners.append(fileScanner)
                        fileScanner.prepareContent()
                        fileScanner.scanAllClasses()
                    }
                }
            }
        } catch {
            print("prepareScanning: fetch dir items failed \(error)")
        }
    }
    
    private func isTargetItem(_ item: String) -> Bool {
        for file in sourceCodeFiles {
            if file.path == item {
                return true
            }
        }
        return false
    }
    
    private func scanUnusedClasses() {
        for classesGroup in projectTotalClassesGroups {
            DispatchQueue.global().async(group: group, execute: DispatchWorkItem(block: { [weak self] in
                
                guard let strongSelf = self else { return }
               
                for objcClass in classesGroup {
                    
                    autoreleasepool {
                        let className = objcClass.name
                        var reference = false
                        for fileScanner in strongSelf.fileScanners {
                            let fileName = fileScanner.fileName
                            let classHFileName = "\(className).h"
                            let classMFileName = "\(className).m"
                            if fileName == classHFileName || fileName == classMFileName { continue }
                            reference = fileScanner.scanUsedClass(with: className)
                            if reference { break }
                        }
                        if !reference {
                            DispatchQueue.main.sync {
                                objcClass.isUsed = false
                                let refreshIndex = strongSelf.projectTotalClasses.firstIndex(of: objcClass) ?? 0
                                strongSelf.scannerDelegate?.projectScanner(strongSelf, didFinishScanningAt: nil, shouldRefreshAt: refreshIndex)
                            }
                        }
                    }
                }
                
            }))
        }
    }
    
    private func scanUsedClassMethods() {
        let usedClasses = projectTotalClasses.filter { $0.isUsed }
        if usedClasses.isEmpty { return }
        let usedClassCount = usedClasses.count
        let groupCount = usedClassCount / threadCount
        let remainCount = usedClassCount % threadCount
        var usedClassesGroup = Array<Array<ObjCClass>>()
        for groupIdx in 0 ..< threadCount {
            var classesGroup = Array<ObjCClass>()
            for index in groupIdx * groupCount ..< (groupIdx + 1) * groupCount {
                classesGroup.append(usedClasses[index])
            }
            usedClassesGroup.append(classesGroup)
        }
        if remainCount > 0 {
            for index in usedClassCount - remainCount ..< usedClassCount {
                usedClassesGroup[0].append(usedClasses[index])
            }
        }
        for classGroup in usedClassesGroup {
            DispatchQueue.global().async(group: group, execute: DispatchWorkItem(block: { [weak self] in
                guard let strongSelf = self else { return }
                for usedClass in classGroup {
                    autoreleasepool {
                        for fileScanner in strongSelf.fileScanners {
                            if fileScanner.fileName.contains(usedClass.name) {
                                fileScanner.scanClassInfo(usedClass)
                            }
                        }
                    }
                }
            }))
        }
    }
    
    private func scanUnusedMethods() {
        let usedClasses = projectTotalClasses.filter { $0.isUsed }
        if usedClasses.isEmpty { return }
        let usedClassCount = usedClasses.count
        let groupCount = usedClassCount / threadCount
        let remainCount = usedClassCount % threadCount
        var usedClassesGroup = Array<Array<ObjCClass>>()
        for groupIdx in 0 ..< threadCount {
            var classesGroup = Array<ObjCClass>()
            for index in groupIdx * groupCount ..< (groupIdx + 1) * groupCount {
                classesGroup.append(usedClasses[index])
            }
            usedClassesGroup.append(classesGroup)
        }
        if remainCount > 0 {
            for index in usedClassCount - remainCount ..< usedClassCount {
                usedClassesGroup[0].append(usedClasses[index])
            }
        }
        for classGroup in usedClassesGroup {
            DispatchQueue.global().async(group: group, execute: DispatchWorkItem(block: { [weak self] in
                guard let strongSelf = self else { return }
                for usedClass in classGroup {
                    for usedMethod in usedClass.methods {
                        autoreleasepool {
                            var used = false
                            for fileScanner in strongSelf.fileScanners {
                                if !fileScanner.fileName.hasSuffix(".m") { continue }
                                used = fileScanner.scanUsedMethod(with: usedMethod)
                                if used { break }
                            }
                            if !used {
                                DispatchQueue.main.sync {
                                    usedMethod.isUsed = used
                                    strongSelf.scannerDelegate?.projectScanner(strongSelf, didFinishScanning: usedMethod)
                                }
                            }
                        }
                    }
                    for category in usedClass.categories {
                        for usedMethod in category.methods {
                            autoreleasepool {
                                var used = false
                                for fileScanner in strongSelf.fileScanners {
                                    if !fileScanner.fileName.hasSuffix(".m") { continue }
                                    used = fileScanner.scanUsedMethod(with: usedMethod)
                                    if used { break }
                                }
                                if usedMethod.debugDescription == "- (void)" {
                                    print("category = \(category), usedClass = \(usedClass)")
                                }
                                if !used {
                                    DispatchQueue.main.sync {
                                        usedMethod.isUsed = used
                                        strongSelf.scannerDelegate?.projectScanner(strongSelf, didFinishScanning: usedMethod)
                                    }
                                }
                            }
                        }
                    }
                }
            }))
        }
    }
}

extension ProjectScanner: FileScanerDelegate {
    
    public func fileScanner(_ fileScanner: FileScaner, didFinish result: Result<Set<ObjCClass>, Error>) {
        switch result {
        case .success(let result):
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                if result.isEmpty { return }
                var currentSet = Set<ObjCClass>(strongSelf.projectTotalClasses)
                let currentCount = strongSelf.totalClassesCount
                let newCount = result.count + currentCount
                currentSet.formUnion(result)
                if currentSet.count == currentCount { return }
                strongSelf.projectTotalClasses.removeAll()
                strongSelf.projectTotalClasses.append(contentsOf: currentSet)
                strongSelf.scannerDelegate?.projectScanner(strongSelf,
                                                           didFinishScanningAt: fileScanner.path,
                                                           newRows:IndexSet(integersIn: currentCount ..< newCount))
            }
        case .failure(let error):
            print("file = \(fileScanner.path), error = \(error)")
        }
    }
    
}

extension ProjectScanner: XMLParserDelegate {
    
    public func parserDidStartDocument(_ parser: XMLParser) {
        
    }
    
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String : String] = [:]) {
        if elementName == "FileRef",
            let location = attributeDict["location"],
            location.contains(projectName) {
            
            let relativeProjectPath = location.replacingOccurrences(of: "group:", with: "")
            projectCorePath = "\(projectPath)/\(projectName.replacingOccurrences(of: ".xcodeproj", with: ""))"
            xcodeProjectPath = "\(projectPath)/\(relativeProjectPath)"
            parser.abortParsing()
        }
    }
    
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        
    }
    
    public func parserDidEndDocument(_ parser: XMLParser) {
        
    }
    
}
