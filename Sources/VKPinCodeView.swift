//
//  VKPinCodeView.swift
//  VKPinCodeView
//
//  Created by Vladimir Kokhanevich on 22/02/2019.
//  Copyright © 2019 Vladimir Kokhanevich. All rights reserved.
//

import UIKit

/// Validation closure. Use it as soon as you need to validate input text which is different from digits.
public typealias PinCodeValidator = (_ code: String) -> Bool


private enum InterfaceLayoutDirection {

    case ltr, rtl
}


/// Main container with PIN input items. You can use it in storyboards, nib files or right in the code.
public final class VKPinCodeView: UIView {

    public enum ActiveIndexStrategy {
        case firstEmptyOrLast, lastFilledOrFirst, firstEmpty
    }

    private lazy var _stack = UIStackView(frame: bounds)
    
    private lazy var _textField = UITextField(frame: bounds)
    
    private var _code = "" {
        
        didSet { onCodeDidChange?(_code) }
    }
    
    private var _activeIndex: Int {

        let count = _code.count
        switch activeIndexStrategy {
        case .lastFilledOrFirst:
            return count == 0 ? 0 : count - 1
        case .firstEmptyOrLast:
            return count == length ? count - 1 : count
        case .firstEmpty:
            return count
        }
    }

    private var _layoutDirection: InterfaceLayoutDirection = .ltr

    public var activeIndexStrategy: ActiveIndexStrategy = .lastFilledOrFirst {

        didSet { highlightActiveLabel(_activeIndex) }
    }

    public var ignoreUserInput: Bool = false

    /// Enable or disable error mode. Default value is false.
    public var isError = false {

        didSet { if oldValue != isError { updateErrorState() } }
    }
    
    /// Number of input items.
    public var length: Int = 4 {
        
        willSet { createLabels() }
    }
    
    /// Spacing between input items.
    public var spacing: CGFloat = 16 {
        
        willSet { if newValue != spacing { _stack.spacing = newValue } }
    }

    /// Setup a keyboard type. Default value is numberPad.
    public var keyBoardType = UIKeyboardType.numberPad {
        
        willSet { _textField.keyboardType = newValue }
    }
    
    /// Setup a keyboard appearence. Default value is light.
    public var keyBoardAppearance = UIKeyboardAppearance.light {
        
        willSet { _textField.keyboardAppearance = newValue }
    }
    
    /// Setup autocapitalization. Default value is none.
    public var autocapitalizationType = UITextAutocapitalizationType.none {
        
        willSet { _textField.autocapitalizationType = newValue }
    }
    
    /// Enable or disable selection animation for active input item. Default value is true.
    public var animateSelectedInputItem = true
    
    /// Enable or disable shake animation on error. Default value is true.
    public var shakeOnError = true
    
    /// Setup a preferred error reset type. Default value is none.
    public var resetAfterError = ResetType.none
    
    /// Fires when PIN is completely entered. Provides actual code and view for managing error state.
    public var onComplete: ((_ code: String, _ pinView: VKPinCodeView) -> Void)?
    
    /// Fires after each char has been entered.
    public var onCodeDidChange: ((_ code: String) -> Void)?
    
    /// Fires after begin editing.
    public var onBeginEditing: (() -> Void)?

    /// Fires when shake animation is created.
    public var onShakeAnimationCreated: ((CAKeyframeAnimation) -> Void)?
    
    /// Text input validation. You might be need it if text input is different from digits. You don't need this by default.
    public var validator: PinCodeValidator?

    /// Fires every time when the label is ready to set the style.
    public var onSettingStyle: (() -> EntryViewStyle)? {

        didSet { createLabels() }
    }
    
    
    // MARK: - Initializers

    public convenience init() {

        self.init(frame: CGRect.zero)
    }

    override public init(frame: CGRect) {
        
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
    }
    
    
    // MARK: Life cycle
    
