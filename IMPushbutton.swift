import UIKit
import QuartzCore

// MARK: - Delegate Protocol
protocol IMPushButtonDelegate {
    func pushbuttonCVCDidChange(IMPushButtonAnimationState: IMPushButtonAnimationState, with touchLocation: CGPoint)
    func pushbuttonCVCWasLongPressed(in IMPushButtonAnimationState: IMPushButtonAnimationState, at touchLocation: CGPoint)
}
enum IMPushButtonAnimationState: Double {
    case off = 0
    case pushOn = 0.3333
    case on = 0.6666
    case pushOff = 1
}

enum IMPushButtonStyle: Int {
    case classic, glow
}
enum IMPushButtonDepth: Int {
    case minimal, shallow, medium, deep, extra
}
enum IMPushButton3DStyle: Int {
    case none, recessed, extruded
}

class IMPushButton: UIButton, UIGestureRecognizerDelegate {
    
    // MARK: - Private variables
    fileprivate let pressRecognizer = UILongPressGestureRecognizer()
    fileprivate var currentIMPushButtonAnimationState: IMPushButtonAnimationState = .off
    fileprivate var targetIMPushButtonAnimationState: IMPushButtonAnimationState?
    fileprivate var currentTouch: UITouch?
    fileprivate var currentTouchLocation: CGPoint? {
        get {
            return currentTouch?.location(in: self)
        }
    }
    fileprivate var overrideDelegate = false
    fileprivate var twoSecondsTimer: Timer?
    fileprivate var twoSecondsOverride = false
    fileprivate var needs3DTouchUpdate = false
    fileprivate var hapticFeedback: IMHapticFeedback?
    
    // MARK: - Public settings
    var pushbuttonDelegate: IMPushButtonDelegate?
    var isSoundEffectEnabled = false
    var style = IMPushButtonStyle.classic {
        didSet {
            updateStyle()
        }
    }
    var isBorderBacklitWhenEnabled: Bool = true {
        didSet {
            updateStyle()
        }
    }
    var backlightColor = UIColor.yellow {
        didSet {
            updateStyle()
        }
    }
    var scaleMultiplier: Double = 1.0 {
        didSet {
            updateStyle()
        }
    }
    var shouldReceiveTouches = true
    var isPushbuttonEnabled: Bool {
        get {
            return (currentIMPushButtonAnimationState != .off)
        }
    }
    var longPressDuration = 2.0
    var use3DTouch = true
    var useHapticFeedback = true
    var useFancyEffects: Bool {
        get {
            return style == .glow
        }
    }
    
