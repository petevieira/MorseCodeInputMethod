//
//  MorseCodeInputMethodController.swift
//  MorseCodeInputMethod
//
//  Created by Pete Vieira on 8/28/24.
//

import Cocoa
import InputMethodKit

@objc(MorseCodeInputMethodController)
class MorseCodeInputMethodController: IMKInputController {
    private var currentMorseCode = ""

    private var keyDownTimestamp: TimeInterval?
    private var keyUpTimestamp: TimeInterval?

    private let ditThresholdSec = 0.15
    private let charThresholdSec = 0.9
    private let wordThresholdSec = 1.05
    private let proportionalGain = 0.75
    
    var morseTimer: Timer?

    var eventTap: CFMachPort?
    
    override init!(server: IMKServer, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        setupEventTap()
    }
    
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0), .commonModes)
        }
    }
    
    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        return false
    }
    
    func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,  // Event tap location
            place: .headInsertEventTap,  // Insert at the head of the event stream
            options: .defaultTap,  // Default options
            eventsOfInterest: CGEventMask(eventMask),  // Event mask
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // No need for optional unwrapping since `event` is already non-optional
                _ = Unmanaged<MorseCodeInputMethodController>.fromOpaque(refcon!).takeUnretainedValue()
                return MorseCodeInputMethodController.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            NSLog("Failed to create event tap")
        }
    }
    
    static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        let controller = Unmanaged<MorseCodeInputMethodController>.fromOpaque(refcon!).takeUnretainedValue()

        switch type {
        case .keyDown:
            // Invalidate the existing timer if any
            controller.morseTimer?.invalidate()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // Detect if the backspace key is pressed
            if keyCode == 51 {  // 51 is the keyCode for the backspace key
                controller.handleBackspace()
                return Unmanaged.passUnretained(event)
            }
            controller.handleKeyDown(event)
            return nil
        case .keyUp:
            controller.handleKeyUp(event)
            return nil
        default:
            break
        }
        
        return nil
    }

    func handleKeyDown(_ event: CGEvent) {
        // Record the time the key was pressed
        self.keyDownTimestamp = TimeInterval(event.timestamp)
    }
    
    func handleKeyUp(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Ignore keyUp event for backspace
        if keyCode == 51 {
            return
        }
        
        self.keyUpTimestamp = TimeInterval(event.timestamp)
        var duration: Double = 0.0
        
        // Convert the time difference to seconds
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)

        if let keyDownTime = keyDownTimestamp {
            let timestampDifference = self.keyUpTimestamp! - keyDownTime
            let convertedDifference = Double(timestampDifference) * Double(timebaseInfo.numer)
            duration = convertedDifference / Double(timebaseInfo.denom) / 1_000_000_000
        } else {
            return
        }

        var morseSymbol = ""
        if (duration < self.ditThresholdSec * proportionalGain) {
            morseSymbol = "."
        } else {
            morseSymbol = "-"
        }

        // Process the Morse code symbol
        self.currentMorseCode.append(morseSymbol)
        
        // Reset the timestamp
        self.keyUpTimestamp = nil
        
        // Start a new timer to process the Morse code if no further input is detected within the threshold
        self.morseTimer = Timer.scheduledTimer(timeInterval: self.charThresholdSec * proportionalGain, target: self, selector: #selector(self.handleCharTimeout), userInfo: nil, repeats: false)
    }
    
    @objc func handleCharTimeout() {
        // Assume the end of a character and process the Morse code
        self.translateMorseCode()

        // Start new timer to process spaces between words
        self.morseTimer = Timer.scheduledTimer(timeInterval: self.wordThresholdSec * proportionalGain, target: self, selector: #selector(self.handleWordTimeout), userInfo: nil, repeats: false)
    }
    
    @objc func handleWordTimeout() {
        guard let inputClient = self.client() else { return }
        inputClient.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    func translateMorseCode() {
        // Translate the current Morse code into a character
        guard let inputClient = self.client() else { return }
        
    
        if let character = self.MorseCodeDictionary[self.currentMorseCode] {
            inputClient.insertText(character, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        } else {
            NSLog("Unrecognized Morse code: \(self.currentMorseCode)")
        }
        
        // Clear the current Morse code after translation
        self.currentMorseCode.removeAll()
    }
    
    // Morse code to character dictionary
    let MorseCodeDictionary: [String: String] = [
        ".-"    : "A", "-..."  : "B", "-.-."  : "C", "-.."   : "D", "."     : "E",
        "..-."  : "F", "--."   : "G", "...."  : "H", ".."    : "I", ".---"  : "J",
        "-.-"   : "K", ".-.."  : "L", "--"    : "M", "-."    : "N", "---"   : "O",
        ".--."  : "P", "--.-"  : "Q", ".-."   : "R", "..."   : "S", "-"     : "T",
        "..-"   : "U", "...-"  : "V", ".--"   : "W", "-..-"  : "X", "-.--"  : "Y",
        "--.."  : "Z", "-----" : "0", ".----" : "1", "..---" : "2", "...--" : "3",
        "....-" : "4", "....." : "5", "-...." : "6", "--..." : "7", "---.." : "8",
        "----." : "9", ".-.-.-": ".", "--..--": ",", "..--.." : "?", ".----.": "'",
        "-.-.--": "!", "-..-." : "/", "-.--." : "(", "-.--.-": ")", ".-..." : "&",
        "---..." : ":", "-.-.-.": ";", "-...-" : "=", ".-.-." : "+", "-....-": "-",
        "..--.-": "_", ".-..-.": "\"", "...-..-": "$", ".--.-.": "@"
    ]
    
    func handleBackspace() {
        if !self.currentMorseCode.isEmpty {
            // Remove the last character from the current Morse code
            self.currentMorseCode.removeAll()
        }
    }
}
