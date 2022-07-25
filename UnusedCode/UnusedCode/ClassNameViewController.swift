//
//  ClassNameViewController.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/11/11.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    
    static let allClassCell = NSUserInterfaceItemIdentifier(rawValue: "allClassCell")
}

class ClassNameViewController: NSViewController {
    
    @IBOutlet weak var allClassesTableView: NSTableView!
    
    let projectScanner = ProjectScanner()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        projectScanner.scannerDelegate = self
        projectScanner.shouldScanMethod = UserDefaults.standard.scanMode()
        
        
        
    }
    
    func showAlert(with title: String, message: String, buttonTitles: [String]) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttonTitles.forEach { buttonTitle in
            alert.addButton(withTitle: buttonTitle)
        }
        alert.runModal()
    }
    
}

extension ClassNameViewController: ProjectScannerDelegate {
    
    func projectScanner(_ scanner: ProjectScanner, didFinishScanningAt path: String?, newRows: IndexSet) {
        allClassesTableView.insertRows(at: newRows, withAnimation: .effectFade)
    }
    
    func projectScanner(_ scanner: ProjectScanner, didFinishScanningAt path: String?, shouldRefreshAt index: Int) {
        guard let splitVC = parent as? NSSplitViewController else { return }
        if let detailVC = splitVC.children[1] as? DetailViewController,
            let unusedClass = projectScanner.totalClassName(at: index) {
            detailVC.updateUnusedClass([unusedClass])
        }
    }
    
    func projectScanner(willBeginStatistics scanner: ProjectScanner) {
        
    }
    
    func projectScanner(didFinishStatistics scanner: ProjectScanner) {
        let totalCount = projectScanner.totalClassesCount
        showAlert(with: "统计项目类总数完成", message: "\(totalCount)", buttonTitles: ["确定"])
        projectScanner.startScanning()
    }
    
    func projectScanner(didFinishScanningFile scanner: ProjectScanner) {
        
    }
    
    func projectScanner(_ scanner: ProjectScanner, didFinishScanning unusedMethd: ObjCMethod) {
        guard let splitVC = parent as? NSSplitViewController else { return }
        if let detailVC = splitVC.children[1] as? DetailViewController {
           detailVC.updateUnusedMethod([unusedMethd])
        }
    }
    
}

extension ClassNameViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return projectScanner.totalClassesCount
    }
    
}

extension ClassNameViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableCellView = tableView.makeView(withIdentifier: .allClassCell, owner: nil) as? NSTableCellView
        
        if let className = projectScanner.totalClassName(at: row)?.name {
            tableCellView?.textField?.stringValue = className
        }
        
        return tableCellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard allClassesTableView.selectedRow != -1 else { return }
        guard let splitVC = parent as? NSSplitViewController else { return }
        if let detailVC = splitVC.children[1] as? DetailViewController,
            let objcClass = projectScanner.totalClassName(at: allClassesTableView.selectedRow) {
            detailVC.updateUnusedMethod(objcClass.methods)
        }
    }
    
}
