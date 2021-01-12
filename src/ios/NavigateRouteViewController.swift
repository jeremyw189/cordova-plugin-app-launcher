//
//  NavigateRouteViewController.swift
//  testPluginApp
//
//  Created by WebDev on 12/31/20.
//
import ArcGIS
import UIKit
import AVFoundation

class NavigateRouteViewController: UIViewController {
    private var mapLoadStatusObservable: NSKeyValueObservation?
    private var inputParams: ArcLocation = ArcLocation()
       
    @IBOutlet var navTitle: UINavigationItem!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var navigationBarButtonItem: UIBarButtonItem!
    @IBOutlet var resetBarButtonItem: UIBarButtonItem!
    @IBOutlet var recenterBarButtonItem: UIBarButtonItem!
    @IBOutlet var mapView: AGSMapView! {
        didSet {
            
            // this is now working
            mapView.locationDisplay.dataSourceStatusChangedHandler = { [weak self] (change) in
              // print("* * * locatin change event * * *")
                guard let self = self else {return}
                print("*** Location status change event.")
                // no error set location as end point.
                self.currentLocation = self.mapView.locationDisplay.mapLocation!
                print(self.currentLocation ?? "location not set")
            }
            
            initMap()
        }
    }
    
    // MARK: Instance properties
       /// Current location from mapview locationdisplay
       var currentLocation: AGSPoint!
       /// The route task to solve the route between stops, using the online routing service.
       var routeTask = AGSRouteTask(url: .carRoutingService)
       /// The route result solved by the route task.
       var routeResult: AGSRouteResult!
       /// The route tracker for navigation. Use delegate methods to update tracking status.
       var routeTracker: AGSRouteTracker!
       /// A list to keep track of directions solved by the route task.
       var directionsList: [AGSDirectionManeuver] = []       
       /// The original view point that can be reset later on.
       var defaultViewPoint: AGSViewpoint?
       /// The initial location for the solved route.
       var initialLocation: AGSLocation!
       /// The graphic (with a dashed line symbol) to represent the route ahead.
       let routeAheadGraphic = AGSGraphic(geometry: nil, symbol: AGSSimpleLineSymbol(style: .solid, color: .systemRed, width: 3))
       /// The graphic to represent the route that's been traveled (initially empty).
       let routeTraveledGraphic = AGSGraphic(geometry: nil, symbol: AGSSimpleLineSymbol(style: .solid, color: .systemBlue, width: 3))
       /// A formatter to format a time value into human readable string.
       let timeFormatter: DateComponentsFormatter = {
           let formatter = DateComponentsFormatter()
           formatter.allowedUnits = [.hour, .minute, .second]
           formatter.unitsStyle = .full
           return formatter
       }()
       /// An AVSpeechSynthesizer for text to speech.
       let speechSynthesizer = AVSpeechSynthesizer()
       
       // MARK: Instance methods
    
