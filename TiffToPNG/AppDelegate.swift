import Cocoa
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var lastChangeCount = NSPasteboard.general.changeCount
    var isConversionEnabled = true  // Toggle flag
    var isPlaintextEnabled = true
    var lastProcessedTiffData: Data?
    var lastProcessedRTFData: Data?
    var lastProcessedHTMLData: Data?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item for the menubar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "Tiff2PNG" // You can also set an image here
        }
        
        // Build the menu for the status item
        let menu = NSMenu()
        
        // Toggle conversion menu item with checkmark state
        let toggleItem = NSMenuItem(title: "Auto Convert", action: #selector(toggleConversion(_:)), keyEquivalent: "")
        toggleItem.state = isConversionEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        let plaintextToggleItem = NSMenuItem(title: "Auto Plaintext", action: #selector(togglePlaintext(_:)), keyEquivalent: "")
        plaintextToggleItem.state = isPlaintextEnabled ? .on : .off
        menu.addItem(plaintextToggleItem)
        
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
        
        // Start monitoring the clipboard using a timer
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(checkClipboard),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    @objc func toggleConversion(_ sender: NSMenuItem) {
        isConversionEnabled.toggle()
        sender.state = isConversionEnabled ? .on : .off
    }

    @objc func togglePlaintext(_ sender: NSMenuItem) {
        isPlaintextEnabled.toggle()
        sender.state = isPlaintextEnabled ? .on : .off
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        print("checking clipboard... ")
        print(pasteboard.changeCount)
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
                    print("Replaced TIFF with PNG.")
                    
                    // Mark this TIFF data as processed
                    lastProcessedTiffData = tiffData
                    
                    // Schedule a system notification
                    let content = UNMutableNotificationContent()
                    content.title = "Clipboard Updated"
                    content.body = "Replaced TIFF with PNG."
                    content.sound = UNNotificationSound.default

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
                        print("Replaced styled text with plain text.")
                        
                        // Mark this styled text as processed
                        lastProcessedRTFData = rtfData
                        
                        // Schedule a system notification
                        let content = UNMutableNotificationContent()
                        content.title = "Clipboard Updated"
                        content.body = "Replaced styled text with plain text."
                        content.sound = UNNotificationSound.default
                        
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
                        print("Replaced styled text (HTML) with plain text.")
                        
                        // Mark this styled text as processed
                        lastProcessedHTMLData = htmlData
                        
                        // Schedule a system notification
                        let content = UNMutableNotificationContent()
                        content.title = "Clipboard Updated"
                        content.body = "Replaced styled text (HTML) with plain text."
                        content.sound = UNNotificationSound.default
                        
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        
                        return
                    }
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
