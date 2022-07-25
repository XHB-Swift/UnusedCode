//
//  DetailViewController.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/11/11.
//

import Cocoa

class DetailViewController: NSViewController {
    
    @IBOutlet weak var unusedClassTextView: NSTextView!
    @IBOutlet weak var unusedMethodTextView: NSTextView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func updateUnusedClass(_ classNames: [ObjCClass]) {
        var string = unusedClassTextView.string
        let attributes: [NSAttributedString.Key : Any] = [
            .font : NSFont.systemFont(ofSize: 14),
            .foregroundColor : NSColor.orange
        ]
        classNames.forEach { className in
            string.append("\(className.name)\n")
        }
        let attrString = NSMutableAttributedString(string: string, attributes: attributes)
        unusedClassTextView.textStorage?.setAttributedString(attrString)
    }
    
    func updateUnusedMethod(_ methods: [ObjCMethod]) {
        var string = unusedMethodTextView.string
        let attributes: [NSAttributedString.Key : Any] = [
            .font : NSFont.systemFont(ofSize: 14),
            .foregroundColor : NSColor.orange
        ]
        methods.forEach { method in
            string.append("\(method)\n")
        }
        let attrString = NSMutableAttributedString(string: string, attributes: attributes)
        unusedMethodTextView.textStorage?.setAttributedString(attrString)
        
    }
}
