//
//  GeminiUsageTracker.swift
//  AssetKit
//
//  Created by Jim Bergren on 3/4/26.
//

import Foundation
import os.log

private let usageLog = Logger(subsystem: "com.castlemindr.AssetKit", category: "GeminiUsage")

/// Tracks daily Gemini API call count in UserDefaults.
/// Enforces a per-day cap for non-premium users.
public final class GeminiUsageTracker {

    public static let shared = GeminiUsageTracker()

    private let defaults: UserDefaults
    private let countKey = "gemini_daily_count"
    private let dateKey = "gemini_daily_date"

    /// Default free-tier daily cap
    public var dailyCap: Int = 5

    /// When true, cap is ignored entirely. Set via launch argument
    /// `-GEMINI_UNLIMITED YES` in Xcode scheme for dev/testing.
    public var unlimitedOverride: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-GEMINI_UNLIMITED")
        #else
        return false
        #endif
    }()

    public init(suiteName: String = "com.castlemindr.AssetKit.usage") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// Returns true if a Gemini call is allowed (under daily cap).
    /// Cap applies to all users — Gemini calls cost real money.
    /// The `isPremium` flag is reserved for future per-tier caps.
    public func canUseGemini(isPremium: Bool = false) -> Bool {
        if unlimitedOverride {
            usageLog.info("Gemini usage check: UNLIMITED (dev override)")
            return true
        }
        resetIfNewDay()
        let count = defaults.integer(forKey: countKey)
        let allowed = count < dailyCap
        usageLog.info("Gemini usage check: \(count)/\(self.dailyCap) — \(allowed ? \"allowed\" : \"capped\")")
        return allowed
    }

    /// Record a Gemini call. Call this after a successful Gemini request.
    public func recordUsage() {
        resetIfNewDay()
        let current = defaults.integer(forKey: countKey)
        defaults.set(current + 1, forKey: countKey)
        usageLog.info("Gemini usage recorded: \(current + 1)/\(self.dailyCap)")
    }

    /// Current usage count today (for UI if needed later).
    public var todayCount: Int {
        resetIfNewDay()
        return defaults.integer(forKey: countKey)
    }

    private func resetIfNewDay() {
        let today = calendarDayString()
        let stored = defaults.string(forKey: dateKey)
        if stored != today {
            defaults.set(0, forKey: countKey)
            defaults.set(today, forKey: dateKey)
            usageLog.info("Gemini usage reset for new day: \(today)")
        }
    }

    private func calendarDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
