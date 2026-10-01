//
//  iOSCaretView.swift
//
// Implements the caret in the iOS caret view
//
//  Created by Miguel de Icaza on 3/20/20.
//

#if os(iOS) || os(visionOS)
import Foundation
import UIKit
import CoreText
import CoreGraphics

// The CaretView is used to show the cursor
class CaretView: UIView {
    weak var terminal: TerminalView?
    var ctline: CTLine?
    /// Cell width of the character currently under the caret (2 for full-width
    /// CJK). Used to center its glyph within the caret, matching the text.
    var glyphColumnWidth: Int = 1
    var bgColor: CGColor
    var tracksFocus = true
    
    public init (frame: CGRect, cursorStyle: CursorStyle, terminal: TerminalView)
    {
        style = cursorStyle
        bgColor = caretColor.cgColor
        self.terminal = terminal
        super.init(frame: frame)
        layer.isOpaque = false
        isUserInteractionEnabled = false
        updateView()
    }
    
    @objc func foreground () {
        updateCursorStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var style: CursorStyle {
        didSet {
            updateCursorStyle ()
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow != nil {
            updateCursorStyle()
        }
    }
    
    override func didMoveToWindow() {
        if window != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: NSNotification.Name(rawValue: UIApplication.willEnterForegroundNotification.rawValue), object: nil)
        } else {
            NotificationCenter.default.removeObserver(self,  name: NSNotification.Name(rawValue: UIApplication.willEnterForegroundNotification.rawValue), object: nil)
        }
        updateCursorStyle ();
    }
    
    private var blinkTimer: Timer?

    // A timer that flips the opacity, not a repeating animation: an animation that never
    // ends keeps the app from ever going idle, which is a constant render-server cost
    // and stalls UI automation for as long as a terminal has focus.
    func updateAnimation (to: Bool) {
        layer.removeAllAnimations()
        blinkTimer?.invalidate()
        blinkTimer = nil
        self.layer.opacity = 1
        if window == nil {
            return
        }
        if to {
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.layer.opacity = self.layer.opacity > 0.5 ? 0 : 1
            }
        }
    }
    
    func setText (ch: CharData) {
        glyphColumnWidth = max(1, Int(ch.width))
        let character = terminal?.terminal.getCharacter(for: ch) ?? " "
        let res = NSAttributedString (
            string: UnicodeUtil.textPresentationAdjusted (character),
            attributes: terminal?.getAttributedValue(ch.attribute, usingFg: caretColor, andBg: caretTextColor ?? terminal?.nativeForegroundColor ?? TTColor.black))
        ctline = CTLineCreateWithAttributedString(res)
        setNeedsDisplay(bounds)
    }
    
    func updateCursorStyle () {
        switch style {
        case .blinkUnderline, .blinkBlock, .blinkBar:
            // Blink only with focus. Started from didMoveToWindow, every terminal in
            // the window blinked forever, hidden or not, and the app never went idle.
            updateAnimation(to: !tracksFocus || (superview?.isFirstResponder ?? false))
        case .steadyBar, .steadyBlock, .steadyUnderline:
            updateAnimation(to: false)
        }
        updateView()
    }
    
    func disableAnimations() {
        layer.removeAllAnimations()
        blinkTimer?.invalidate()
        blinkTimer = nil
        layer.opacity = 1
    }
    
    public var defaultCaretColor = UIColor.gray
    
    public var caretColor: UIColor = UIColor.gray {
        didSet {
            bgColor = caretColor.cgColor
            updateView()
        }
    }

    public var defaultCaretTextColor: UIColor? = nil
    public var caretTextColor: UIColor? = nil {
        didSet {
            updateView()
        }
    }

    func updateView() {
        setNeedsDisplay()
    }

    override public func draw (_ dirtyRect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext () else {
            return
        }
        context.scaleBy (x: 1, y: -1)
        context.translateBy(x: 0, y: -frame.height)

        drawCursor(in: context, hasFocus: tracksFocus ? (superview?.isFirstResponder ?? true) : true)
    }

}
#endif
