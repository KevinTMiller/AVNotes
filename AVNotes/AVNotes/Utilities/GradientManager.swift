//
//  GradientManager.swift
//  AVNotes
//
//  Created by Kevin Miller on 2/25/18.
//  Copyright © 2018 Kevin Miller. All rights reserved.
//

import UIKit

class GradientManager: NSObject {

    private lazy var managedViews = [UIView]()
    private lazy var index = UserDefaults.standard.value(forKey: "gradient") as? Int ?? 0
    private lazy var gradientLayer = CAGradientLayer()
    private lazy var keyDictionary = ["Vanusa", "eXpresso", "Red Sunset", "Taran Tado",
                                 "Purple Bliss"]
    private lazy var gradientDictionary: [String: [CGColor]] = [
        "Vanusa":       [UIColor(red: 0.85, green: 0.27, blue: 0.33, alpha: 1.0).cgColor,
                         UIColor(red: 0.54, green: 0.13, blue: 0.42, alpha: 1.0).cgColor],
        "eXpresso":     [UIColor(red: 0.68, green: 0.33, blue: 0.54, alpha: 1.0).cgColor,
                         UIColor(red: 0.24, green: 0.06, blue: 0.33, alpha: 1.0).cgColor],
        "Red Sunset":   [UIColor(red: 0.21, green: 0.36, blue: 0.49, alpha: 1.0).cgColor,
                         UIColor(red: 0.42, green: 0.36, blue: 0.48, alpha: 1.0).cgColor,
                         UIColor(red: 0.75, green: 0.42, blue: 0.52, alpha: 1.0).cgColor],
        "Taran Tado":   [UIColor(red: 0.14, green: 0.03, blue: 0.30, alpha: 1.0).cgColor,
                         UIColor(red: 0.80, green: 0.33, blue: 0.20, alpha: 1.0).cgColor],
        "Purple Bliss": [UIColor(red: 0.21, green: 0.00, blue: 0.20, alpha: 1.0).cgColor,
                         UIColor(red: 0.04, green: 0.53, blue: 0.58, alpha: 1.0).cgColor]
    ]

    // Eventually will implement user settings to select gradient
    // that's why using key here. Can refactor to accept a string
    // based on user choice
    func redrawGradients() {
        for view in managedViews {
            let gradient = createCAGradientLayer(for: view)
            gradient.colors = gradientDictionary[keyDictionary[index]]

            if let button = view as? UIButton,
                let imageView = button.imageView {
                button.bringSubview(toFront: imageView)
            }
            view.layer.addSublayer(gradient)
        }
    }
    
    func cycleGradient() {
        if index == keyDictionary.count - 1 { index = 0 } else { index += 1 }
        if let colors = gradientDictionary[keyDictionary[index]] {
            updateViewsWithGradient(colors)
        }
    }

    func addManagedView(_ view: UIView) {
        managedViews.append(view)
        let color = gradientDictionary[keyDictionary[0]]
        updateViewsWithGradient(color!)
    }

    func createCAGradientLayer(for view: UIView) -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.bounds = view.bounds
        gradientLayer.cornerRadius = view.layer.cornerRadius
        gradientLayer.position = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        return gradientLayer
    }

    private func updateViewsWithGradient(_ colors: [CGColor]) {
        for view in managedViews {
            let gradient = createCAGradientLayer(for: view)
            gradient.colors = colors

            if let view = view as? GradientView {
                view.gradientLayer.colors = colors
                view.layer.addSublayer(view.gradientLayer)
            }

            if let button = view as? UIButton,
                let imageView = button.imageView {
                view.layer.addSublayer(gradient)
                button.bringSubview(toFront: imageView)
            }
        }
    }
}