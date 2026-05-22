import Cocoa

class MenuTracker {
  static let shared = MenuTracker()

  private var monitorTimer: Timer?
  private var countdownTimer: Timer?
  private var wasMenuDetected = false
  private var delay: Double = -1
  private var checksSinceStart = 0
  private var completion: (() -> Void)?

  func startTracking(delay: Double, completion: @escaping () -> Void) {
    self.delay = delay
    self.completion = completion

    monitorTimer?.invalidate()
    countdownTimer?.invalidate()
    wasMenuDetected = false
    checksSinceStart = 0

    if delay < 0 { return }

    monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      guard let self = self else { return }

      let menuVisible = self.isMenuWindowOpen()
      self.checksSinceStart += 1

      if menuVisible {
        self.wasMenuDetected = true
        self.countdownTimer?.invalidate()
        self.countdownTimer = nil
      } else {
        if self.wasMenuDetected {
          // Menu was open but is now closed. Start the countdown.
          self.wasMenuDetected = false
          self.startCountdown()
        } else if self.countdownTimer == nil && self.checksSinceStart >= 5 {
          // 1 second grace period passed and no menu opened. Start the countdown.
          self.startCountdown()
        }
      }
    }
  }

  func stopTracking() {
    monitorTimer?.invalidate()
    countdownTimer?.invalidate()
    monitorTimer = nil
    countdownTimer = nil
  }

  private func startCountdown() {
    countdownTimer?.invalidate()

    countdownTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
      [weak self] _ in
      self?.completion?()
      self?.stopTracking()
    }
  }

  private func isMenuWindowOpen() -> Bool {
    let options = CGWindowListOption.optionOnScreenOnly
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
    else {
      return false
    }

    for window in windowList {
      if let layer = window[kCGWindowLayer as String] as? Int32 {
        // Layer 101 is kCGPopUpMenuWindowLevel, used for dropdowns/menus
        if layer == 101 {
          return true
        }
      }
    }
    return false
  }
}