    override public func awakeFromNib() {
        
        super.awakeFromNib()
        setup()
    }
    
    
    // MARK: Overrides

    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        
        onBecomeActive()
        return super.becomeFirstResponder()
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        onBecomeActive()
    }
    
    
    // MARK: Public methods

    /// Use this method to reset the code
    public func resetCode() {
        _code = ""
        _textField.text = nil
        _stack.arrangedSubviews.forEach({ ($0 as! VKLabel).text = nil })
        isError = false
    }
    
    /// Use this method to access internal views: labels for custom animations
    public func getLabels() -> [UILabel] {
        return _stack.arrangedSubviews.compactMap { $0 as? UILabel}
    }

    // MARK: Private methods
    
    private func setup() {
        
        setupTextField()
        setupStackView()

        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {

            _layoutDirection = .rtl
        }

        createLabels()
    }
    
    private func setupStackView() {
        
        _stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _stack.alignment = .fill
        _stack.axis = .horizontal
        _stack.distribution = .fillEqually
        _stack.spacing = spacing
        addSubview(_stack)
    }
    
    private func setupTextField() {
        
        _textField.keyboardType = keyBoardType
        _textField.autocapitalizationType = autocapitalizationType
        _textField.keyboardAppearance = keyBoardAppearance
        _textField.isHidden = true
        _textField.delegate = self
        _textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _textField.addTarget(self, action: #selector(self.onTextChanged(_:)), for: .editingChanged)
        
        if #available(iOS 12.0, *) { _textField.textContentType = .oneTimeCode }
        
        addSubview(_textField)
    }
    
    @objc private func onTextChanged(_ sender: UITextField) {
        
        let text = sender.text!
        
        if _code.count > text.count {
            
            deleteChar(text)
        } else {
            
            appendChar(text)
        }

        highlightActiveLabel(_activeIndex)
        
        if _code.count == length {

            _textField.resignFirstResponder()
            onComplete?(_code, self)
        }
    }
    
    private func deleteChar(_ text: String) {
        
        let index = text.count
        let previous = _stack.arrangedSubviews[index] as! UILabel
        previous.text = ""
        _code = text
    }
    
    private func appendChar(_ text: String) {
        
        if text.isEmpty { return }

        let index = text.count - 1
        let activeLabel = _stack.arrangedSubviews[index] as! UILabel
        let charIndex = text.index(text.startIndex, offsetBy: index)
        activeLabel.text = String(text[charIndex])
        _code += activeLabel.text!
    }
    
    private func highlightActiveLabel(_ activeIndex: Int) {
        
        for i in 0 ..< _stack.arrangedSubviews.count {

            let label = _stack.arrangedSubviews[normalizeIndex(index: i)] as! VKLabel
            label.isSelected = i == normalizeIndex(index: activeIndex)
        }
    }
    
    private func turnOffSelectedLabel() {

        guard _activeIndex < _stack.arrangedSubviews.count,
              let label = _stack.arrangedSubviews[_activeIndex] as? VKLabel else { return }
        label.isSelected = false
    }
    
    private func createLabels() {
        
        _stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for _ in 1 ... length { _stack.addArrangedSubview(VKLabel(onSettingStyle?())) }
    }
    
    private func updateErrorState() {
        
        if isError {
            
            turnOffSelectedLabel()
            if shakeOnError { shakeAnimation() }
        }
        
        _stack.arrangedSubviews.forEach({ ($0 as! VKLabel).isError = isError })
    }
    
    private func shakeAnimation() {
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-15.0, 15.0, -15.0, 15.0, -12.0, 12.0, -10.0, 10.0, 0.0]
        animation.delegate = self
        onShakeAnimationCreated?(animation)
        layer.add(animation, forKey: "shake")
    }
    
    private func onBecomeActive() {
        
        _textField.becomeFirstResponder()
        highlightActiveLabel(_activeIndex)
    }

    private func normalizeIndex(index: Int) -> Int {

        return _layoutDirection == .ltr ? index : length - 1 - index
    }
}


extension VKPinCodeView: UITextFieldDelegate {
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {

        onBeginEditing?()
        handleErrorStateOnBeginEditing()
    }
    
    public func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        
        if string.isEmpty { return true }
        if ignoreUserInput { return false }
        return (validator?(string) ?? true) && _code.count < length
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        
        if isError { return }
        turnOffSelectedLabel()
    }

    private func handleErrorStateOnBeginEditing() {

        if isError, case ResetType.onUserInteraction = resetAfterError {

            return resetCode()
        }

        isError = false
    }
}

extension VKPinCodeView: CAAnimationDelegate {
    
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {

        if !flag { return }

        switch resetAfterError {

            case let .afterError(delay):
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.resetCode() }
            default:
                break
        }
    }
}