    // MARK: - View Lifecycle
    override func didMoveToSuperview() {
        if useFancyEffects { updateStyle() }
        
        use3DTouch = use3DTouch && self.traitCollection.forceTouchCapability == .available
        
        pressRecognizer.minimumPressDuration = 0.0
        pressRecognizer.cancelsTouchesInView = true
        pressRecognizer.delegate = self
        pressRecognizer.addTarget(self, action: #selector(handleTap))
        self.addGestureRecognizer(pressRecognizer)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if useFancyEffects { updateStyle() }
    }
    
    // MARK: - Effects & Animation!
    
    fileprivate func updateStyle() {
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.black.cgColor
        
        layer.masksToBounds = false
        layer.shadowOpacity = 0.0
        layer.shadowColor = backlightColor.cgColor
        layer.shadowRadius = 5.0
        layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        let shadowScale = CGFloat(0.9*scaleMultiplier)
        let shadowSize = self.bounds.size.scaled(by: shadowScale)
        let shadowPoint = CGPoint(x: shadowSize.width*0.5*(1-shadowScale), y: shadowSize.height*0.5*(1-shadowScale))
        let shadowRect = CGRect(origin: shadowPoint, size: shadowSize)
        layer.shadowPath = UIBezierPath(rect: shadowRect).cgPath
    }
    
    override func draw(_ rect: CGRect) {
        if let target = targetIMPushButtonAnimationState {
            if target != currentIMPushButtonAnimationState || needs3DTouchUpdate {
                let animationCompletionHandler: (Bool) -> () = {
                    if $0 {
                        if (!self.overrideDelegate) {
                            self.pushbuttonDelegate?.pushbuttonCVCDidChange(IMPushButtonAnimationState: self.currentIMPushButtonAnimationState, with: self.currentTouchLocation!)
                        } else {
                            self.overrideDelegate = false
                        }
                        if self.currentIMPushButtonAnimationState == .off {
                            UIView.animate(withDuration: 0.5) {
                                self.layer.shadowOpacity = 0.0
                            }
                        }
                    }
                }
                var scale: CGFloat = 1.0
                var targetBacklightBrightness: Float = 0.9
                
                if use3DTouch && needs3DTouchUpdate && ((currentIMPushButtonAnimationState == .pushOn) || (currentIMPushButtonAnimationState == .pushOff))  {
                    if currentIMPushButtonAnimationState == .off {
                        currentIMPushButtonAnimationState = target
                    }
                    if let pressure = self.currentTouch?.force {
                        scale = CGFloat(min(0.75,max(0.6,(20/3-pressure)/10)+0.1))
                    }
                    targetBacklightBrightness = 1.0
                    needs3DTouchUpdate = false
                } else {
                    switch currentIMPushButtonAnimationState {
                    case .off:
                        switch target {
                        case .pushOn:
                            scale = CGFloat(0.7 * self.scaleMultiplier)
                            targetBacklightBrightness = 1.0
                            break
                        default:
                            break
                        }
                        break
                    case .pushOn:
                        switch target {
                        case .on:
                            scale = CGFloat(0.8 * self.scaleMultiplier)
                            targetBacklightBrightness = 0.9
                            break
                        case .off:
                            scale = 1.0
                            break
                        default:
                            break
                        }
                        break
                    case .on:
                        switch target {
                        case .pushOff:
                            scale = CGFloat(0.7 * self.scaleMultiplier)
                            targetBacklightBrightness = 1.0
                            break
                        case .off:
                            scale = 1.0
                            break
                        default:
                            break
                        }
                        break
                    case .pushOff:
                        switch target {
                        case .off:
                            scale = 1.0
                            break
                        case .on:
                            scale = CGFloat(0.8 * self.scaleMultiplier)
                            targetBacklightBrightness = 0.9
                            break
                        default:
                            break
                        }
                        break
                    }
                    currentIMPushButtonAnimationState = target
                    targetIMPushButtonAnimationState = nil
                }
                if !overrideDelegate && useHapticFeedback {
                    if (currentIMPushButtonAnimationState == .on) || (currentIMPushButtonAnimationState == .off) {
                        prepareImpactFeedback(heavyImpact: false)
                        hfImpactOccurred()
                    }
                }
                UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .curveEaseIn], animations: {
                    self.self.transform = CGAffineTransform.identity.scaledBy(x: scale, y: scale)
                    self.layer.shadowOpacity = targetBacklightBrightness
                }, completion: animationCompletionHandler)
            }
        }
        super.draw(rect)
    }
    
    fileprivate func resetAnimation() {
        targetIMPushButtonAnimationState = .off
        setNeedsDisplay()
    }
    
    // MARK: - Tap handling
    func handleTap() {
        if pressRecognizer.numberOfTouches == 1 {
            switch(pressRecognizer.state) {
            case .began:
                currentTouch = (pressRecognizer.value(forKey: "touches") as! Array)[0]
                twoSecondsTimer?.invalidate()
                twoSecondsTimer = Timer.scheduledTimer(timeInterval: longPressDuration, target: self, selector: #selector(longPressed), userInfo: nil, repeats: true)
                if currentIMPushButtonAnimationState.rawValue < 0.5 {
                    targetIMPushButtonAnimationState = .pushOn
                } else {
                    targetIMPushButtonAnimationState = .pushOff
                }
                if (currentIMPushButtonAnimationState == .pushOn) || (currentIMPushButtonAnimationState == .pushOff) {
                    prepareImpactFeedback(heavyImpact: false)
                }
                needs3DTouchUpdate = use3DTouch
                setNeedsDisplay()
                break
            case .changed:
                currentTouch = (pressRecognizer.value(forKey: "touches") as! Array)[0]
                needs3DTouchUpdate = use3DTouch
                setNeedsDisplay()
                break
            case .ended:
                needs3DTouchUpdate = false
                currentTouch = (pressRecognizer.value(forKey: "touches") as! Array)[0]
                twoSecondsTimer?.invalidate()
                twoSecondsTimer = nil
                if twoSecondsOverride {
                    twoSecondsOverride = false
                    targetIMPushButtonAnimationState = .on
                } else {
                    if currentIMPushButtonAnimationState.rawValue < 0.5 {
                        targetIMPushButtonAnimationState = .on
                    } else {
                        targetIMPushButtonAnimationState = .off
                    }
                }
                setNeedsDisplay()
                break
            default:
                currentTouch = nil
                twoSecondsTimer?.invalidate()
                twoSecondsTimer = nil
                resetAnimation()
                break
            }
        }
    }
    
    func overrideState(with newIMPushButtonAnimationState: IMPushButtonAnimationState) {
        targetIMPushButtonAnimationState = newIMPushButtonAnimationState
        overrideDelegate = true
        setNeedsDisplay()
    }
    
    func longPressed(timer: Timer) {
        pushbuttonDelegate?.pushbuttonCVCWasLongPressed(in: currentIMPushButtonAnimationState, at: pressRecognizer.location(in: self))
        twoSecondsOverride = true
        if useHapticFeedback {
            //hfSelectionOccurred()
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isEqual(pressRecognizer) {
            return false
        } else {
            return true
        }
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return shouldReceiveTouches && isUserInteractionEnabled
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let should = shouldReceiveTouches && isUserInteractionEnabled
        if should {
            currentTouch = touch
        }
        return should
    }
}

// MARK: - Haptic Feedback
fileprivate extension IMPushButton {
    fileprivate func prepareImpactFeedback(heavyImpact: Bool) {
        if #available(iOS 10, *) {
            hapticFeedback = IMHapticFeedback(mode: .impact, strength: heavyImpact ? .strong : .light)
            hapticFeedback!.prepareForFeedback()
        }
    }
    fileprivate func hfImpactOccurred() {
        if #available(iOS 10, *) {
            if hapticFeedback != nil {
                hapticFeedback!.triggerFeedback()
            }
        }
    }
}

fileprivate extension CGSize {
    func scaled(by scaleFactor: CGFloat) -> CGSize {
        return CGSize(width: width * scaleFactor, height: height * scaleFactor)
    }
}
