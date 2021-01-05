
@objc(Launcher) class Launcher : CDVPlugin {
  @objc(launch:)
  func launch(command: CDVInvokedUrlCommand) {
    var pluginResult = CDVPluginResult(
      status: CDVCommandStatus_ERROR
    )

    let parms = command.arguments[0] as! NSDictionary
    let address = parms.value(forKey: "address") as! String

    if address.count > 0 {
        let lat = parms.value(forKey: "gisLat") as! Double
        let long = parms.value(forKey: "gisLong") as! Double
        let tt = parms.value(forKey: "travelType") as! Int
        let  location = ArcLocation( address: address, longitude: long, latitude: lat, route: RouteType(rawValue: tt) ?? RouteType.CAR)
        
        let  mapCtrl = NavigateRouteViewController(location:  location) // = MapViewController(destination: location)
    
        //let transition = CATransition()
        //transition.duration = 0.5
        //transition.type = CATransitionType.push
        //transition.subtype = CATransitionSubtype.fromRight
        //transition.timingFunction =
        //    CAMediaTimingFunction(name:CAMediaTimingFunctionName.easeInEaseOut)
        // unable to get refeference to window.
        //self.viewController.view.window!.layer.add(transition, forKey: kCATransition)
        self.viewController?.present(mapCtrl, animated: true, completion: nil)
        
    

//      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//        toastController.dismiss(
//          animated: true,
//          completion: nil
//        )
//      }
      
     pluginResult = CDVPluginResult( status: CDVCommandStatus_OK, messageAs: address    )
        
    }

    self.commandDelegate!.send(
      pluginResult,
      callbackId: command.callbackId
    )
  }

  @objc(canLaunch:)
  func canLaunch(command: CDVInvokedUrlCommand) {
    let pluginResult = CDVPluginResult(
      status: CDVCommandStatus_ERROR
    )

     self.commandDelegate!.send(
      pluginResult,
      callbackId: command.callbackId
    )
  }
}
