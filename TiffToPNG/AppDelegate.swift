import Cocoa
import UserNotifications
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var lastChangeCount = NSPasteboard.general.changeCount
    var isConversionEnabled = true
    var isPlaintextEnabled = true
    var isSmartQuotesEnabled = true
    var lastProcessedTiffData: Data?
    var lastProcessedRTFData: Data?
    var lastProcessedHTMLData: Data?
    var isLaunchAtLoginEnabled = false
    
    let defaults: [String: Any] = [
        "AutoConvertEnabled": true,
        "AutoPlaintextEnabled": true,
        "AutoSmartQuotesEnabled": true,
        "LaunchAtLoginEnabled": false
    ]
    
    var gcdTimer: DispatchSourceTimer?

    func startClipboardMonitoring() {
        // Create a timer on a background queue
        gcdTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        gcdTimer?.schedule(deadline: .now(), repeating: 0.5)  // Check every second
        gcdTimer?.setEventHandler { [weak self] in
            // Dispatch back to the main queue if your checkClipboard needs to update UI
            DispatchQueue.main.async {
                self?.checkClipboard()
            }
        }
        gcdTimer?.resume()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item for the menubar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: NSImage.Name("StatusIcon"))
            button.image?.isTemplate = true
        }
        
        // Register default settings
        UserDefaults.standard.register(defaults: defaults)
        
        isConversionEnabled = UserDefaults.standard.bool(forKey: "AutoConvertEnabled")
        isPlaintextEnabled = UserDefaults.standard.bool(forKey: "AutoPlaintextEnabled")
        isSmartQuotesEnabled = UserDefaults.standard.bool(forKey: "AutoSmartQuotesEnabled")
        isLaunchAtLoginEnabled = UserDefaults.standard.bool(forKey: "LaunchAtLoginEnabled")
        
        // Build the menu for the status item
        let menu = NSMenu()
        
        // Toggle conversion menu item with checkmark state
        let toggleItem = NSMenuItem(title: "Auto Convert", action: #selector(toggleConversion(_:)), keyEquivalent: "")
        toggleItem.state = isConversionEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        let plaintextToggleItem = NSMenuItem(title: "Auto Plaintext", action: #selector(togglePlaintext(_:)), keyEquivalent: "")
        plaintextToggleItem.state = isPlaintextEnabled ? .on : .off
        menu.addItem(plaintextToggleItem)

        let smartQuotesToggleItem = NSMenuItem(title: "Auto Smart Quotes", action: #selector(toggleSmartQuotes(_:)), keyEquivalent: "")
        smartQuotesToggleItem.state = isSmartQuotesEnabled ? .on : .off
        menu.addItem(smartQuotesToggleItem)

        let launchAtLoginToggleItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginToggleItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginToggleItem)
        
        // Separator for clarity
        menu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        startClipboardMonitoring()
    }
    
    @objc func toggleConversion(_ sender: NSMenuItem) {
        isConversionEnabled.toggle()
        sender.state = isConversionEnabled ? .on : .off
        UserDefaults.standard.set(isConversionEnabled, forKey: "AutoConvertEnabled")
        UserDefaults.standard.synchronize()
    }

    @objc func togglePlaintext(_ sender: NSMenuItem) {
        isPlaintextEnabled.toggle()
        sender.state = isPlaintextEnabled ? .on : .off
        UserDefaults.standard.set(isPlaintextEnabled, forKey: "AutoPlaintextEnabled")
        UserDefaults.standard.synchronize()
    }
    
    @objc func toggleSmartQuotes(_ sender: NSMenuItem) {
        isSmartQuotesEnabled.toggle()
        sender.state = isSmartQuotesEnabled ? .on : .off
        UserDefaults.standard.set(isSmartQuotesEnabled, forKey: "AutoSmartQuotesEnabled")
        UserDefaults.standard.synchronize()
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        isLaunchAtLoginEnabled.toggle()
        sender.state = isLaunchAtLoginEnabled ? .on : .off
        UserDefaults.standard.set(isLaunchAtLoginEnabled, forKey: "LaunchAtLoginEnabled")
        UserDefaults.standard.synchronize()
        if #available(macOS 13.0, *) {
            do {
                if isLaunchAtLoginEnabled {
                    try SMAppService.mainApp.register()
                    print("Registered main app for launch at login.")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("Unregistered main app for launch at login.")
                }
            } catch {
                print("Error toggling launch at login: \(error)")
            }
        } else {
            // Fallback for earlier macOS versions (if needed)
            print("Launch at login toggling not supported on this macOS version.")
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Only proceed if there is a change in the pasteboard
        if pasteboard.changeCount != lastChangeCount {
            // Update the lastChangeCount to prevent reprocessing
            lastChangeCount = pasteboard.changeCount
            
            // Check for TIFF data and if conversion is enabled
            if isConversionEnabled,
               let types = pasteboard.types,
               types.contains(.tiff),
               let tiffData = pasteboard.data(forType: .tiff) {
                
                // Skip processing if this clipboard data was already processed
                if let lastData = lastProcessedTiffData, lastData == tiffData {
                    return
                }
                
                if let image = NSImage(data: tiffData),
                   let pngData = image.pngDataRepresentation() {
                    
                    // Replace the clipboard content with PNG data
                    lastChangeCount += 1;
                    pasteboard.clearContents()
                    pasteboard.setData(pngData, forType: .png)
                    
                    // Mark this TIFF data as processed
                    lastProcessedTiffData = tiffData
                    
                    // Schedule a system notification
                    let content = UNMutableNotificationContent()
                    content.title = "Clipboard Updated"
                    content.body = "->PNG"

                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    
                    // After processing TIFF, exit to avoid further processing
                    return
                }
            }
            
            // Check for styled text and if plaintext conversion is enabled
            if isPlaintextEnabled, let types = pasteboard.types {
                if types.contains(.rtf), let rtfData = pasteboard.data(forType: .rtf) {
                    // Skip processing if this styled text was already processed
                    if let lastRTFData = lastProcessedRTFData, lastRTFData == rtfData {
                        return
                    }
                    
                    if let attributedString = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                        let plainText = attributedString.string
                        
                        // Replace the clipboard content with plain text
                        lastChangeCount += 1
                        pasteboard.clearContents()
                        pasteboard.setString(plainText, forType: .string)
                        
                        // Mark this styled text as processed
                        lastProcessedRTFData = rtfData
                        
                        // Schedule a system notification
                        let content = UNMutableNotificationContent()
                        content.title = "Clipboard Updated"
                        content.body = "->plaintext"
                        
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        
                        return
                    }
                } else if types.contains(.html), let htmlData = pasteboard.data(forType: .html) {
                    // Skip processing if this styled text was already processed
                    if let lastHTMLData = lastProcessedHTMLData, lastHTMLData == htmlData {
                        return
                    }
                    
                    if let attributedString = try? NSAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                        let plainText = attributedString.string
                        
                        // Replace the clipboard content with plain text
                        lastChangeCount += 1
                        pasteboard.clearContents()
                        pasteboard.setString(plainText, forType: .string)
                        
                        // Mark this styled text as processed
                        lastProcessedHTMLData = htmlData
                        
                        // Schedule a system notification
                        let content = UNMutableNotificationContent()
                        content.title = "Clipboard Updated"
                        content.body = "->plaintext"
                        
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        
                        return
                    }
                }
            }
            
            // Check for plain text smart quotes replacement
            if isSmartQuotesEnabled, let plainText = pasteboard.string(forType: .string) {
                let updatedText = plainText
                    .replacingOccurrences(of: "“", with: "\"")
                    .replacingOccurrences(of: "”", with: "\"")
                    .replacingOccurrences(of: "‘", with: "'")
                    .replacingOccurrences(of: "’", with: "'")
                if updatedText != plainText {
                    lastChangeCount += 1
                    pasteboard.clearContents()
                    pasteboard.setString(updatedText, forType: .string)
                    
                    let content = UNMutableNotificationContent()
                    content.title = "Clipboard Updated"
                    content.body = "->dumb quotes"
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    
                    return
                }
            }
        }
    }
}

extension NSImage {
    /// Returns the PNG data representation of the NSImage.
    func pngDataRepresentation() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
