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
    /// The currently typed Morse symbols that will be converted.
    private var currentMorseCode = ""
    /// Current input range the the Morse symbols are taking up.
    private var currentMorseRange: NSRange?

    /// Timestamp for when the last keyDown occured.
    private var keyDownTimestamp: TimeInterval?
    /// Timestamp for when the last keyUp occured.
    private var keyUpTimestamp: TimeInterval?

    private let ditThresholdSec = 0.15
    /// Length of pause in typing that indicates the currently typed Morse symbols should be converted to characters.
    private let charThresholdSec = 0.9
    /// Length of pause in typing that indicates the end of typing a word.
    private let wordThresholdSec = 1.05
    /// Nominal delay that the user preferences gets multiplied by
    private let nominalDelay: Double = 0.75
    /// Default normalizing typing delay so that 0.75 is the middle of the slider range, ie. when typingDelay is 5.
    private let typingDelayNormalizer = 5.0
    /// Delay factor before conversion from Morse symbols to valid characters occurs. The smaller the faster one must type.
    private var typingDelay: Double {
        get {
            return UserDefaults.standard.double(forKey: "typingDelay") != 0 ?
            UserDefaults.standard.double(forKey: "typingDelay") : 5.0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "typingDelay")
        }
    }
    
    var preferencesWindowController: PreferencesWindowController?
    
    /// Backspace event key code, since it's handled exceptionally.
    private static let backspace: Int64 = 51
    
    /// Timer for determining when to convert Morse symbols to valid characters, and when to insert a space at the end of a word or sentence.
    var morseTimer: Timer?
    
    var eventTap: CFMachPort?
    
    /**
     * Constructor.
     */
    override init!(server: IMKServer, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        setupEventTap()
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: UserDefaults.didChangeNotification, object: nil)
    }

    deinit {
        self.removeEventTap()
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        
        let preferencesMenuItem = NSMenuItem(
            title: "Typing Speed \(self.typingDelay)...",
            action: #selector(openPreferencesWindow),
            keyEquivalent: ""
        )
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)
        
        return menu
    }

    func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        NSLog("Event tap successfully removed.")
    }
    
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        NSLog("Morse code input method activated.")
    }

    override func deactivateServer(_ sender: Any!) {
        super.deactivateServer(sender)
        removeEventTap() // Ensure event tap is removed on deactivation
        NSLog("Morse code input method deactivated.")
    }

    /**
     * Ensures the inputText is valid and can be used to insert characters.
     * - Parameters:
     *  - string: The key down event, which is the text input by the client.
     *  - sender: The client object sending the key down events.
     * - Returns: true if the input is accepted; otherwise false. Always returns true.
     */
    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        return true
    }
    
    /**
     * Sets up global event handler, specifying to only handle keyDown and keyUp events.
     * - Returns: void
     */
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
    
    /**
     * Handles tap events.
     * - Parameters:
     *   - proxy: Represents state within this application.
     *   - type: The type of the event.
     *   - event: The actual event object.
     *   - refcon: Raw pointer for accessing and manipulation untyped data.
     * - Returns: An unmanaged reference to the object passed as value if not a valid characters, or nil if handles by the Morse processor.
     */
    static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        let controller = Unmanaged<MorseCodeInputMethodController>.fromOpaque(refcon!).takeUnretainedValue()
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // If not a valid key code, or if it's bac
        if !MorseKeyCodes.contains(keyCode) || (keyCode == self.backspace && type != .keyDown) {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            // Invalidate the existing timer if any
            controller.morseTimer?.invalidate()

            // Detect if the backspace key is pressed
            if keyCode == self.backspace {
                controller.handleBackspace()
                return Unmanaged.passUnretained(event)
            }
            controller.handleKeyDown(event)
        case .keyUp:
            controller.handleKeyUp(event)
        default:
            break
        }
        
        return nil
    }

    /**
     * Updates the timestamp for when a valid key was pressed down.
     * - Returns: void
     */
    func handleKeyDown(_ event: CGEvent) {
        // Record the time the key was pressed
        self.keyDownTimestamp = TimeInterval(event.timestamp)
    }
    
    /**
     * Handles the actual creation of dots and dashes when a valid key is released, by checking how long the key
     * was pressed down for.
     * - Parameters:
     *   - event: Core Graphics tap event
     * - Returns: void
     */
    func handleKeyUp(_ event: CGEvent) {
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

        var morseSymbol = "-"
        if (duration < self.ditThresholdSec * self.getTypingDelay()) {
            morseSymbol = "."
        }

        // Process the Morse code symbol
        self.processMorseSymbol(morseSymbol)
        
        // Reset the timestamp
        self.keyUpTimestamp = nil
        
        // Start a new timer to process the Morse code if no further input is detected within the threshold
        self.morseTimer = Timer.scheduledTimer(timeInterval: self.charThresholdSec * self.getTypingDelay(), target: self, selector: #selector(self.handleCharTimeout), userInfo: nil, repeats: false)
    }
    
    func getTypingDelay() -> Double {
        return self.typingDelay * self.nominalDelay / self.typingDelayNormalizer
    }
    
    /**
     * Timer callback that causes the conversion of the recently typed Morse symbols valid characters (letters, numbers, punctuation).
     * See MorseCodeDictionary.swift.
     * - Returns: void
     */
    @objc func handleCharTimeout() {
        // Assume the end of a character and process the Morse code
        let conversionOk = self.translateMorseCode()

        if (conversionOk) {
            // Start new timer to process spaces between words
            self.morseTimer = Timer.scheduledTimer(timeInterval: self.wordThresholdSec * self.getTypingDelay(), target: self, selector: #selector(self.handleWordTimeout), userInfo: nil, repeats: false)
        }
    }
    
    /**
     * Timer callback that adds a space to wherever typing is occuring to mark the end of a word.
     * - Returns: void
     */
    @objc func handleWordTimeout() {
        guard let inputClient = self.client() else {
            NSLog("[handleWordTimeout] inputClient not valid")
            return
        }

        // Insert space after word
        inputClient.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
    
    /**
     * Appends the new Morse symbol to wherever typing is occuring, and updates the range of text that will need to be converted later.
     * - Parameters:
     *   - symbol: The dot (.) or dash (-) that was typed.
     * - Returns: void
     */
    func processMorseSymbol(_ symbol: String) {
        guard let inputClient = self.client() else {
            NSLog("[processMorseSymbol] inputClient not valid")
            return
        }

        // Append the Morse symbol to the current Morse code
        self.currentMorseCode.append(symbol)

        // Insert Morse symbol as text
        inputClient.insertText(symbol, replacementRange: NSRange(location: NSNotFound, length: 0))
        
        // Track the range of inserted Morse symbols
        if self.currentMorseRange == nil {
            let insertionPoint = inputClient.selectedRange().location
            self.currentMorseRange = NSRange(location: insertionPoint - 1, length: 1)
        } else {
            self.currentMorseRange?.length += 1
        }
    }

    /**
     * Translates the currently typed Morse symbols to characters, numbers or punctuation. (See MorseCodeDictionary.swift).
     * - Returns: true if symbols were converted. false if no symbols to convert.
     */
    func translateMorseCode() -> Bool {
        // Translate the current Morse code into a character
        guard let inputClient = self.client() else {
            NSLog("[translateMorseCode] inputClient not valid")
            return false
        }
        
        let character = MorseCodeDictionary[self.currentMorseCode] ?? ""

        if let range = self.currentMorseRange {
            inputClient.insertText(character, replacementRange: range)
        }

        // Clear the current Morse code after translation
        self.currentMorseCode = ""
        self.currentMorseRange = nil
        
        if (character.isEmpty) {
            self.morseTimer?.invalidate()
            return false
        }
        
        return true
    }
    
    /**
     * Deletes all morse symbols not yet converted
     * - Returns: void
     */
    func handleBackspace() {
        self.currentMorseCode = ""
        self.morseTimer?.invalidate()
    }
    
    @objc func openPreferencesWindow() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(windowNibName: "PreferencesWindow")
        }
        preferencesWindowController?.showWindow(self)
    }
    
    @objc func updateSettings() {
        self.typingDelay = UserDefaults.standard.double(forKey: "typingDelay")
        NSLog("[Morse Code Input Method] Updated typingDelay to \(self.typingDelay)")
    }
}
