//
//  GeminiUsageTracker.swift
//  AssetKit
//
//  Created by Jim Bergren on 3/4/26.
//

import Foundation
import os.log

private let usageLog = Logger(subsystem: "com.castlemindr.AssetKit", category: "GeminiUsage")

/// Tracks AI asset ingestion usage using backend-provided cap data.
///
/// The host app should call `syncFromProfile(limit:remaining:)` after
/// fetching the user profile so cap decisions reflect the backend's
/// single source of truth. Between profile refreshes the tracker
/// keeps a local `remaining` counter that decrements on each call.
public final class GeminiUsageTracker {

    public static let shared = GeminiUsageTracker()

    /// Backend-provided limit (nil = unlimited).
    public private(set) var limit: Int?

    /// Backend-provided remaining count (nil = unlimited).
    public private(set) var remaining: Int?

    /// When true, cap is ignored entirely. Set via launch argument
    /// `-GEMINI_UNLIMITED YES` in Xcode scheme for dev/testing.
    public var unlimitedOverride: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-GEMINI_UNLIMITED")
        #else
        return false
        #endif
    }()

    public init() {}

    /// Sync cap data from the backend user profile response.
    /// Call this after fetching the profile (e.g., on app launch or after auth change).
    ///
    /// - Parameters:
    ///   - limit: `assetIngestionLimit` from UserProfileResponse (nil = unlimited).
    ///   - remaining: `assetIngestionRemaining` from UserProfileResponse (nil = unlimited).
    public func syncFromProfile(limit: Int?, remaining: Int?) {
        self.limit = limit
        self.remaining = remaining
        usageLog.info("Synced caps from profile: limit=\(limit.map(String.init) ?? "unlimited"), remaining=\(remaining.map(String.init) ?? "unlimited")")
    }

    /// Returns true if a Gemini call is allowed.
    /// Premium/beta/dev users are unlimited. Capped users check `remaining`.
    public func canUseGemini(isPremium: Bool = false) -> Bool {
        if unlimitedOverride || isPremium {
            usageLog.info("Gemini usage check: UNLIMITED (\(isPremium ? "premium" : "dev override"))")
            return true
        }
        guard let remaining = remaining else {
            // nil remaining = unlimited (pro+, beta, or profile not loaded yet — allow)
            return true
        }
        let allowed = remaining > 0
        usageLog.info("Gemini usage check: remaining=\(remaining)/\(self.limit.map(String.init) ?? "?") — \(allowed ? "allowed" : "capped")")
        return allowed
    }

    /// Record a Gemini call. Decrements the local remaining counter.
    /// The backend increments its own counter when the Cloud Function runs,
    /// so this is just for immediate UI feedback between profile refreshes.
    public func recordUsage() {
        if let current = remaining, current > 0 {
            remaining = current - 1
            usageLog.info("Gemini usage recorded — remaining: \(current - 1)")
        }
    }

    /// Current remaining count for UI display (nil = unlimited).
    public var remainingCount: Int? {
        remaining
    }
}
