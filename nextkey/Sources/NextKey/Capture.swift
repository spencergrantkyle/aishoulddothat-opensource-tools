import AppKit
import ScreenCaptureKit

enum Capture {
    /// Title and bounds (global, top-left origin) of the frontmost window of `pid`.
    /// Titles of other apps' windows need Screen Recording permission.
    static func frontWindow(pid: pid_t?) -> (title: String?, bounds: CGRect?) {
        guard let pid,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return (nil, nil) }
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (w[kCGWindowLayer as String] as? Int) == 0 else { continue }
            let title = (w[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
            var bounds: CGRect?
            if let dict = w[kCGWindowBounds as String] as? NSDictionary {
                bounds = CGRect(dictionaryRepresentation: dict as CFDictionary)
            }
            return (title, bounds)
        }
        return (nil, nil)
    }

    /// Screenshot of the display holding `windowBounds` (main display otherwise), with
    /// NextKey's own windows excluded. Returns JPEG data plus a thumbnail image.
    static func screenshot(windowBounds: CGRect?, maxDimension: Int) async throws -> (Data, NSImage) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else { throw CaptureError.noDisplay }

        let display = content.displays.first { d in
            windowBounds.map { d.frame.contains(CGPoint(x: $0.midX, y: $0.midY)) } ?? false
        } ?? content.displays.first { $0.displayID == CGMainDisplayID() } ?? content.displays[0]

        let ownApp = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])

        let scale = min(1.0, Double(maxDimension) / Double(max(display.width, display.height)))
        let config = SCStreamConfiguration()
        config.width = Int(Double(display.width) * scale)
        config.height = Int(Double(display.height) * scale)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else {
            throw CaptureError.encode
        }
        return (jpeg, NSImage(cgImage: image, size: .zero))
    }

    enum CaptureError: Error { case noDisplay, encode }
}
