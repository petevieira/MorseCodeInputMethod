//
//  MorseCodeInputMethodController.swift
//  MorseCodeInputMethod
//
//  Created by Pete Vieira on 8/28/24.
//

import Cocoa
import InputMethodKit
import AVFoundation

@objc(MorseCodeInputMethodController)
class MorseCodeInputMethodController: IMKInputController {
    /// The currently typed Morse symbols that will be converted.
    private var currentMorseCode = ""
    /// Current input range the the Morse symbols are taking up.
    private var currentMorseRange: NSRange?

    /// Whether or not a speed setting key is being processed. Needed to avoid false conversions.
    private var isSpeedSettingKey: Bool = false

    /// Timestamp for when the last keyDown occured.
    private var keyDownTimestamp: TimeInterval?
    /// Timestamp for when the last keyUp occured.
    private var keyUpTimestamp: TimeInterval?

    private let ditThresholdSec = [0, 0.143, 0.13406, 0.12513, 0.11619, 0.10725, 0.09831, 0.08938, 0.08044, 0.0715]
    /// Length of pause in typing that indicates the currently typed Morse symbols should be converted to characters.
    private let charThresholdSec = [0, 0.884, 0.816, 0.748, 0.68, 0.612, 0.544, 0.476, 0.408, 0.34]
    /// Length of pause in typing that indicates the end of typing a word.
    private let wordThresholdSec = [0, 1.027, 0.948, 0.869, 0.79, 0.711, 0.632, 0.553, 0.474, 0.395]
    /// Delay factor before conversion from Morse symbols to valid characters occurs. The smaller the faster one must type.
    private var typingSpeed = 5

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
    }

    deinit {
        self.removeEventTap()
    }

    /**
     * Remove event tap capturing, when input method deactivated.
     */
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

    /**
     * Create the menu in the layout switch menu in the mac menu bar.
     * - Returns: Final menu
     */
    override func menu() -> NSMenu! {
        let menu = NSMenu()

        let infoMenuItem = NSMenuItem()
        infoMenuItem.title = "- Use number keys (1-9) to adjust typing speed."
        infoMenuItem.isEnabled = false

        let substitutionsMenuItem = NSMenuItem()
        substitutionsMenuItem.title = "- Turn off text substitutions to avoid issues."
        substitutionsMenuItem.isEnabled = false

        menu.addItem(infoMenuItem)
        menu.addItem(substitutionsMenuItem)

        return menu
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
        if (!MorseLetterKeyCodes.contains(keyCode) && !MorseNumberKeyCodes.contains(keyCode))
            || (keyCode == self.backspace && type != .keyDown)
        {
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
            } else if MorseNumberKeyCodes.contains(keyCode) {
                controller.handleTypingSpeedChange(keyCode)
                controller.isSpeedSettingKey = true
                return nil
            } else {
                controller.isSpeedSettingKey = false
                controller.handleKeyDown(event)
                return nil
            }
        case .keyUp:
            if controller.isSpeedSettingKey || MorseNumberKeyCodes.contains(keyCode) {
                controller.isSpeedSettingKey = false
                return nil
            } else {
                controller.handleKeyUp(event)
            }
            break
        default:
            break
        }

        return nil
    }

    /**
     * Updates the typing speed based on the number typed (1-9)
     * - Paramaters:
     *   - keyCode: key code of number typed
     * - Returns: void
     */
    func handleTypingSpeedChange(_ keyCode: Int64) {
        if let speed = KeyCodeToNumber[keyCode] {
            self.typingSpeed = Int(speed)
            NSLog("Typing speed set to \(self.typingSpeed).")
        } else {
            print("Invalid key code for typing speed adjustment.")
        }
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
        if (duration < self.ditThresholdSec[typingSpeed]) {
            morseSymbol = "."
        }

        // Process the Morse code symbol
        self.processMorseSymbol(morseSymbol)

        // Reset the timestamp
        self.keyUpTimestamp = nil

        // Start a new timer to process the Morse code if no further input is detected within the threshold
        self.morseTimer = Timer.scheduledTimer(timeInterval: self.charThresholdSec[typingSpeed], target: self, selector: #selector(self.handleCharTimeout), userInfo: nil, repeats: false)
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
            self.morseTimer = Timer.scheduledTimer(timeInterval: self.wordThresholdSec[typingSpeed], target: self, selector: #selector(self.handleWordTimeout), userInfo: nil, repeats: false)
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

        // Do not play morse sound for now because it doesn't handle very fast beeps
//        self.playMorseSound(for: symbol)

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
}
