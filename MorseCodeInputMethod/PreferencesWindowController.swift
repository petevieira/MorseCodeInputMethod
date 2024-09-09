//
//  PreferencesWindowController.swift
//  MorseCodeInputMethod
//
//  Created by Pete Vieira on 9/9/24.
//

import Foundation
import AppKit

class PreferencesWindowController: NSWindowController {
//    @IBOutlet weak var typingDelaySlider: NSSlider!
    
    override var windowNibName: String {
        return "PreferencesWindow"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSLog("[MorseCodeInputMethod] Preferences window visible: \(window.isVisible)")
        } else {
            NSLog("No window found!")
        }

//        self.typingDelaySlider?.doubleValue = 1.0
//        typingDelaySlider?.doubleValue = UserDefaults.standard.double(forKey: "typingDelay") != 0 ?
//        UserDefaults.standard.double(forKey: "typingDelay") : 5.0
    }

//    @IBAction func typingDelayChanged(_ sender: NSSlider) {
//        UserDefaults.standard.set(sender.doubleValue, forKey: "typingDelay")
//        NSLog("Typing delay set to \(sender.doubleValue)")
//    }
}
