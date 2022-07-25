//
//  PreferenceSettingsViewController.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/11/11.
//

import Cocoa

class PreferenceSettingsViewController: NSViewController {
    
    private var shouldScanUnusedMethod = false

    @IBOutlet weak var scanUnusedClassButton: NSButton!
    @IBOutlet weak var scanUnusedMethodButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        shouldScanUnusedMethod = UserDefaults.standard.scanMode()
        scanUnusedClassButton.state = shouldScanUnusedMethod ? .off : .on
        scanUnusedMethodButton.state = shouldScanUnusedMethod ? .on : .off
    }
    
    @IBAction func radioButtonChangedAction(_ sender: NSButton) {
        shouldScanUnusedMethod = (scanUnusedMethodButton.state == .on)
    }
    
    @IBAction func confirmAction(_ sender: NSButton) {
        UserDefaults.standard.set(scanMode: shouldScanUnusedMethod)
        dismiss(nil)
    }
}
