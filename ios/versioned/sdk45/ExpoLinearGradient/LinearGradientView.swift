// Copyright 2021-present 650 Industries. All rights reserved.

import UIKit
import ABI45_0_0ExpoModulesCore

final class LinearGradientView: ExpoView {
  override class var layerClass: AnyClass {
    return LinearGradientLayer.self
  }

  public var gradientLayer: LinearGradientLayer {
    return layer as! LinearGradientLayer
  }
}
