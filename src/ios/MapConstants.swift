//
//  MapConstants.swift
//  testPluginApp
//
//  Created by WebDev on 12/17/20.
//

import Foundation
import ArcGIS

struct ArcSettings {
 
    static let map_service = "https://arc7.thevillages.com/arcgis/rest/services/PUBLICMAP26/MapServer"
    static let geocode_server = "https://arc5.thevillages.com/arcgis/rest/services/TSGLOCATE2/GeocodeServer"
}

struct ArcLocation {
    var address: String = ""
    var longitude: Double = 0
    var latitude: Double = 0
    var route: RouteType = RouteType.CAR
}

enum RouteType: Int {
    case CAR, GOLF_CART
}

extension URL {
    static let worldRoutingService = URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!
    static let carRoutingService = URL(string: "https://arc7.thevillages.com/arcgis/rest/services/CARROUTES/NAServer/Route")!
    static let golfRoutingService = URL(string: "https://arc7.thevillages.com/arcgis/rest/services/GOLFCROUTE2/NAServer/Route")!
    static let villagesMapService = URL(string: "https://arc7.thevillages.com/arcgis/rest/services/PUBLICMAP26/MapServer")!
}
/// Add title property to arcgis load atatus
/// extension method
extension AGSLoadStatus {
    /// The human readable name of the load status.
    var title: String {
        switch self {
        case .loaded:
            return "Loaded"
        case .loading:
            return "Loading"
        case .failedToLoad:
            return "Failed to Load"
        case .notLoaded:
            return "Not Loaded"
        case .unknown:
            fallthrough
        @unknown default:
            return "Unknown"
        }
    }
}
