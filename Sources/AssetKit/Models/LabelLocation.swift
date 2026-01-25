import Foundation
import CastleMindrModels

/// Location where the appliance label was found (user selection)
public enum LabelLocation: String, CaseIterable, Codable, Sendable, Equatable {
    case insideLeftDoor = "inside_left_door"
    case insideRightDoor = "inside_right_door"
    case backPanel = "back_panel"
    case sideLeft = "side_left"
    case sideRight = "side_right"
    case topEdge = "top_edge"
    case bottomEdge = "bottom_edge"
    case behindAccessPanel = "behind_access_panel"
    case drawerFront = "drawer_front"
    case insideFrame = "inside_frame"
    case other = "other"
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .insideLeftDoor: return "Inside Left Door"
        case .insideRightDoor: return "Inside Right Door"
        case .backPanel: return "Back Panel"
        case .sideLeft: return "Left Side"
        case .sideRight: return "Right Side"
        case .topEdge: return "Top Edge"
        case .bottomEdge: return "Bottom Edge"
        case .behindAccessPanel: return "Behind Access Panel"
        case .drawerFront: return "Drawer Front"
        case .insideFrame: return "Inside Frame"
        case .other: return "Other"
        }
    }
    
    /// SF Symbol icon for picker
    public var iconName: String {
        switch self {
        case .insideLeftDoor: return "door.left.hand.open"
        case .insideRightDoor: return "door.right.hand.open"
        case .backPanel: return "rectangle.portrait"
        case .sideLeft: return "rectangle.lefthalf.filled"
        case .sideRight: return "rectangle.righthalf.filled"
        case .topEdge: return "rectangle.tophalf.filled"
        case .bottomEdge: return "rectangle.bottomhalf.filled"
        case .behindAccessPanel: return "rectangle.badge.minus"
        case .drawerFront: return "tray"
        case .insideFrame: return "rectangle.inset.filled"
        case .other: return "questionmark.square"
        }
    }
    
    /// Common locations filtered by appliance category
    public static func commonLocations(for category: ApplianceCategory) -> [LabelLocation] {
        if category == .refrigerator {
            return [.insideLeftDoor, .insideRightDoor, .backPanel, .sideLeft]
        } else if category == .washer || category == .dryer {
            return [.insideFrame, .backPanel, .topEdge, .sideLeft]
        } else if category == .dishwasher {
            return [.insideFrame, .sideLeft, .sideRight]
        } else if category == .oven || category == .microwave {
            return [.insideFrame, .backPanel, .sideLeft]
        } else if category == .hvac {
            return [.behindAccessPanel, .sideLeft, .sideRight]
        } else if category == .waterHeater {
            return [.sideLeft, .sideRight, .backPanel]
        } else {
            return [.backPanel, .sideLeft, .sideRight, .other]
        }
    }
}
