//
//  MapViewController.swift
//  testPluginApp
//
//  Created by Jay Bowman on 12/17/20.
//

import UIKit
import ArcGIS

class MapViewController: UIViewController {
    private let map_service = "https://arc7.thevillages.com/arcgis/rest/services/PUBLICMAP26/MapServer"
    private var mapLoadStatusObservable: NSKeyValueObservation?
    private var inputParams: ArcLocation = ArcLocation()
    private var routeTask: AGSRouteTask?
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var navBar: UINavigationBar!
    
    init (destination location: ArcLocation){
        super.init(nibName: nil, bundle: nil)
        inputParams = location
        if inputParams.route == RouteType.CAR {
            routeTask = .init(url: .carRoutingService)
        } else {
            routeTask = .init(url: .golfRoutingService)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction func closeBtn(_ sender: UIBarButtonItem) {
        removeFromParent()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMap()
        
        addGraphics()
       
    }
    
    private func initMap() {
        let layer = AGSArcGISTiledLayer(url: URL(string: map_service)!)
        let base = AGSBasemap(baseLayer: layer)
        //mapView.map = AGSMap(basemap: AGSBasemap.openStreetMap() )
        mapView.map = AGSMap(basemap: base)
        let point = AGSPoint(x: lslanding.longitude, y: lslanding.latitude, spatialReference: AGSSpatialReference.wgs84())
        let vpoint = AGSViewpoint.init(center: point, scale: 24000)
        
        mapView.map!.initialViewpoint = vpoint
        
        mapLoadStatusObservable = mapView.map!.observe(\.loadStatus, options: .initial) { [weak self] (_, _) in
               //update the banner label on main thread
               DispatchQueue.main.async { [weak self] in
                   self?.updateLoadStatusLabel()
               }          
        }
        mapView.touchDelegate = self
    }
    
    private func setupMap() {
        mapView.map = AGSMap(
            basemapType: .navigationVector,
            latitude: 28.82479334,
            longitude: -81.98671583,
            levelOfDetail: 11
        )
        mapView.touchDelegate = self
    }
    
    private func updateLoadStatusLabel(){
        infoLabel.text = "Status: \(mapView.map!.loadStatus.title)"
    }
    
    // MARK:- Route Builder
    
    private enum RouteBuilderStatus {
        case none
        case selectedStart(AGSPoint)
        case selectedStartAndEnd(AGSPoint, AGSPoint)
        case routeSolved(AGSPoint, AGSPoint, AGSPolyline)
    }
    
    private var status: RouteBuilderStatus = .none {
        didSet {
            switch status {
            case .none:
                startGraphic.geometry = nil
                endGraphic.geometry = nil
                routeGraphic.geometry = nil
            case .selectedStart(let start):
                startGraphic.geometry = start
                endGraphic.geometry = nil
                routeGraphic.geometry = nil
            case .selectedStartAndEnd(let start, let end):
                startGraphic.geometry = start
                endGraphic.geometry = end
                routeGraphic.geometry = nil
            case .routeSolved(let start, let end, let route):
                startGraphic.geometry = start
                endGraphic.geometry = end
                routeGraphic.geometry = route
            }
        }
    }
    
    // MARK:- Route Graphics
    
    private func addGraphics() {
        mapView.graphicsOverlays.add(routeGraphics)
        routeGraphics.graphics.addObjects(from: [routeGraphic, startGraphic, endGraphic])
    }
    
    private let routeGraphics = AGSGraphicsOverlay()
    
    // Build a graphic to symbolize the start point of the route.
    // The graphic is built with no geometry and without visibility.
    private lazy var startGraphic: AGSGraphic = {
        let symbol = AGSSimpleMarkerSymbol(style: .diamond, color: .orange, size: 8)
        symbol.outline = AGSSimpleLineSymbol(style: .solid, color: .blue, width: 2)
        let graphic = AGSGraphic(geometry: nil, symbol: symbol)
        return graphic
    }()
    
    // Build a graphic to symbolize the end point of the route.
    // The graphic is built with no geometry and without visibility.
    private lazy var endGraphic: AGSGraphic = {
        let symbol = AGSSimpleMarkerSymbol(style: .square, color: .green, size: 8)
        symbol.outline = AGSSimpleLineSymbol(style: .solid, color: .red, width: 2)
        let graphic = AGSGraphic(geometry: nil, symbol: symbol)
        return graphic
    }()
    
    // Build a graphic to symbolize the route polyline.
    // The graphic is built with no geometry and without visibility.
    private lazy var routeGraphic: AGSGraphic = {
        let symbol = AGSSimpleLineSymbol(style: .solid, color: .blue, width: 4)
        let graphic = AGSGraphic(geometry: nil, symbol: symbol)
        return graphic
    }()
    
    // MARK:- Route Task
  
    private var currentSolveRouteOperation: AGSCancelable?

    private func solveRoute(start: AGSPoint, end: AGSPoint, completion: @escaping (Result<[AGSRoute], Error>) -> Void) {
        
        currentSolveRouteOperation?.cancel()
                
        currentSolveRouteOperation = routeTask!.defaultRouteParameters { [weak self] (defaultParameters, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let params = defaultParameters else { return }
            params.setStops([AGSStop(point: start), AGSStop(point: end)])

            self.currentSolveRouteOperation = self.routeTask!.solveRoute(with: params) { (routeResult, error) in
                
                if let routes = routeResult?.routes {
                    completion(.success(routes))
                }
                else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
   
} // end class mapViewController

// MARK:- GeoView Touch Delegate
extension MapViewController: AGSGeoViewTouchDelegate {
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        
        currentSolveRouteOperation?.cancel()
        
        switch status {
        case .none:
            status = .selectedStart(mapPoint)
        case .selectedStart(let start):
            status = .selectedStartAndEnd(start, mapPoint)
        case .selectedStartAndEnd(_, _):
            status = .selectedStart(mapPoint)
        case .routeSolved(_, _, _):
            status = .selectedStart(mapPoint)
        }
        
        if case let .selectedStartAndEnd(start, end) = status {
            
            solveRoute(start: start, end: end) { [weak self] (result) in
                guard let self = self else { return }
                
                switch result {
                case .failure(let error):
                    print(error.localizedDescription)
                    self.status = .none
                case .success(let routes):
                    if let line = routes.first?.routeGeometry {
                        self.status = .routeSolved(start, end, line)
                    }
                    else {
                        self.status = .none
                    }
                }
            }
        }
    }
    
    func licenseApplication() {
        do {
            try AGSArcGISRuntimeEnvironment.setLicenseKey(.licenseKey)
        } catch {
            print("[Error: ArcGISRuntimeEnvronemnt] \(error.localizedDescription)")
        }
    }
}

// extension method
private extension AGSLoadStatus {
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

struct lslanding {
    // Y center point for the villages
    static let latitude = 28.82479334
    // x
    static let longitude = -81.98671583
}
