import AppKit

/// Prevents `NSDocumentController` from intercepting file-open events with errors.
///
/// mkdn declares `CFBundleDocumentTypes` in its Info.plist so macOS routes Markdown
/// files to the app, but it uses SwiftUI's `WindowGroup` instead of `NSDocument`
/// subclasses. The default `NSDocumentController` fails with
/// `NSCocoaErrorDomain Code 256` when it cannot find a document class for the type.
///
/// By installing this subclass before `NSDocumentController.shared` is first
/// accessed (in `AppDelegate.applicationWillFinishLaunching`), all document-class
/// lookup errors are suppressed. File routing goes through ``FileOpenService``
/// instead.
@MainActor
public final class NonDocumentController: NSDocumentController {
    /// Routes Markdown files through ``FileOpenService`` instead of the
    /// document-class machinery.
    ///
    /// Calls `completionHandler(nil, false, nil)` to tell AppKit the open
    /// succeeded without producing an `NSDocument`, preventing the error dialog.
    override public func openDocument(
        withContentsOf url: URL,
        display _: Bool,
        // swiftlint:disable:next unneeded_escaping
        completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
    ) {
        if url.isMarkdownFile {
            FileOpenService.shared.pendingURLs.append(url)
            completionHandler(nil, false, nil)
            return
        }
        completionHandler(nil, false, nil)
    }

    /// Suppresses the "untitled document" creation that `NSDocumentController`
    /// triggers on launch or via `Cmd-N`.
    ///
    /// SwiftUI's `WindowGroup` handles window creation; calling `super` would
    /// fail because there are no `NSDocument` subclasses registered.
    override public func newDocument(_: Any?) {}
}
