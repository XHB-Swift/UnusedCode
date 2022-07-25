//
//  Preference.swift
//  UnusedCode
//
//  Created by xiehongbiao on 2021/11/15.
//

import Foundation

extension UserDefaults {
    
    public func scanMode() -> Bool {
        return (preference(for: "scanMode") as? Bool) ?? false
    }
    public func set(scanMode: Bool) {
        set(preference: scanMode, for: "scanMode")
    }
    
    
    private func set(preferenceInfo: [String : Any]) {
        set(preferenceInfo, forKey: "cc_unused_code_preference_info")
    }
    private func preferenceInfo() -> [String : Any]? {
        return object(forKey: "cc_unused_code_preference_info") as? [String : Any]
    }
    private func preference(for key: String) -> Any? {
        return preferenceInfo()?[key]
    }
    private func set(preference: Any, for key: String) {
        var info = preferenceInfo()
        if info == nil {
            info = Dictionary<String, Any>()
        }
        info?[key] = preference
        set(preferenceInfo: info!)
    }
}
