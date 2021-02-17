//
//  NavigateRouteViewController.swift
//  testPluginApp
//
//  Created by WebDev on 12/31/20.
//
import ArcGIS
import UIKit
import AVFoundation

class NavigateRouteViewController: UIViewController  {
    private var mapLoadStatusObservable: NSKeyValueObservation?
    private var inputParams: ArcLocation = ArcLocation()
       
    @IBOutlet var navTitle: UINavigationItem!
    @IBOutlet var directionLabel: UILabel!
    @IBOutlet var directionImage: UIImageView!
    @IBOutlet var distanceLabel: UILabel!    
    @IBOutlet var navigationBarButtonItem: UIBarButtonItem!
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
            
            //mapView.map = AGSMap(basemap:  .openStreetMap())
            //mapView.graphicsOverlays.add(makeRouteOverlay())
            
            // use the villages map server
            initMap()
        }
    }
    
    // MARK: Instance properties
       /// Current location from mapview locationdisplay
       var currentLocation: AGSPoint!
       /// The route task to solve the route between stops, using the online routing service.
       var routeTask = AGSRouteTask(url: .myAppRoutingService)
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
        
       // The actural route graphic for testing
       let actualRouteGraphic = AGSGraphic(geometry: nil, symbol: AGSSimpleLineSymbol(style: .solid, color: .green, width: 3))
    
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
        AGSRequestConfiguration.global().debugLogRequests = true
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        AGSRequestConfiguration.global().debugLogFileURL = URL(fileURLWithPath: "debug.md", relativeTo: documentURL)
        
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
        let point = AGSPoint(x: TestPoints.longitude, y: TestPoints.latitude, spatialReference: AGSSpatialReference.wgs84())
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
        let p1 =  AGSPoint(x: TestPoints.mvp_x, y: TestPoints.mvp_y, spatialReference: .wgs84())
        let stop1 = AGSStop(point: self.currentLocation ?? p1)
        //let stop1 = AGSStop(point: p1)
        stop1.name = "Starting location"
       
        let stop2 = AGSStop(point: AGSPoint( x: inputParams.longitude, y: inputParams.latitude, spatialReference: .wgs84()))
        stop2.name = inputParams.address
        
        return [stop1, stop2]
    }
    
    func makeSimulatedStops() -> [AGSStop] {
        let p1 = AGSPoint(x: TestPoints.mvp_x, y: TestPoints.mvp_y, spatialReference: .wgs84())
        //let start = AGSStop(point: p1)
        let start = AGSStop(point: currentLocation ?? p1)
        start.name = "Current location"
        let final = AGSStop(point: AGSPoint(x: TestPoints.swLong, y: TestPoints.swLat, spatialReference: .wgs84()))
        final.name = "Shooters world"
        return [start, final]
    }
        
       
    /// Make a graphics overlay with graphics and add to mapView
    ///
    /// - Returns: An `AGSGraphicsOverlay` object.
    func makeRouteOverlay() -> AGSGraphicsOverlay {
        // The graphics overlay for the polygon and points.
        let graphicsOverlay = AGSGraphicsOverlay()
        let stopSymbol = AGSSimpleMarkerSymbol(style: .diamond, color: .orange, size: 20)
              
        var stopGraphics = makeStops().map { AGSGraphic(geometry: $0.geometry, symbol: stopSymbol) }
        
        // TEST:  remove for production
        let testSymbol = AGSSimpleMarkerSymbol(style: .triangle, color: .purple, size: 20)
        let actualStopGraphics = makeSimulatedStops().map { AGSGraphic(geometry: $0.geometry, symbol: testSymbol) }
        stopGraphics.append(actualStopGraphics[1])
        
        let routeGraphics = [routeAheadGraphic, routeTraveledGraphic, actualRouteGraphic]
        
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
    func setNavigation(with routeResult: AGSRouteResult, parameters: AGSRouteParameters) {
        // Set the route tracker
        routeTracker = AGSRouteTracker(routeResult: routeResult, routeIndex: 0, skipCoincidentStops: true)!
        routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
        routeTracker.delegate = self
        
        // add rerouteing
        if  routeTask.routeTaskInfo().supportsRerouting {
            routeTracker.enableRerouting(with: self.routeTask, routeParameters: parameters, strategy: AGSReroutingStrategy.toNextStop, visitFirstStopOnStart: false)
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
        
        //TESTING: Set the mock simulsted location data source for testing.
        //let densifiedRoute = AGSGeometryEngine.geodeticDensifyGeometry(firstRoute.routeGeometry!, maxSegmentLength: 60.0, lengthUnit: .meters(), curveType: .geodesic) as! AGSPolyline
        //let mockDataSource = AGSSimulatedLocationDataSource()
        //mockDataSource.setLocationsWith(densifiedRoute)
        //initialLocation = mockDataSource.locations?.first
        //let routeTrackerLocationDataSource = AGSRouteTrackerLocationDataSource(routeTracker: routeTracker, locationDataSource: mockDataSource)
        
        // MARK: For production use system location data source
        let routeTrackerLocationDataSource = AGSRouteTrackerLocationDataSource(routeTracker: routeTracker)
                     
        // Set location display data source.
        mapView.locationDisplay.dataSource = routeTrackerLocationDataSource
        
        recenter()
        
        // Update graphics and viewpoint.
        let firstRouteGeometry = firstRoute.routeGeometry!
        updateRouteGraphics(remaining: firstRouteGeometry)
        updateViewpoint(geometry: firstRouteGeometry)
    }
    
    func setNavigationOnSecondRoute(with routeResult: AGSRouteResult, secondRouteResult: AGSRouteResult, secondParameters: AGSRouteParameters) {
        // Set the route tracker
        routeTracker = AGSRouteTracker(routeResult: routeResult, routeIndex: 0, skipCoincidentStops: true)!
        routeTracker.delegate = self
      
        routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
        
        // add rerouteing
        if  routeTask.routeTaskInfo().supportsRerouting {
            routeTracker.enableRerouting(with: routeTask, routeParameters: routeParameters, strategy: AGSReroutingStrategy.toNextWaypoint, visitFirstStopOnStart: false)
            { (error) in
                if let error = error {
                    print(error)
                    return
                }
                // rerouting is enabled
                print( "*** Rerouting is enabled!")
                self.setStatus(message: "Rerouting is enabled!")
              
            }
        }
        else {
            print ("*** REROUTING IS NOT SUPPORTED ***")
        }
              
        let firstRoute = secondRouteResult.routes.first!
        directionsList = firstRoute.directionManeuvers
        
        //TESTING: Set the mock simulsted location data source for testing.
        let densifiedRoute = AGSGeometryEngine.geodeticDensifyGeometry(firstRoute.routeGeometry!, maxSegmentLength: 60.0, lengthUnit: .meters(), curveType: .geodesic) as! AGSPolyline
        let mockDataSource = AGSSimulatedLocationDataSource()
        mockDataSource.setLocationsWith(densifiedRoute)
        //initialLocation = mockDataSource.locations?.first
        let routeTrackerLocationDataSource = RouteTrackerDisplayLocationDataSource(routeTracker: routeTracker, locationDataSource: mockDataSource)
        mockDataSource.locationChangeHandlerDelegate = self
                
        // Set location display data source.
        mapView.locationDisplay.dataSource = routeTrackerLocationDataSource
        
        recenter()
        
        // Update graphics and viewpoint.
        let firstRouteGeometry = firstRoute.routeGeometry!
        updateRouteGraphics(remaining: firstRouteGeometry)
        updateViewpoint(geometry: firstRouteGeometry)
    }
    
    
    // MARK: UI
    
    func setStatus(message: String) {
        directionLabel.text = message
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
      
        navigationBarButtonItem.image = UIImage(systemName: "stop.fill")
        
        if mapView.locationDisplay.started {
            reset()
            return
        }
                  
        // Start the location data source and location display.
        mapView.locationDisplay.start(completion: ) { (error) in
            if let error = error {
                print(error)
            }
        }
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
        setNavigation(with: routeResult, parameters: routeParameters)
        // toggle  buttons image.
        navigationBarButtonItem.image = UIImage(systemName: "location.fill")
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
        
        mapView.contentInset.top = CGFloat(directionLabel.numberOfLines) * directionLabel.font.lineHeight
               
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
                        self?.routeResult = result
                        // comment out for second route testing
                        //self?.setNavigation(with: result, parameters: params)
                        self?.navigationBarButtonItem.isEnabled = true
                        //
                        // Test rerouting using 2 routes. ssolve the second route.
                        //
                        
                        self?.routeTask.defaultRouteParameters { [weak self] (params: AGSRouteParameters?, error: Error?) in
                            guard let self = self else { return }
                            if let params = params {
                                // Explicitly set values for parameters.
                                params.returnDirections = true
                                params.returnStops = true
                                params.returnRoutes = true
                                params.outputSpatialReference = .wgs84()
                                params.setStops(self.makeSimulatedStops())
                                self._routeParameters = params
                                self.routeTask.solveRoute(with: params) { [weak self] (result_, error) in
                                    if let result_ = result_ {
                                        let routeGeometry_ = result_.routes.first?.routeGeometry
                                        self!.actualRouteGraphic.geometry = routeGeometry_
                                        //TODO Add graphic to map
                                        //self!.setExtent(routeGeometry: (self!.routeResult.routes.first?.routeGeometry)!, actualGeometry: routeGeometry_!)
                                        self!.setNavigationOnSecondRoute(with: result, secondRouteResult: result_, secondParameters: params)
                                        
                                    } else if let error = error {
                                        self!.presentAlert(error: error)
                                    }
                                }
                            } else if let error = error {
                                self.presentAlert(error: error)
                                self.setStatus(message: "Failed to get route parameters for test route.")
                            }
                        }
                        
                        
                    } else if let error = error {
                        self?.presentAlert(error: error)
                        self?.setStatus(message: "Failed to solve route.")
                        self?.navigationBarButtonItem.isEnabled = false
                    }
                }
            } else if let error = error {
                self.presentAlert(error: error)
                self.setStatus(message: "Failed to get route parameters.")
            }
        }
        
      
    }
    //TESTING
    var _routeParameters: AGSRouteParameters!
    
    
    func setExtent(routeGeometry: AGSGeometry, actualGeometry: AGSGeometry){
        // add actual geoemtery to mapview.
        
        let envelope = AGSGeometryEngine.combineExtents(ofGeometries: [routeGeometry, actualGeometry])
        mapView.setViewpointGeometry(envelope!)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Only reset when the route is successfully solved.
        if routeResult != nil {
            reset()
        }
    }
  
    func getDirectionImage(direction: String) -> UIImage {
        var imgName = "square"
        if direction.contains("Turn left") {
            imgName = "arrow.turn.up.left"
        }
        else  if direction.contains("Turn right") {
            imgName = "arrow.turn.up.right"
        }
        else  if direction.contains("Bear left") {
            imgName = "arrow.up.left"
        }
        else  if direction.contains("Bear right") {
            imgName = "arrow.up.right"
        }
        else  if direction.contains("Continue") {
            imgName = "arrow.up"
        }
        else  if direction.contains("U-turn") {
            imgName = "arrow.uturn.down"
        }
        else  if direction.contains("Go north") {
            imgName = "arrow.up"
        }
        else  if direction.contains("Go east") {
            imgName = "arrow.right"
        }
        else  if direction.contains("Sharp Left") {
            imgName = "arrow.left"
        }
        else if direction.contains("Finish") {
            imgName = "flag"
        }
        
        return UIImage(systemName: imgName)!
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
        var statusText = ""
        var distanceText = ""
        
        switch status.destinationStatus {
        case .notReached, .approaching:
            let distanceRemaining = status.routeProgress.remainingDistance.displayText + " " + status.routeProgress.remainingDistance.displayTextUnits.abbreviation
            let timeRemaining = timeFormatter.string(from: TimeInterval(status.routeProgress.remainingTime * 60))!
            
            distanceText = """
            Distance: \(distanceRemaining)   \(timeRemaining)
            """
            if status.currentManeuverIndex + 1 < directionsList.count {
                let nextDirection = directionsList[status.currentManeuverIndex + 1].directionText
                statusText = "\(nextDirection)"
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
        distanceLabel.text = distanceText
        directionImage.image = getDirectionImage(direction: statusText)
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
        print ("*** Reroute completed ***")
        if let error = error {
            print(error)

        } else if let status = trackingStatus {

            directionsList = status.routeResult.routes.first!.directionManeuvers
            // display updated to route graphics.
            //let newRoutePolyline = trackingStatus?.routeResult.routes[0].routeGeometry
            // update the route ahead graphic with the new line.
            //routeAheadGraphic.geometry = newRoutePolyline
        }
    }
}

// MARK: - AGSLocationChangeHandlerDelegate

extension NavigateRouteViewController: AGSLocationChangeHandlerDelegate {
    func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
        // Update the tracker location with the new location from the simulated data source.
        routeTracker?.trackLocation(location) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.setStatus(message: error.localizedDescription)
                self.routeTracker.delegate = nil
            }
        }
    }
}
