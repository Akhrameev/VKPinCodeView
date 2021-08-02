//
//  CustomizableUnderlineStyle.swift
//  VKPinCodeView
//
//  Created by Pavel Akhrameev on 20.07.21.
//  Copyright © 2021 Pavel Akhrameev. All rights reserved.
//

import UIKit

public final class CustomizableUnderlineStyle: EntryViewStyle {

    public class Color: NSObject {
        public enum State {
            case error, selected, empty, filled
        }

        private(set) var visible: Bool = false

        final func color(state: State) -> UIColor {
            return colors(state: state).first ?? .clear
        }

        func colors(state: State) -> [UIColor] {
            return [.clear]
        }
    }

    public final class ClearColor: Color {}
    public final class SolidColor: Color {
        let storedColor: UIColor

        override var visible: Bool {
            return true
        }

        public init(color: UIColor) {
            storedColor = color
        }

        override func colors(state: Color.State) -> [UIColor] {
            return [storedColor]
        }
    }

    public typealias ColorsForState = ((CustomizableUnderlineStyle.Color.State) -> [UIColor])
    public final class LambdaColor: Color {
        let lambda: ColorsForState

        override var visible: Bool {
            return true
        }

        public init(lambda: @escaping ColorsForState) {
            self.lambda = lambda
        }

        override func colors(state: Color.State) -> [UIColor] {
            return lambda(state)
        }
    }

    private var _cursor = CAShapeLayer()

    private var _line = CAShapeLayer()

    private var _font: UIFont

    private var _textColor: Color

    private var _cursorColor: Color

    private var _lineColor: Color

    private var _lineWidth: CGFloat

    private var _lineCapStyle: CGLineCap

    public required init(
        font: UIFont = UIFont.systemFont(ofSize: 22),
        textColor: Color = SolidColor(color: .black),
        cursorColor: Color = ClearColor(),
        lineColor: Color = SolidColor(color: .black),
        lineWidth: CGFloat = 1,
        lineCapStyle: CGLineCap = .butt) {

        _font = font
        _textColor = textColor
        _cursorColor = cursorColor
        _lineColor = lineColor
        _lineWidth = lineWidth
        _lineCapStyle = lineCapStyle
    }

    public func onSetStyle(_ label: VKLabel) {

        updateCursorPath(label)
        updateLinePath(label)
        updateColors(label)

        label.layer.addSublayer(_line)
        label.layer.addSublayer(_cursor)

        label.font = _font
        label.textAlignment = .center
    }

    public func onUpdateSelectedState(_ label: VKLabel) {

        updateColors(label)
        updateAnimations(label)
    }

    public func onUpdateErrorState(_ label: VKLabel) {

        updateColors(label)
        updateAnimations(label)
    }

    public func onLayoutSubviews(_ label: VKLabel) {

        updateCursorPath(label)
        updateLinePath(label)
    }

    private func updateCursorPath(_ label: VKLabel) {

        let width: CGFloat = 2

        let bounds = label.bounds
        let topY = bounds.midY - bounds.maxX / 2
        let path = UIBezierPath(roundedRect: CGRect(x: bounds.midX - width / 2,
                                                    y: topY,
                                                    width: width,
                                                    height: bounds.maxX),
                                cornerRadius: width / 2)
        _cursor.path = path.cgPath
    }

    private func updateLinePath(_ label: VKLabel) {

        let bounds = label.bounds
        let topY = bounds.maxY - _lineWidth
        let path = UIBezierPath(roundedRect: CGRect(x: bounds.minX,
                                                    y: topY,
                                                    width: bounds.width,
                                                    height: _lineWidth),
                                cornerRadius: _lineCapStyle == .round ? _lineWidth / 2 : 0)
        _line.path = path.cgPath
    }

    private func updateColors(_ label: VKLabel) {
        let state = state(label)
        _line.fillColor = _lineColor.color(state: state).cgColor
        _cursor.fillColor = _cursorColor.color(state: state).cgColor
        label.textColor = _textColor.color(state: state)
    }

    private func updateAnimations(_ label: VKLabel) {
        updateCursorAnimation(label)
        updateLineAnimation(label)
    }

    private func updateCursorAnimation(_ label: VKLabel) {
        let colors = _cursorColor.colors(state: state(label)).map { $0.cgColor }
        guard colors.count > 1 else {
            _cursor.removeAllAnimations()
            return
        }
        let animation = animateSelection(keyPath: #keyPath(CAShapeLayer.fillColor), values: colors)
        animation.duration = 2
        _cursor.add(animation, forKey: "fillColorAnimation")
    }

    private func updateLineAnimation(_ label: VKLabel) {
        let colors = _lineColor.colors(state: state(label)).map { $0.cgColor }
        let forceRemoveAnimation = label.isSelected && !label.animateWhileSelected
        guard colors.count > 1, !forceRemoveAnimation else {
            _line.removeAllAnimations()
            return
        }
        let animation = animateSelection(keyPath: #keyPath(CAShapeLayer.fillColor), values: colors)
        _line.add(animation, forKey: "fillColorAnimation")
    }

    private func state(_ label: VKLabel) -> Color.State {
        guard !label.isError else { return .error }
        guard !label.isSelected else { return .selected }
        guard let text = label.text, !text.isEmpty else { return .empty }
        return .filled
    }
}
