//
//  AppDelegate.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/9/23.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var mainMenu: NSMenu!
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @IBAction func file_menu_open_action(_ sender: NSMenuItem) {
        
        let app = NSApplication.shared
        guard let window = app.mainWindow else { return }
        guard let splitVC = window.contentViewController as? NSSplitViewController else { return }
        guard let classNameVC = splitVC.children.first as? ClassNameViewController else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false //true for unit test
//        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.canChooseDirectories = true //false for unit test
//        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in
            
            if response != .OK { return }
            guard let path = panel.urls.first?.path else { return }
            classNameVC.projectScanner.shouldScanMethod = UserDefaults.standard.scanMode()
            classNameVC.projectScanner.projectPath = path
            classNameVC.projectScanner.prepareScanning()
            DispatchQueue.global().async {
//                self.testScan(path)
//                self.testScanClass(path)
            }
        }
    }
    
    func testScanClass(_ path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let content = String(data: data, encoding: .utf8) else { return }
            let fileScanner = FileScaner(content: content)
            fileScanner.scanMethod = true
            fileScanner.prepareContent()
            fileScanner.scanAllClasses()
            for classInfo in fileScanner.classes {
                fileScanner.scanClassInfo(classInfo)
            }
            print("class = \(fileScanner.classes)")
        } catch {
            print("error = \(error)")
        }
    }
    
    func testScan(_ path: String) {
        
        //- (void)showNot18UserAlert:(NSString *)title
                
                let objcMethod = ObjCMethod()
                objcMethod.type = .class
//                objcMethod.returnType = "void"
//                objcMethod.tokenParamInfos = [
//                    ObjCMethod.MethodToken(token: "cc_springAnimateWithFriction", type: "CGFloat", param: "friction", isBlockType: false),
//                    ObjCMethod.MethodToken(token: "tension", type: "CGFloat", param: "tension", isBlockType: false),
//                    ObjCMethod.MethodToken(token: "mass", type: "CGFloat", param: "mass", isBlockType: false),
//                    ObjCMethod.MethodToken(token: "initialSpringVelocity", type: "CGFloat", param: "initialSpringVelocity", isBlockType: false),
//                    ObjCMethod.MethodToken(token: "options", type: "UIViewAnimationOptions", param: "options", isBlockType: false),
//                    ObjCMethod.MethodToken(token: "animations", type: "void (^)(void)", param: "animations", isBlockType: true),
//                    ObjCMethod.MethodToken(token: "completion", type: "void (^_Nullable)(BOOL finished)", param: "completion", isBlockType: true)
//                ]
//        objcMethod.returnType = "CCOnlineAppConfigs *"
//        objcMethod.tokenParamInfos = [
//            ObjCMethod.MethodToken(token: "sharedAppConfigs")
//        ]
//        objcMethod.tokenParamInfos = [
//            ObjCMethod.MethodToken(token: "tipsViewShouldDisplayNext", type: "CCAudioHallPotentialConsumerEntranceTipsView *", param: "view")
//        ]
//        objcMethod.tokenParamInfos = [
//            ObjCMethod.MethodToken(token: "showNot18UserAlert", type: "NSString *", param: "title")
//        ]
        objcMethod.returnType = "BOOL"
        objcMethod.tokenParamInfos = [
            ObjCMethod.MethodToken(token: "isLogin")
        ]
                objcMethod.serializedSignature()
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    guard let content = String(data: data, encoding: .utf8) else { return }
                    let fileScanner = FileScaner(content: content)
                    fileScanner.prepareContent()
                    let check = fileScanner.scanUsedMethod(with: objcMethod)
                    print("check = \(check)")
                } catch {
                    print("error = \(error)")
                }
    }
    
}

