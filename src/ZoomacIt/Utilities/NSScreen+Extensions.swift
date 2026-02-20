import AppKit

extension NSScreen {

    /// Returns the screen that contains the mouse cursor.
    static var screenContainingMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// The display's backing scale factor (Retina = 2.0, standard = 1.0).
    var displayScaleFactor: CGFloat {
        backingScaleFactor
    }

    /// The pixel dimensions of the screen (accounting for Retina scaling).
    var pixelSize: CGSize {
        CGSize(
            width: frame.width * backingScaleFactor,
            height: frame.height * backingScaleFactor
        )
    }
}
