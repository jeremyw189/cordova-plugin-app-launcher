//
//  MapViewController.swift
//  testPluginApp
//
//  Created by Jay Bowman on 12/17/20.
//

import UIKit
import ArcGIS

class MapViewController: UIViewController {
    
    private var mapLoadStatusObservable: NSKeyValueObservation?
    private var inputParams: ArcLocation = ArcLocation()
    private var routeTask: AGSRouteTask?
    private var destination: AGSPoint?
  //  private var start: AGSPoint?
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mapView: AGSMapView! 
    @IBOutlet weak var navBar: UINavigationItem!
    @IBOutlet weak var navigateButtonBarItem: UIBarButtonItem!
    
    // MARK: Instance properties
     
    init (destination location: ArcLocation){
        super.init(nibName: nil, bundle: nil)
        licenseApplication()
        
        inputParams = location
        if inputParams.route == RouteType.CAR {
            routeTask = .init(url: .carRoutingService)
        } else {
            routeTask = .init(url: .golfRoutingService)
        }
        destination = AGSPoint(x: inputParams.longitude, y: inputParams.latitude, spatialReference: AGSSpatialReference.wgs84())
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction func closeBtn(_ sender: UIBarButtonItem) {
        findRoute()
    }
        
    @IBAction func recenter(_ sender: UIBarButtonItem) {
        mapView.locationDisplay.autoPanMode = .navigation
        sender.isEnabled = false
        mapView.locationDisplay.autoPanModeChangedHandler = { [weak self] _ in
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
            self?.mapView.locationDisplay.autoPanModeChangedHandler = nil
        }
    }
    
    @IBAction func directions(_ sender: UIBarButtonItem) {
    }
    
    @IBAction func stopNavigation() {
        mapView.locationDisplay.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.title = inputParams.address
      
        initMap() // use thevillages map
        
        addGraphics()
        
        endGraphic.geometry = destination
       
    }
    
    private func initMap() {
        let layer = AGSArcGISTiledLayer(url: .villagesMapService)
        let base = AGSBasemap(baseLayer: layer)
        mapView.map = AGSMap(basemap: base)
        let point = AGSPoint(x: LakesSumterLanding.longitude, y: LakesSumterLanding.latitude, spatialReference: AGSSpatialReference.wgs84())
        let vpoint = AGSViewpoint.init(center: point, scale: 54000)
        mapView.map!.initialViewpoint = vpoint
                
        mapLoadStatusObservable = mapView.map!.observe(\.loadStatus, options: .initial) { [weak self] (_, _) in
               //update the banner label on main thread
            DispatchQueue.main.async { [weak self] in
                 self?.updateLoadStatusLabel()
            }
            if self?.mapView.map?.loadStatus == .loaded {
                self?.setupLocationDisplay()
            }
        }
        mapView.touchDelegate = self
    }
    
//    private func setupMap() {
//        mapView.map = AGSMap(
//            basemapType: .navigationVector,
//            latitude: 28.82479334,
//            longitude: -81.98671583,
//            levelOfDetail: 11
//        )
//        mapView.touchDelegate = self
//    }
    /// Crreate an array of stops for navigation
    ///
    /// - Returns: An array of 'AGSStop' objects.
    func makeStops() -> [AGSStop] {
        let start = AGSStop(point: mapView.locationDisplay.mapLocation!)
        start.name = "Current Location"
        let end = AGSStop(point: destination!)
        end.name = inputParams.address
        return [start, end]
    }
    
 
    func setStatus(message: String){
        infoLabel.text = message
    }
 
     
    func setupLocationDisplay () {
       
        mapView.locationDisplay.autoPanMode = .compassNavigation
        mapView.locationDisplay.wanderExtentFactor = 0.5
        
        mapView.locationDisplay.start(completion: )  {[weak self] (error) in
            guard let self = self else {return}
            if let error = error {
                self.showError(error)
            } else {
                // no error set location as end point.
                //let start = self.mapView.locationDisplay.mapLocation!
              
            }
        }
    }
    
    func showError(_ error: Error){
        let alert = UIAlertController( title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        let dismiss = UIAlertAction (title: "Dismiss", style: .default, handler: nil)
        alert.addAction(dismiss)
        present(alert, animated: true, completion: nil)
    }
    
    func updateLoadStatusLabel(){
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Only reset when the route is successfully solved.
       // if routeResult != nil {
        //    stopNavigation()
       // }
    }
   
} // end class mapViewController

// MARK: - AGSRouteTrackerDelegate


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
    
    func findRoute(){
        let start = mapView.locationDisplay.mapLocation!
        let end = self.destination!
        solveRoute(start: start, end: end) {[weak self] (result) in
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
    
    func licenseApplication() {
        do {
            try AGSArcGISRuntimeEnvironment.setLicenseKey(.licenseKey)
        } catch {
            print("[Error: ArcGISRuntimeEnvronemnt] \(error.localizedDescription)")
        }
    }
}



struct LakesSumterLanding {
    // Y center point for the villages east of brownwood off of 44.
    static let latitude = 28.82479334
    // x
    static let longitude = -81.98671583
    // barns and knobles
    static let lslLong = -81.976787349
    static let lslLat =   28.908179615
    
    static let shooters_world = "Shooters World"
    static let swLat = 28.849218843817695
    static let swLong = -82.02131201965173
    
    // mvp -82.022588, 28.845312
    static let   address = "Cane Garden Country club"
    static let gisLong = -81.99463648
    static let gisLat = 28.89330536
}