    init (location: ArcLocation){
        super.init(nibName: nil, bundle: nil)
        licenseApplication()
        
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
    
    func licenseApplication() {
        do {
            try AGSArcGISRuntimeEnvironment.setLicenseKey(.licenseKey)
        } catch {
            print("[Error: ArcGISRuntimeEnvronemnt] \(error.localizedDescription)")
        }
    }
    
    func initMap() {
        let layer = AGSArcGISTiledLayer(url: .villagesMapService)
        let base = AGSBasemap(baseLayer: layer)
        mapView.map = AGSMap(basemap: base)
        let point = AGSPoint(x: LakesSumterLanding.longitude, y: LakesSumterLanding.latitude, spatialReference: AGSSpatialReference.wgs84())
        let vpoint = AGSViewpoint.init(center: point, scale: 54000)
        mapView.map!.initialViewpoint = vpoint
                
        mapLoadStatusObservable = mapView.map!.observe(\.loadStatus, options: .initial) { [weak self] (_, _) in
               //update the banner label on main thread
            DispatchQueue.main.async { [weak self] in
                self?.setStatus(message: "Status: \(String(describing: self?.mapView.map!.loadStatus.title))")
            }
            if self?.mapView.map?.loadStatus == .loaded {
               self?.setupLocationDisplay()
            }
        }
       // mapView.touchDelegate = self
    }
    
    func setupLocationDisplay () {
        mapView.locationDisplay.autoPanMode = .navigation
        mapView.locationDisplay.wanderExtentFactor = 0.5
        
        mapView.locationDisplay.start(completion:) {[weak self] (error) in
            guard let self = self else {return}
            if let error = error {
                print(error)
                return
            }
            
            if self.mapView.locationDisplay.started {
                print("Location display started.")
            }
        }
    }
    
    
    /// A wrapper function for operations after the route is solved by an `AGSRouteTask`.
    ///
    /// - Parameter routeResult: The result from `AGSRouteTask.solveRoute(with:completion:)`.
    func didSolveRoute(with routeResult: Result<AGSRouteResult, Error>) {
        switch routeResult {
        case .success(let routeResult):
            self.routeResult = routeResult
            setNavigation(with: routeResult)
            navigationBarButtonItem.isEnabled = true
        case .failure(let error):
            presentAlert(error: error)
            setStatus(message: "Failed to solve route.")
            navigationBarButtonItem.isEnabled = false
        }
    }
    
    func presentAlert(error: Error){
        let alert = UIAlertController( title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        let dismiss = UIAlertAction (title: "Dismiss", style: .default, handler: nil)
        alert.addAction(dismiss)
        present(alert, animated: true, completion: nil)
    }
    
    /// Create the stops for the navigation.
    ///
    /// - Returns: An array of `AGSStop` objects.
    func makeStops() -> [AGSStop] {
        // default to sumter landing if we don't have a valid gps location.
        let p1 =  AGSPoint(x: LakesSumterLanding.lslLong, y: LakesSumterLanding.lslLat, spatialReference: .wgs84())
        let stop1 = AGSStop(point: currentLocation ?? p1)
        stop1.name = "Starting location"
       
        let stop2 = AGSStop(point: AGSPoint( x: inputParams.longitude, y: inputParams.latitude, spatialReference: .wgs84()))
        stop2.name = inputParams.address
        
        return [stop1, stop2]
    }
    
    /// Make the simulated data source for this demo.
    ///
    /// - Parameter route: An `AGSRoute` object whose geometry is used to configure the data source.
    /// - Returns: An `AGSSimulatedLocationDataSource` object.
    func makeDataSource(route: AGSRoute) -> AGSSimulatedLocationDataSource {
        let densifiedRoute = AGSGeometryEngine.geodeticDensifyGeometry(route.routeGeometry!, maxSegmentLength: 60.0, lengthUnit: .meters(), curveType: .geodesic) as! AGSPolyline
        // The mock data source to demo the navigation. Use delegate methods to update locations for the tracker.
        let mockDataSource = AGSSimulatedLocationDataSource()
        mockDataSource.setLocationsWith(densifiedRoute)
        //mockDataSource.setLocationsWith(route.routeGeometry!)
        
        mockDataSource.locationChangeHandlerDelegate = self
        return mockDataSource
    }
     
    /// Make a route tracker to provide navigation information.
    ///
    /// - Parameter result: An `AGSRouteResult` object used to configure the route tracker.
    /// - Returns: An `AGSRouteTracker` object.
    func makeRouteTracker(result: AGSRouteResult) -> AGSRouteTracker {
        let tracker = AGSRouteTracker(routeResult: result, routeIndex: 0, skipCoincidentStops: true)!
        tracker.delegate = self
        tracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
        
        return tracker
    }
    
    /// Make a graphics overlay with graphics and add to mapView
    ///
    /// - Returns: An `AGSGraphicsOverlay` object.
    func makeRouteOverlay() -> AGSGraphicsOverlay {
        // The graphics overlay for the polygon and points.
        let graphicsOverlay = AGSGraphicsOverlay()
        let stopSymbol = AGSSimpleMarkerSymbol(style: .diamond, color: .orange, size: 20)
      
        let stopGraphics = makeStops().map { AGSGraphic(geometry: $0.geometry, symbol: stopSymbol) }
        
        let routeGraphics = [routeAheadGraphic, routeTraveledGraphic]
        // Add graphics to the graphics overlay.
        graphicsOverlay.graphics.addObjects(from: routeGraphics + stopGraphics)
        return graphicsOverlay
    }
    
    /// Update the viewpoint so that it reflects the original viewpoint when the example is loaded.
    ///
    /// - Parameter result: An `AGSGeometry` object used to update the view point.
    func updateViewpoint(geometry: AGSGeometry) {
        // Show the resulting route on the map and save a reference to the route.
        if let viewPoint = defaultViewPoint {
            // Reset to initial view point with animation.
            mapView.setViewpoint(viewPoint, completion: nil)
        } else {
            mapView.setViewpointGeometry(geometry) { [weak self] _ in
                // Get the initial zoomed view point.
                self?.defaultViewPoint = self?.mapView.currentViewpoint(with: .centerAndScale)
            }
        }
    }
    
    /// Set route tracker, data source and location display with a solved route result.
    ///
    /// - Parameter routeResult: An `AGSRouteResult` object.
    func setNavigation(with routeResult: AGSRouteResult) {
        // Set the route tracker
        routeTracker = makeRouteTracker(result: routeResult)
        
        // add rerouteing
        if  routeTask.routeTaskInfo().supportsRerouting {
            routeTracker.enableRerouting(with: routeTask, routeParameters: routeParameters, strategy: AGSReroutingStrategy.toNextWaypoint, visitFirstStopOnStart: false)
            { (error) in
                if let error = error {
                    print(error)
                    return
                }
                // rerouting is enabled
                self.setStatus(message: "Rerouting is enabled!")
              
            }
        }
              
        let firstRoute = routeResult.routes.first!
        directionsList = firstRoute.directionManeuvers
        
        // Set the mock location data source.
        //let mockDataSource = makeDataSource(route: firstRoute)
        //initialLocation = mockDataSource.locations?.first       
        //let routeTrackerLocationDataSource = AGSRouteTrackerLocationDataSource(routeTracker: routeTracker, locationDataSource: mockDataSource)
        
        // MARK: For production use system location data source
        let routeTrackerLocationDataSource = AGSRouteTrackerLocationDataSource(routeTracker: routeTracker, locationDataSource: mapView.locationDisplay.dataSource)
        routeTrackerLocationDataSource.locationChangeHandlerDelegate = self
              
        // Set location display.
        mapView.locationDisplay.dataSource = routeTrackerLocationDataSource
        
        recenter()
        
        // Update graphics and viewpoint.
        let firstRouteGeometry = firstRoute.routeGeometry!
        updateRouteGraphics(remaining: firstRouteGeometry)
        updateViewpoint(geometry: firstRouteGeometry)
    }
    
    // MARK: UI
    
    func setStatus(message: String) {
        statusLabel.text = message
    }
    
    // MARK: Actions
    
    @IBAction func directionsButton(_ sender: Any) {
        // show modal popup
        var dirlist = [String]()
        for item in directionsList {
            dirlist.append(item.directionText )           
        }
        let listModalView = DirectionsViewController(directions: dirlist)
        listModalView.modalPresentationStyle = .automatic
        self.present(listModalView, animated: true, completion: nil)
        
    }
    @IBAction func navBarBackButton(_ sender: UIBarButtonItem) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func startnavigation(_ sender: Any) {
      
        navigationBarButtonItem.isEnabled = false
        resetBarButtonItem.isEnabled = true
        // Start the location data source and location display.
        mapView.locationDisplay.start(completion: ) { (error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        reset()
    }
    
    func reset() {
         // Stop the speech, if there is any.
        speechSynthesizer.stopSpeaking(at: .immediate)
        // Reset to the starting location for location display.
        //mapView.locationDisplay.dataSource.didUpdate(initialLocation)
        // Stop the location display as well as datasource generation, if reset before the end is reached.
        mapView.locationDisplay.stop()
        mapView.locationDisplay.autoPanModeChangedHandler = nil
        mapView.locationDisplay.autoPanMode = .off
        directionsList.removeAll()
        setStatus(message: "Directions are shown here.")
        
        // Reset the navigation.
        setNavigation(with: routeResult)
        // Reset buttons state.
        resetBarButtonItem.isEnabled = false
        navigationBarButtonItem.isEnabled = true
    }
    
    @IBAction func recenter(_ sender: UIBarButtonItem) {
           recenter()
    }
    func recenter() {
        mapView.locationDisplay.autoPanMode = .navigation
        recenterBarButtonItem.isEnabled = false
        mapView.locationDisplay.autoPanModeChangedHandler = { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.recenterBarButtonItem.isEnabled = true
            }
            self?.mapView.locationDisplay.autoPanModeChangedHandler = nil
        }
    }
    
    // MARK: UIViewController
    var routeParameters: AGSRouteParameters!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Add the source code button item to the right of navigation bar.
        //(navigationItem.rightBarButtonItem as? SourceCodeBarButtonItem)?.filenames = //["NavigateRouteViewController"]
        // Avoid the overlap between the status label and the map content.
        
        navTitle.title = inputParams.address
        let navigationBarAppearance = UINavigationBar.appearance();
        navigationBarAppearance.tintColor = UIColor.white
        //navigationBarAppearance.barTintColor = UIColor(red: 0, green: 73, blue: 44, alpha: 0)
        navigationBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor:UIColor.white]
        
        mapView.contentInset.top = CGFloat(statusLabel.numberOfLines) * statusLabel.font.lineHeight
               
    }
    override func viewDidAppear(_ animated: Bool) {
              
        print(self.currentLocation ?? "location not set view appearing")
        
        mapView.graphicsOverlays.add(makeRouteOverlay())
        
        solveRoute()
    }
    
    func solveRoute() {
        if mapView.locationDisplay.started {
            mapView.locationDisplay.stop()
        }
     
        // Solve the route as map loads.
        routeTask.defaultRouteParameters { [weak self] (params: AGSRouteParameters?, error: Error?) in
            guard let self = self else { return }
            if let params = params {
                // Explicitly set values for parameters.
                params.returnDirections = true
                params.returnStops = true
                params.returnRoutes = true
                params.outputSpatialReference = .wgs84()
                params.setStops(self.makeStops())
                self.routeParameters = params
                self.routeTask.solveRoute(with: params) { [weak self] (result, error) in
                    if let result = result {
                        self?.didSolveRoute(with: .success(result))
                    } else if let error = error {
                        self?.didSolveRoute(with: .failure(error))
                    }
                }
            } else if let error = error {
                self.presentAlert(error: error)
                self.setStatus(message: "Failed to get route parameters.")
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Only reset when the route is successfully solved.
        if routeResult != nil {
            reset()
        }
    }
    
}

// MARK: - AGSRouteTrackerDelegate

extension NavigateRouteViewController: AGSRouteTrackerDelegate {
    func routeTracker(_ routeTracker: AGSRouteTracker, didGenerateNewVoiceGuidance voiceGuidance: AGSVoiceGuidance) {
        setSpeakDirection(with: voiceGuidance.text)
    }
    
    func routeTracker(_ routeTracker: AGSRouteTracker, didUpdate trackingStatus: AGSTrackingStatus) {
        updateTrackingStatusDisplay(routeTracker: routeTracker, status: trackingStatus)
    }
    
    func setSpeakDirection(with text: String) {
        speechSynthesizer.stopSpeaking(at: .word)
        speechSynthesizer.speak(AVSpeechUtterance(string: text))
    }
    
    func updateTrackingStatusDisplay(routeTracker: AGSRouteTracker, status: AGSTrackingStatus) {
        var statusText: String
        switch status.destinationStatus {
        case .notReached, .approaching:
            let distanceRemaining = status.routeProgress.remainingDistance.displayText + " " + status.routeProgress.remainingDistance.displayTextUnits.abbreviation
            //let timeRemaining = timeFormatter.string(from: TimeInterval(status.routeProgress.remainingTime * 60))!
            statusText = """
            Distance remaining: \(distanceRemaining)
            """
            if status.currentManeuverIndex + 1 < directionsList.count {
                let nextDirection = directionsList[status.currentManeuverIndex + 1].directionText
                statusText.append("\nNext direction: \(nextDirection)")
            }
        case .reached:
            if status.remainingDestinationCount > 1 {
                statusText = "Intermediate stop reached, continue to next stop."
                routeTracker.switchToNextDestination()
            } else {
                statusText = "Final destination reached."
                mapView.locationDisplay.stop()
            }
        default:
            return
        }
        updateRouteGraphics(remaining: status.routeProgress.remainingGeometry, traversed: status.routeProgress.traversedGeometry)
        setStatus(message: statusText)
    }
    
    func updateRouteGraphics(remaining: AGSGeometry?, traversed: AGSGeometry? = nil) {
        routeAheadGraphic.geometry = remaining
        routeTraveledGraphic.geometry = traversed
    }
    
    func routeTrackerRerouteDidStart(_ routeTracker: AGSRouteTracker) {
        setStatus(message: "Reroute started event!")
        print("Reroute started")
    }
           
    func routeTracker(_ routeTracker: AGSRouteTracker, rerouteDidCompleteWith trackingStatus: AGSTrackingStatus?, error: Error?) {
        setStatus(message: "Reroute completion event!")
        if let error = error {
            print(error)
            return
        }

        directionsList = (trackingStatus?.routeResult.routes[0].routeGeometry.directionManeuvers)!
        // display updated to route graphics.
        let newRoutePolyline = trackingStatus?.routeResult.routes[0].routeGeometry
        // update the route ahead graphic with the new line.
     
        routeAheadGraphic.geometry = newRoutePolyline
    }
}

// MARK: - AGSLocationChangeHandlerDelegate

extension NavigateRouteViewController: AGSLocationChangeHandlerDelegate {
    
    func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
        // Update the tracker location with the new location from the simulated data source.
        routeTracker?.trackLocation(location)
    }
}
