import Foundation
import CastleMindrModels

/// Location where the appliance label was found (user selection)
public enum LabelLocation: String, CaseIterable, Codable, Sendable, Equatable {
    // Door locations
    case insideLeftDoor = "inside_left_door"
    case insideRightDoor = "inside_right_door"
    case insideDoor = "inside_door"               // Generic inside door (dryers, ovens)

    // Frame & edges
    case insideFrame = "inside_frame"              // Door frame opening (washers, dishwashers)
    case topEdge = "top_edge"
    case bottomEdge = "bottom_edge"
    case underside = "underside"                   // Flipped upside down / underneath

    // Panels
    case backPanel = "back_panel"
    case sideLeft = "side_left"
    case sideRight = "side_right"
    case frontPanel = "front_panel"                // Near controls (water heaters, HVAC)
    case behindAccessPanel = "behind_access_panel" // Must remove cover

    // Specific areas
    case underLid = "under_lid"                    // Top-loader washers, chest freezers
    case drawerFront = "drawer_front"
    case nearControls = "near_controls"            // Near knobs/buttons
    case nearFilter = "near_filter"                // HVAC filter slot area
    case nearPipes = "near_pipes"                  // Water heater pipe connections
    case onCompressor = "on_compressor"            // Fridge/AC compressor
    case insideCabinet = "inside_cabinet"          // Built-in appliances

    // Catch-all
    case other = "other"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .insideLeftDoor: return "Inside Left Door"
        case .insideRightDoor: return "Inside Right Door"
        case .insideDoor: return "Inside Door"
        case .insideFrame: return "Inside Frame"
        case .topEdge: return "Top Edge"
        case .bottomEdge: return "Bottom Edge"
        case .underside: return "Underside"
        case .backPanel: return "Back Panel"
        case .sideLeft: return "Left Side"
        case .sideRight: return "Right Side"
        case .frontPanel: return "Front Panel"
        case .behindAccessPanel: return "Behind Access Panel"
        case .underLid: return "Under Lid"
        case .drawerFront: return "Drawer Front"
        case .nearControls: return "Near Controls"
        case .nearFilter: return "Near Filter"
        case .nearPipes: return "Near Pipes"
        case .onCompressor: return "On Compressor"
        case .insideCabinet: return "Inside Cabinet"
        case .other: return "Other"
        }
    }

    /// SF Symbol icon for picker
    public var iconName: String {
        switch self {
        case .insideLeftDoor: return "door.left.hand.open"
        case .insideRightDoor: return "door.right.hand.open"
        case .insideDoor: return "door.left.hand.open"
        case .insideFrame: return "rectangle.inset.filled"
        case .topEdge: return "rectangle.tophalf.filled"
        case .bottomEdge: return "rectangle.bottomhalf.filled"
        case .underside: return "arrow.turn.right.down"
        case .backPanel: return "rectangle.portrait"
        case .sideLeft: return "rectangle.lefthalf.filled"
        case .sideRight: return "rectangle.righthalf.filled"
        case .frontPanel: return "rectangle.portrait.fill"
        case .behindAccessPanel: return "rectangle.badge.minus"
        case .underLid: return "menubar.arrow.up.rectangle"
        case .drawerFront: return "tray"
        case .nearControls: return "slider.horizontal.3"
        case .nearFilter: return "aqi.medium"
        case .nearPipes: return "pipe.and.drop"
        case .onCompressor: return "gearshape"
        case .insideCabinet: return "cabinet.fill"
        case .other: return "questionmark.square"
        }
    }

    /// Common locations filtered by appliance category string (shown first in picker)
    public static func commonLocations(for category: String) -> [LabelLocation] {
        let category = ApplianceCategory(rawValue: category)
        switch category {
        case .refrigerator:
            return [.insideLeftDoor, .insideRightDoor, .backPanel, .sideLeft, .onCompressor]
        case .washer:
            return [.insideFrame, .backPanel, .underLid, .topEdge, .sideLeft]
        case .dryer:
            return [.insideFrame, .insideDoor, .backPanel, .topEdge, .sideLeft]
        case .dishwasher:
            return [.insideFrame, .insideDoor, .sideLeft, .sideRight, .topEdge]
        case .oven, .microwave:
            return [.insideFrame, .insideDoor, .backPanel, .sideLeft, .nearControls]
        case .hvac:
            return [.behindAccessPanel, .sideLeft, .sideRight, .nearFilter, .frontPanel]
        case .waterHeater:
            return [.frontPanel, .sideLeft, .sideRight, .nearPipes, .backPanel]
        default:
            return [.backPanel, .sideLeft, .sideRight, .insideFrame, .frontPanel]
        }
    }

    /// All remaining locations not in the common set for a category
    public static func additionalLocations(for category: String) -> [LabelLocation] {
        let common = Set(commonLocations(for: category))
        return allCases.filter { $0 != .other && !common.contains($0) }
    }
}
