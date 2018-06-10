//
//  GoogleMapViewController.swift
//  MakeTrax
//
//  Created by Mark on 5/2/15.
//  Copyright (c) 2015 Inukshuk, LLC. All rights reserved.
//

import Foundation
import GoogleMaps
import CoreData
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

let BASEMARKERSIZE=16

extension UIImage {
    
    class func imageByCombiningImage(firstImage: UIImage, withImage secondImage: UIImage) -> UIImage? {
        
//        let newImageWidth  = max(firstImage.size.width,  secondImage.size.width )
        let newImageWidth  = firstImage.size.width + secondImage.size.width

        let newImageHeight = max(firstImage.size.height, secondImage.size.height)
        let newImageSize = CGSize(width : newImageWidth, height: newImageHeight)
        
        UIGraphicsBeginImageContextWithOptions(newImageSize, false, UIScreen.main.scale)
        
        let firstImageDrawX  = 0.0
        let firstImageDrawY  = 0.0     
        
        let secondImageDrawX = Double(firstImage.size.width)
        let secondImageDrawY = 0.0

        firstImage .draw(at: CGPoint(x: firstImageDrawX,  y: firstImageDrawY))
        secondImage.draw(at: CGPoint(x: secondImageDrawX, y: secondImageDrawY))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}



class GMSLinkedMarkerList: GMSMarker {
    var marker: GMSMarker?
    var next: GMSMarker?
}

class GMSSuperMarker: GMSMarker {
    var multiples = 1
    
    init(position: CLLocationCoordinate2D) {
        super.init()
        self.position = position
    }
}

class GoogleMapVC : UIViewController, GMSMapViewDelegate, UIGestureRecognizerDelegate, UIPopoverControllerDelegate {
    var trailSystem: TrailSystem? {
        didSet {
            if self.recreateViews {
                self.clearViewData()
                self.mapView?.removeFromSuperview()
                self.mapView = nil
                self.createViews()
                self.recreateViews = false
            }
        }
    }
    var splitViewBarButtonItem = UIBarButtonItem()
    var recreateViews = true
    var allowElevationView = false
    @IBOutlet weak var containerView: UIView!
    var containerViewFrame = CGRect()
    var managedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
    var latitudes = [Double]()
    var longitudes = [Double]()
    var elevations = [Double]()
    var times = [Double]()
//    var trailRoot = GPXRoot()
    var singleTap = UITapGestureRecognizer()
    var doubleTap = UITapGestureRecognizer()
    var pinchRecog = UIPinchGestureRecognizer()
    var pause = UIBarButtonItem()
    var mapView: GMSMapView?
    var markers = [UIView]()
    lazy var trailSystemMgr: TrailSystemMgr = {
        var mgr = TrailSystemMgr(withTrailSystem: self.trailSystem, view: self.mapView!)
        return mgr
        }()
    var docMgr: DocManager
    var trackPointsDictionary = [String: [CGPoint]]()  // these are the track points in map view space
    var trackNameDictionary = [String: String]()
    var trackVisibilityDictionary = [String: Bool]()
    var routeNameDictionary = [String: String]()
    var routeVisibilityDictionary = [String: Bool]()
    var sortedTrackPointsDictionary = [String: [Trackpoint]]()
    var sortedRoutePointsDictionary = [String: [Routepoint]]()
    var trackControlPointsDictionary = [String: [CGPoint]]()
    var trackSegmentPointsDictionary = [String: [CGPoint]]()
    var routePointsDictionary = [String: [CGPoint]]()
    var trailNameView: TrailNameVw?
    var currentCameraPosition = CLLocationCoordinate2D()
    var currentTrailNameViewPosition = CGPoint.zero
    var waypointViews = [WaypointView]()
    var trailMarkerViews = [TrailMarkerView]()
    var waypointViewCounts = [Int]()
    var waypointViewLocations = [CGPoint]()
    var trailMarkerViewLocations = [CGPoint]()
    var elevationScrollVC: ElevationVC?
    var resetVC = UIViewController()
    var layerVC: LayerNC?
    var containerOffscreen = true
    var containerViewFrameSet = false
    var oldZoom = 0.0
    let COMPARETOL = 0.000001
    let textInflationFactor = 1.20
    let MAXPOINTS = 100
    var initialized = true  // using this flag to tell if there is an initial camera adjustment neccesitating a subsequent trail name redraw
    var statusBarHidden = false  // this is properly initialized in init() below

    required init?(coder aDecoder: NSCoder) {
        docMgr = DocManager.sharedInstance
//        if docMgr.displayTrackNamesWhenOnline == "true" {  // TODO: change this to use the trail system bool
//            trailNameView = TrailNameVw(coder: aDecoder)
//        }
        super.init(coder: aDecoder)
        DispatchQueue.main.async {
            self.statusBarHidden = UIApplication.shared.isStatusBarHidden
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    
    func createViews() {
//        if trailSystem?.displayTrackNamesForOnlineMode == true {
//            trailNameView = TrailNameVw(frame: CGRect.zero, controlPointsDictionary: [String:[CGPoint]](), nameDictionary: [String:String](), zoomableView: nil, scrollView: nil)
//        }
        if self.mapView == nil {
            let view = GMSMapView(frame: self.view.bounds)
            self.view.addSubview(view)
            self.mapView = view
        }
        self.mapView!.isMyLocationEnabled = true
        
        self.mapView!.mapType = GMSMapViewType.terrain
        self.mapView!.settings.myLocationButton = true
        self.setHomeView()
        self.drawTrails()
        self.drawRoutes()
        self.addMarkers()
        
        self.mapView!.delegate = self
        
        // add the trail name sub view if not a track VC and the XML data doesn't override displaying track names
        if !(self is GoogleMapTrackVC) && trailSystem!.displayTrackNamesForOnlineMode == true {
            self.drawTrailNames()
        }
        
        // setup recognizers
        if let recognizers = self.mapView!.gestureRecognizers {
            for gr in recognizers {
                self.mapView!.removeGestureRecognizer(gr )
            }
        }
        self.singleTap = UITapGestureRecognizer(target: self, action: #selector(GoogleMapVC.screenTapped))
        self.singleTap.numberOfTapsRequired = 1
        self.singleTap.delegate = self
        
        self.doubleTap = UITapGestureRecognizer(target: self, action: #selector(GoogleMapVC.screenDoubleTapped))
        self.doubleTap.numberOfTapsRequired = 2
        self.doubleTap.delegate = self
        
        self.mapView!.addGestureRecognizer(self.singleTap)
        self.mapView!.addGestureRecognizer(self.doubleTap)
        
        self.pinchRecog = UIPinchGestureRecognizer(target: self, action: #selector(GoogleMapVC.screenPinched))
        self.mapView!.addGestureRecognizer(self.pinchRecog)
        
        // register for notifications
        self.registerForFiltersModified()
        self.registerForResetView()
        
        // remember where the trailname view should be
        self.currentCameraPosition = self.mapView!.camera.target
        
        // initial zoom level
        self.oldZoom = Double(self.mapView!.camera.zoom)
        
        if let view = self.containerView {
            self.view.bringSubview(toFront: view)
            if let vc = self.elevationScrollVC {
                vc.scrollView.setNeedsDisplay()
            }
        }
    }
    
    // MARK: View Callbacks
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.recreateViews && self.trailSystem != nil {
            self.clearViewData()
            self.createViews()
            self.recreateViews = false
        }
        if let controllers = self.tabBarController?.viewControllers {
            var reset = false
            var settings = false
            var settingsIndex = -1
            var i = 0
            for controller: UIViewController in controllers {
                if controller is ElevationVC {
                } else if controller is ResetVC {
                    reset = true
                } else if controller is LayerNC {
                    self.layerVC = controller as? LayerNC
                } else if controller is SettingsNC {
                    settings = true
                    settingsIndex = i
                }
                i += 1
            }
        
            if !reset && settings {
                let url = Bundle.main.url(forResource: "home", withExtension: "png")
                if let path = url?.path {
                    let image = UIImage(contentsOfFile: path)
                    let controller = ResetVC()
                    controller.tabBarItem.image = image
                    var viewControllers = self.tabBarController!.viewControllers
                    viewControllers?.insert(controller, at: settingsIndex)
                    self.tabBarController!.viewControllers = viewControllers
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.initialized = false
        var reset = false
        var resetIndex = -1
        var i = 0
        if let controllers = self.tabBarController?.viewControllers {
            for controller in controllers {
                if controller is ElevationVC {
                } else if controller is ResetVC {
                    reset = true
                    resetIndex = i
                } else if controller is LayerNC {
                }
                i += 1
            }
            
            if reset {
                var viewControllers = self.tabBarController!.viewControllers
                viewControllers?.remove(at: resetIndex)
                self.tabBarController!.viewControllers = viewControllers
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let containerView = self.containerView {
            if !self.containerViewFrameSet {
                self.containerViewFrame = containerView.frame
                self.containerViewFrameSet = true
            }
            if self.containerOffscreen {
                var containerFrame = containerView.frame
                containerFrame.origin.y = self.view.frame.size.height
                self.containerView!.frame = containerFrame
            } else {
                if let tabBarController = self.tabBarController {
                    if tabBarController.tabBar.alpha < 1.0 {
                        var containerFrame = self.containerViewFrame
                        let barHeight = self.tabBarController?.tabBar.frame.size.height
                        containerFrame.origin.y += barHeight!
                        self.containerView?.frame = containerFrame
                    }
                }
            }
        }
    }
        
    // MARK: Segues
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "Show Layers" {
//            return self.layerPopover!.popoverVisible ? false : true
            return false
        } else {
            return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Layers" { // no popover currently implemented
        } else if segue.identifier == "Show Track Elevation" {
            self.elevationScrollVC = segue.destination as? ElevationVC
        }
    }
    
    func clearViewData() {
        self.waypointViewCounts.removeAll(keepingCapacity: false)
        self.waypointViews.removeAll(keepingCapacity: false)
        self.waypointViewLocations.removeAll(keepingCapacity: false)
        self.mapView?.removeFromSuperview()
        self.mapView = nil
        if let tView = self.trailNameView {
            tView.removeFromSuperview()
            self.trailNameView = nil
        }
        for view in self.trailMarkerViews {
            view.removeFromSuperview()
        }
        self.trailMarkerViews.removeAll(keepingCapacity: false)
    }
    
    // MARK: Drawing 
    
    func setHomeView() {
        if self.mapView != nil {
            var completeBBox = GMSCoordinateBounds()
            if let trails = self.trailSystem?.trails as? Set<Trail> {
                for trail in trails {
                    let bbox = trail.metadata!.bounds
                    var northEast = CLLocationCoordinate2D()
                    var southWest = CLLocationCoordinate2D()
                    northEast.longitude = bbox!.east!.doubleValue
                    northEast.latitude = bbox!.north!.doubleValue
                    southWest.longitude = bbox!.west!.doubleValue
                    southWest.latitude = bbox!.south!.doubleValue
                    let gmsBBox = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)
                    completeBBox = completeBBox.includingBounds(gmsBBox)
                }
                if let camera = self.mapView?.camera(for: completeBBox, insets: UIEdgeInsets.zero) {
                    if let view = self.mapView {
                        view.camera = camera
                        self.currentCameraPosition = camera.target
                        self.currentTrailNameViewPosition = view.projection.point(for: camera.target)
                    }
                }
            }
        }
    }

    func resetHomeView() {
        if self.mapView != nil {
            var completeBBox = GMSCoordinateBounds()
            if let trails = self.trailSystem?.trails as? Set<Trail> {
                for trail in trails {
                    let bbox = trail.metadata!.bounds
                    var northEast = CLLocationCoordinate2D()
                    var southWest = CLLocationCoordinate2D()
                    northEast.longitude = bbox!.east!.doubleValue
                    northEast.latitude = bbox!.north!.doubleValue
                    southWest.longitude = bbox!.west!.doubleValue
                    southWest.latitude = bbox!.south!.doubleValue
                    let gmsBBox = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)
                    completeBBox = completeBBox.includingBounds(gmsBBox)
                }
                // if the zoom level is going to change, remove the trail name view
                let currentZoom = self.mapView?.camera.zoom
                let camera = self.mapView?.camera(for: completeBBox, insets: UIEdgeInsets.zero)
                let zoom = camera?.zoom
                if fabs(currentZoom!-zoom!) > 0.001 {
                    if let trailNameView = self.trailNameView {
                        trailNameView.removeFromSuperview()
                        self.trailNameView = nil
                    }
                }
                let update = GMSCameraUpdate.fit(completeBBox, with: UIEdgeInsets.zero)
                if let view = self.mapView {
                    self.mapView?.animate(with: update)
                    self.currentCameraPosition = view.camera.target
                    self.currentTrailNameViewPosition = view.projection.point(for: self.currentCameraPosition)
                }
            }
        }
    }
    
    func forwards(_ t1: Trackpoint, t2: Trackpoint) -> Bool {
        return t1.number!.intValue < t2.number!.intValue
    }

    func routeForwards(_ r1: Routepoint, r2: Routepoint) -> Bool {
        return r1.number!.intValue < r2.number!.intValue
    }

    func drawTrails() {
        if self.mapView != nil {
            if let trails = self.trailSystem?.trails as? Set<Trail> {
                for trail in trails {
                    if let tracks = trail.tracks as? Set<Track> {
                        for track in tracks {
                            if let tracksegments = track.tracksegments as? Set<Tracksegment> {
                                let difficulty = track.overallRating!.intValue
                                let lineWidth = track.lineWidth!.doubleValue
                                let visible = self.trailSystemMgr.isLayerVisible(difficulty)
                                if !visible || !track.displayTrack!.boolValue {
                                    continue
                                }
                                let colorStr = track.lineColor
                                var color = UIColor()
                                if !track.displayTrack!.boolValue {
                                    color = UIColor.clear
                                } else if colorStr == nil || colorStr == "" {
                                    switch difficulty {
                                    case -1:
                                        color = self.trailSystemMgr.colorForTrack("IntermediateBlue")
                                        break
                                    case 0:
                                        color = self.trailSystemMgr.colorForTrack("BeginnerGreen")
                                        break
                                    case 1:
                                        color = self.trailSystemMgr.colorForTrack("BeginnerGreen")
                                        break
                                    case 2:
                                        color = self.trailSystemMgr.colorForTrack("IntermediateBlue")
                                        break
                                    case 3:
                                        color = UIColor.black
                                        break
                                    case 4:
                                        color = UIColor.black
                                        break
                                    default:
                                        break
                                    }
                                } else {
                                    color = self.trailSystemMgr.colorForTrack(colorStr!)
                                }
                                var cgPts  = [CGPoint]()
                                var trkpts = [Trackpoint]()
                                for tracksegment in tracksegments {
                                    if let trackpoints = tracksegment.trackpoints as? Set<Trackpoint> {
                                        var sortedTrackpoints = [Trackpoint]()
                                        let path = GMSMutablePath()
                                        sortedTrackpoints = trackpoints.sorted(by: forwards)
                                        for trackpoint: Trackpoint in sortedTrackpoints {
                                            path.addLatitude(trackpoint.latitude!.doubleValue, longitude: trackpoint.longitude!.doubleValue)
                                            let coordinate = CLLocationCoordinate2DMake(trackpoint.latitude!.doubleValue, trackpoint.longitude!.doubleValue)
                                            let pt = self.mapView?.projection.point(for: coordinate)
                                            cgPts.append(pt!)
                                            trkpts.append(trackpoint)
                                        }
                                        let polyline = GMSPolyline(path: path)
                                        if let surface = track.surface {  // check for surface override
                                            if surface == "Doubletrack" {
                                                polyline.strokeWidth = 2.0
                                                let base = GMSPolyline(path: path)
                                                let overlayColor = UIColor(red: 0.725, green: 0.819, blue: 0.572, alpha: 1.0)
                                                let styles = [GMSStrokeStyle.solidColor(UIColor.clear),
                                                    GMSStrokeStyle.solidColor(UIColor.brown)]
                                                let lengths = [75, 75]  // 75 meters
                                                base.spans = GMSStyleSpans(base.path!, styles, lengths as [NSNumber], GMSLengthKind.geodesic)
                                                base.strokeWidth = 4.0
                                                polyline.strokeColor = overlayColor
                                                base.map = self.mapView
                                                polyline.map = self.mapView
                                                base.zIndex = 0
                                                polyline.zIndex = 0
                                            } else if surface == "Faint" {
                                                let base = GMSPolyline(path: path)
                                                let styles = [GMSStrokeStyle.solidColor(UIColor.clear),
                                                    GMSStrokeStyle.solidColor(color)]
                                                let lengths = [75, 75]  // 75 meters
                                                base.spans = GMSStyleSpans(base.path!, styles, lengths as [NSNumber], GMSLengthKind.geodesic)
                                                base.strokeWidth = CGFloat(lineWidth)
                                                base.map = self.mapView
                                                base.zIndex = 0
                                            }
                                        } else {
                                            polyline.strokeColor = color
                                            polyline.strokeWidth = CGFloat(lineWidth)
                                            polyline.map = self.mapView
                                            polyline.zIndex = 1
                                        }
                                    }
                                }
                                self.trackPointsDictionary[track.identifier!] = cgPts
                                self.sortedTrackPointsDictionary[track.identifier!] = trkpts
                                self.trackNameDictionary[track.identifier!] = track.name
                                self.trackVisibilityDictionary[track.identifier!] = track.displayName!.boolValue
                            }
                        }
                    }
                }
            }
        }
    }
    
    func drawRoutes() {
        if self.mapView != nil {
            if let trails = self.trailSystem?.trails as? Set<Trail> {
                for trail in trails {
                    if let routes = trail.routes as? Set<Route> {
                        for route in routes {
                            let difficulty = route.overallRating!.intValue
                            let lineWidth = route.lineWidth!.doubleValue
                            let visible = self.trailSystemMgr.isLayerVisible(difficulty)
                            if !visible || !route.displayRoute!.boolValue {
                                continue
                            }
                            let colorStr = route.lineColor
                            var color = UIColor()
                            if !route.displayRoute!.boolValue {
                                color = UIColor.clear
                            } else if colorStr == nil || colorStr == "" {
                                switch difficulty {
                                case 0:
                                    color = UIColor.green
                                    break
                                case 1:
                                    color = UIColor.green
                                    break
                                case 2:
                                    color = UIColor.blue
                                    break
                                case 3:
                                    color = UIColor.black
                                    break
                                case 4:
                                    color = UIColor.black
                                    break
                                default:
                                    break
                                }
                            } else {
                                color = self.trailSystemMgr.colorForTrack(colorStr!)
                            }
                            var cgPts = [CGPoint]()
                            var rtpts = [Routepoint]()
                            if let routepoints = route.routepoints as? Set<Routepoint> {
                                var sortedRoutepoints = [Routepoint]()
                                let path = GMSMutablePath()
                                sortedRoutepoints = routepoints.sorted(by: routeForwards)
                                for routepoint: Routepoint in sortedRoutepoints {
                                    path.addLatitude(routepoint.latitude!.doubleValue, longitude: routepoint.longitude!.doubleValue)
                                    let coordinate = CLLocationCoordinate2DMake(routepoint.latitude!.doubleValue, routepoint.longitude!.doubleValue)
                                    let pt = self.mapView?.projection.point(for: coordinate)
                                    cgPts.append(pt!)
                                    rtpts.append(routepoint)
                                }
                                let polyline = GMSPolyline(path: path)
                                polyline.strokeColor = color
                                polyline.strokeWidth = CGFloat(lineWidth)
                                polyline.map = self.mapView
                                self.routePointsDictionary[route.identifier!] = cgPts
                                self.sortedRoutePointsDictionary[route.identifier!] = rtpts
                                self.routeNameDictionary[route.identifier!] = route.name
                                self.routeVisibilityDictionary[route.identifier!] = route.displayName!.boolValue
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getMarkerFrame(marker: GMSSuperMarker, map: GMSMapView) -> CGRect? {
        let origin = marker.position
        let markerScreenPos = map.projection.point(for: origin)
        let newFrame = CGRect(x: (markerScreenPos.x), y: (markerScreenPos.y), width: CGFloat(marker.multiples*BASEMARKERSIZE), height: CGFloat(BASEMARKERSIZE))
        return newFrame
    }
    
    private func appendMarker(marker: GMSSuperMarker, toList: inout [GMSSuperMarker]) {
         if toList.count == 0 {
            // nothing to compare to so automatically append to list
            toList.append(marker)
            return
        }
        guard let markerRect = getMarkerFrame(marker: marker, map: mapView!) else {
            print("no rect for marker")
            abort()
        }
        
        for listMarker in toList {
            if let rect = getMarkerFrame(marker: listMarker, map: mapView!) {
                if rect.intersects(markerRect) {
                    if let combinedImage = UIImage.imageByCombiningImage(firstImage: listMarker.icon!, withImage: marker.icon!) {
                        listMarker.icon = combinedImage
                    }
                    listMarker.multiples = listMarker.multiples + 1
                    return
                }
            }
        }
        
        // no intersection so append to array
        toList.append(marker)
    }
    
    func addMarkers() {
        if let trails = self.trailSystem?.trails as? Set<Trail> {
            for trail in trails {
                if let waypoints = trail.waypoints as? Set<Waypoint> {
                    var markerList = [GMSSuperMarker]()
                    for waypoint in waypoints {
                        let visible = self.trailSystemMgr.isLayerVisible(waypoint.overallRating!.intValue)
                        if !visible || !waypoint.displayWaypoint!.boolValue {
                            continue
                        }
                        let latitude = waypoint.latitude!.doubleValue
                        let longitude = waypoint.longitude!.doubleValue
                        let point = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        //
                        // go through all the waypoints and examine each frame.  If a frame intersects a previous waypoint,
                        // then add it to the list for that position.  Once the waypoints are grouped, then render each
                        // waypoint in the lists adjusting each waypoint's lat/lon to space it from the previous one.
                        //
                        let marker = GMSSuperMarker(position: point)
                        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                        if let wpURL: URL = Bundle.main.url(forResource: waypoint.image, withExtension: nil) {
                            if let image = UIImage(contentsOfFile: wpURL.path) {
                                marker.icon = image
                                appendMarker(marker: marker, toList: &markerList)
                            }
                        } else {
                            // this is trail marker view which means it has no "image" but will have a number instead
                            if var viewPoint: CGPoint = self.mapView?.projection.point(for: point) {
                                viewPoint.x += CGFloat(waypoint.centerOffsetX!.floatValue)
                                viewPoint.y += CGFloat(waypoint.centerOffsetY!.floatValue)
                                let tmView = TrailMarkerView()
                                tmView.title = waypoint.name!
                                tmView.waypoint = waypoint
                                tmView.scale = 1.0
                                tmView.isOpaque = false
                                tmView.center = viewPoint
                                tmView.title = waypoint.name!
                                tmView.trailDifficulty = Int(waypoint.overallRating!.int32Value)
                                if let shape = waypoint.shape {
                                    tmView.shape = shape
                                }
                                tmView.opacity = waypoint.opacity!.doubleValue
                                tmView.isHidden = !waypoint.displayWaypoint!.boolValue
                                self.mapView!.addSubview(tmView)
                                self.trailMarkerViews.append(tmView)
                                let coordinate = CGPoint(x: CGFloat(latitude), y: CGFloat(longitude))
                                self.trailMarkerViewLocations.append(coordinate)
                                if !self.trailSystemMgr.isLayerVisible(tmView.trailDifficulty) {
                                    tmView.isHidden = true
                                }
                            }
                        }
                        
                        // Now go through the marker list and add each marker to the GMS Map
                        for marker in markerList {
                            marker.map = mapView
                        }
                    }
                }
            }
        }
    }
    
    func drawTrailNames() {
        var bounds = CGRect()
        if let _ = self.mapView?.frame {
            var completeBBox = GMSCoordinateBounds()
            if let bbox = self.trailSystem?.bounds {
                var northEast = CLLocationCoordinate2D()
                var southWest = CLLocationCoordinate2D()
                var northWest = CLLocationCoordinate2D()
                var southEast = CLLocationCoordinate2D()
                
                northEast.longitude = bbox.east!.doubleValue
                northEast.latitude = bbox.north!.doubleValue
                southWest.longitude = bbox.west!.doubleValue
                southWest.latitude = bbox.south!.doubleValue
                northWest.longitude = bbox.west!.doubleValue
                northWest.latitude = bbox.north!.doubleValue
                southEast.longitude = bbox.east!.doubleValue
                southEast.latitude = bbox.south!.doubleValue
                let gmsBBox = GMSCoordinateBounds(coordinate: southWest, coordinate: northEast)
                completeBBox = completeBBox.includingBounds(gmsBBox)
                if let origin = self.mapView?.projection.point(for: northWest) {
                    if let cgPt = self.mapView?.projection.point(for: southEast) {
                        let width = cgPt.x - origin.x
                        let height = cgPt.y - origin.y
                        bounds = CGRect(x: origin.x, y: origin.y, width: width, height: height)
                    }
                }
            }
            let trailNameView = TrailNameVw(frame: bounds, controlPointsDictionary: self.trackControlPointsDictionary, nameDictionary: self.trackNameDictionary, zoomableView: self.mapView, scrollView: self.mapView)
            self.trailNameView = trailNameView
            trailNameView.trailSystem = self.trailSystem
            trailNameView.isUserInteractionEnabled = false
            trailNameView.scale = Double.greatestFiniteMagnitude   // really don't know what scale means in Google maps so set it to max so all names will draw if they can
            trailNameView.trailSystemMgr = self.trailSystemMgr
            self.view.addSubview(trailNameView)
            
            // compute the initial control Points
            self.computeInitialControlPoints()
        }
    }
    
    func computeInitialControlPoints() {
        guard let tView = trailNameView else {
            print("trail nmae view is null")
            abort()
        }
        let dict = self.trackPointsDictionary
        var dirtyDictionary = [String: Bool]()
        self.trackControlPointsDictionary.removeAll(keepingCapacity: false)
        self.trackSegmentPointsDictionary.removeAll(keepingCapacity: false)
        for (trackName, _) in dict {
            dirtyDictionary[trackName] = true
            if let textPointArray = self.computeBestAvailableTextSegment(trackName, center: true) {
                let textPoints = textPointArray[0]
                if textPoints.count > 0 {
                    self.trackSegmentPointsDictionary[trackName] = textPoints
                    var controlPoints = self.trailSystemMgr.computeControlPointsThroughCurve(textPoints, length: 0.0)
                    let stPt = controlPoints[0]
                    let endPt = controlPoints[3]
                    let dot = endPt.x-stPt.x
                    if dot < 0 {
                        var reverse = [CGPoint]()
                        reverse.insert(controlPoints[3], at: 0)
                        reverse.insert(controlPoints[2], at: 1)
                        reverse.insert(controlPoints[1], at: 2)
                        reverse.insert(controlPoints[0], at: 3)
                        self.trackControlPointsDictionary[trackName] = reverse
                    } else {
                        self.trackControlPointsDictionary[trackName] = controlPoints
                    }
                }
            }
        }
        tView.redrawGlyphs(self.trackControlPointsDictionary, dirtyDictionary: dirtyDictionary, zoomView: self.mapView, translation: CGAffineTransform.identity)

    }

    // update the track points to reflect the new mapview bounds
    func updateTrackPoints() {
        if self.mapView != nil {
            if let trails = self.trailSystem!.trails as? Set<Trail> {
                for trail: Trail in trails {
                    if let tracks = trail.tracks as? Set<Track> {
                        for track in tracks {
                            let difficulty = track.overallRating!.intValue
                            let visible = self.trailSystemMgr.isLayerVisible(difficulty)
                            if !visible || !track.displayTrack!.boolValue {
                                continue
                            }
                            if let tracksegments = track.tracksegments as? Set<Tracksegment> {
                                var cgPts = [CGPoint]()
                                for tracksegment in tracksegments {
                                    if let _ = tracksegment.trackpoints as? Set<Trackpoint> {
                                        var sortedTrackpoints = [Trackpoint]()
                                        sortedTrackpoints = self.sortedTrackPointsDictionary[track.identifier!]!
                                        for trackpoint in sortedTrackpoints {
                                            let coordinate = CLLocationCoordinate2DMake(trackpoint.latitude!.doubleValue, trackpoint.longitude!.doubleValue)
                                            if let pt = self.mapView?.projection.point(for: coordinate) {
                                                cgPts.append(pt)
                                            }
                                        }
                                    }
                                }
                                self.trackPointsDictionary[track.identifier!] = cgPts
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Gesture Protocol
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let pt = touch.location(in: self.view)
        if pt.y < 44 {
            return false
        } else {
            return true
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return self.statusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return UIStatusBarAnimation.fade
    }
    
    @objc func screenTapped() {
        var alpha = 0.0
        if self.tabBarController?.tabBar.alpha < 1.0 {
            alpha = 1.0  // transitioning from hidden to visible
        }
        
        //Toggle visible/hidden status bar.
        //This will only work if the Info.plist file is updated with two additional entries
        //"View controller-based status bar appearance" set to YES (default) and "Status bar is initially hidden" set to YES or NO
        //Hiding the status bar turns the gesture shortcuts for Notification Center and Control Center into 2 step gestures
        self.statusBarHidden = !self.statusBarHidden
        
        UIView.animate(withDuration: 0.30, animations: { [unowned self] in
            self.setNeedsStatusBarAppearanceUpdate()
            
            if let containerView = self.containerView {
                containerView.alpha = CGFloat(alpha)
            }
            
            if let naviController = self.navigationController {
                naviController.navigationBar.alpha = CGFloat(alpha)
            }
            if let tabBarController = self.tabBarController {
                tabBarController.tabBar.alpha = CGFloat(alpha)
            }
        })
    }
    
    @objc func screenDoubleTapped() {
        if let view = self.trailNameView {
            view.removeFromSuperview()
            self.trailNameView = nil
        }
    }
    
    @objc func screenPinched() {
        if let view = self.trailNameView {
            view.removeFromSuperview()
            self.trailNameView = nil
        }
    }
    
    // MARK: Notifications
    
    func registerForFiltersModified() {
        NotificationCenter.default.addObserver(self, selector: #selector(GoogleMapVC.handleFiltersModified(_:)), name: NSNotification.Name(rawValue: "filtersModified"), object: nil)
    }
    
    func registerForResetView() {
        NotificationCenter.default.addObserver(self, selector: #selector(GoogleMapVC.handleResetView(_:)), name: NSNotification.Name(rawValue: "resetView"), object: nil)
    }
    
    @objc func handleFiltersModified(_ notification: AnyObject) {
        self.recreateViews = true
    }
    
    @objc func handleResetView(_ notification: AnyObject) {
        self.resetHomeView()
    }
        
    // MARK: GMSMapView Delegate
    
    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        
        if trailSystem!.displayTrackNamesForOnlineMode == false {
            return
        }
        
        // trail name view may have been removed as a result of zoom/pinch so recreate the trail name view
        if self.trailNameView == nil {
            self.updateTrackPoints()
            if !(self is GoogleMapTrackVC) {
                self.drawTrailNames()
            }
        } else {
            // move the trail name view to coincide with the GMSMapview
            if let view = self.trailNameView {
                let oldViewCenter = view.center
                let newViewCenter = self.mapView!.projection.point(for: position.target)
                let trans = CGAffineTransform(translationX: oldViewCenter.x - newViewCenter.x, y: oldViewCenter.y - newViewCenter.y)
                if trans.isIdentity {
                    return
                }
                
                // translate control points so we can calculate if any names can now be drawn there were previously offscreen or did not have sufficient room
                var dict = [String: [CGPoint]]()
                var dirtyDictionary = [String: Bool]()
                for (key, _) in self.trackControlPointsDictionary {
                    dirtyDictionary[key] = true
                    if let controlPoints = self.trackControlPointsDictionary[key] {
                        var scaledControlPoints = [CGPoint]()
                        for pt in controlPoints {
                            let xformPt = pt.applying(trans)
                            scaledControlPoints.append(xformPt)
                        }
                        dict[key] = scaledControlPoints
                    }
                }

                self.updateTrackPoints()
                self.updateTrailNameView(view, scrollView: self.mapView, redrawGlyphs: true, delta: 0.0)
            }
        }
    }
    
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        
        if let view = self.trailNameView {
            if trailSystem!.displayTrackNamesForOnlineMode == true {
                // update trail name view position
                let oldPosition = self.mapView?.projection.point(for: self.currentCameraPosition)
                self.currentCameraPosition = position.target
                let newPosition = self.mapView?.projection.point(for: position.target)
                if self.trailNameView != nil {
                    let deltaX = oldPosition!.x - newPosition!.x
                    let deltaY = oldPosition!.y - newPosition!.y
                    let trans = CGAffineTransform(translationX: deltaX, y: deltaY)
                    self.view.center = view.center.applying(trans)
                    if !self.initialized {  // We get this call back mysteriously during initialization of the vc so the trail name needs to be redrawn.  If it is not, the view bounds are not correctly set.
                        view.removeFromSuperview()
                        self.trailNameView = nil
                        self.updateTrackPoints()
                        if !(self is GoogleMapTrackVC) {
                            self.drawTrailNames()
                        }
                        self.initialized = true
                    }
                }
            }
        }
        
        // adjust waypoints/mileposts
        var i = 0
        for view in self.waypointViews {
            if let waypoint = view.waypoint {
                let latitude = waypoint.latitude!.doubleValue
                let longitude = waypoint.longitude!.doubleValue
                let coordinate = CLLocationCoordinate2DMake(latitude, longitude)
                if var viewPoint = self.mapView?.projection.point(for: coordinate) {
                    viewPoint.x += CGFloat(waypoint.centerOffsetX!.floatValue)  // waypoints may be offset to account for pin placement
                    viewPoint.y += CGFloat(waypoint.centerOffsetY!.floatValue)
                    view.center = viewPoint
                }
            }
        }
        i = 0
        for view in self.trailMarkerViews {
            let point = self.trailMarkerViewLocations[i]
            i += 1
            let coordinate = CLLocationCoordinate2DMake(Double(point.x), Double(point.y))
            if let viewPoint = self.mapView?.projection.point(for: coordinate) {
                view.center = viewPoint
            }
        }
    }
    
    func updateTrailNameView(_ view: TrailNameVw, scrollView: UIView?, redrawGlyphs: Bool, delta: Double) {
        
        guard trailSystem!.displayTrackNamesForOnlineMode == true else {
            print("updating trail names inappropriately")
            abort()
        }
        guard let tView = self.trailNameView else {
            print("trail name view is null")
            abort()
        }
        
        let dict = self.trackPointsDictionary
        var dirtyDictionary = [String: Bool]()
        let textUtilites = TextUtilities(trackPtsDictionary: self.trackPointsDictionary, trackNameDictionary: self.trackNameDictionary, trackSegmentPointsDictionary: self.trackSegmentPointsDictionary, trackControlPointsDictionary: self.trackControlPointsDictionary, trackVisibilityDictionary: self.trackVisibilityDictionary, pdfScaleX: 1.0, pdfScaleY: 1.0, trailNameView: tView, zoomableView: nil, scrollView: nil, mapView: self.mapView)
        for (track, _) in dict {
            dirtyDictionary[track] = false
        }
        for (key, _) in dict {
            if let visible = self.trackVisibilityDictionary[key] {
                if !visible {
                    continue
                }
            }
            var intersect = false
            if let bboxes = view.boundingBoxesForTrack(key) {
                for bboxVal in bboxes {
                    var bbox = bboxVal
                    bbox = view.convert(bbox, to: scrollView)
                    if let sView = scrollView {
                        if sView.bounds.intersects(bbox) {
                            intersect = true
                            break
                        }
                    }
                }
                if bboxes.count > 0 {  // create a new trail name if the current one is off screen or hasn't been drawn at all (e.g. removed because of insufficient space)
                    if !intersect {
                        if let pts = self.computeBestAvailableTextSegment(key, center: true) {
                            if pts.count > 0 {
                                let points = pts[0]
                                self.trackSegmentPointsDictionary[key] = pts[0]
                                if points.count > 0 {
                                    dirtyDictionary[key] = true
                                    let controlPoints = self.trailSystemMgr.computeControlPointsThroughCurve(points, length: 0.0)
                                    // transform control points to trail name view
                                    let stPt = controlPoints[0]
                                    let endPt = controlPoints[3]
                                    let dot = endPt.x-stPt.x
                                    if dot < 0 {
                                        var reverse = [CGPoint]()
                                        reverse.insert(controlPoints[3], at: 0)
                                        reverse.insert(controlPoints[2], at: 1)
                                        reverse.insert(controlPoints[1], at: 2)
                                        reverse.insert(controlPoints[0], at: 3)
                                        self.trackControlPointsDictionary[key] = reverse
                                    } else {
                                        self.trackControlPointsDictionary[key] = controlPoints
                                    }
                                    view.trackControlPointsDictionary = self.trackControlPointsDictionary
                                }
                            }
                        }
                    }
                }
            } else {
                // no view rects for this track so see if they can be created
                if let pts = self.computeBestAvailableTextSegment(key, center: true) {
                    if let textPointArray = textUtilites.computeBestAvailableTextSegment(key, center: true) {
                        let textPoints = textPointArray[0]
                        if textPoints.count > 0 {
                            
                        }
                    }
                    if pts.count > 0 {
                        let points = pts[0]
                        self.trackSegmentPointsDictionary[key] = pts[0]
                        if points.count > 0 {
                            dirtyDictionary[key] = true
                            let controlPoints = self.trailSystemMgr.computeControlPointsThroughCurve(points, length: 0.0)
                            let stPt = controlPoints[0]
                            let endPt = controlPoints[3]
                            let dot = endPt.x-stPt.x
                            if dot < 0 {
                                var reverse = [CGPoint]()
                                reverse.insert(controlPoints[3], at: 0)
                                reverse.insert(controlPoints[2], at: 1)
                                reverse.insert(controlPoints[1], at: 2)
                                reverse.insert(controlPoints[0], at: 3)
                                self.trackControlPointsDictionary[key] = reverse
                            } else {
                                self.trackControlPointsDictionary[key] = controlPoints
                            }
                            view.trackControlPointsDictionary = self.trackControlPointsDictionary
                        }
                    }
                }
            }
        }
        view.redrawGlyphs(self.trackControlPointsDictionary, dirtyDictionary: dirtyDictionary, zoomView: self.mapView, translation: CGAffineTransform.identity)

    }

    func computeBestAvailableTextSegment(_ key: String, center: Bool) -> [[CGPoint]]? {
        // convert the points which lie in map view space to the trail name view space
        var scaledPts = [CGPoint]()
        scaledPts = self.trackPointsDictionary[key]!
        guard let tView = trailNameView else {
            print("trail name view is null")
            abort()
        }
        var segments = [[CGPoint]]()
        let width = tView.nameLength(self.trackNameDictionary[key]!)
        var segment = [CGPoint]()
        for val in scaledPts {
            let pt = val as CGPoint
            let bounds = self.mapView!.bounds
            if bounds.contains(pt) {
                segment.append(pt)
            } else {
                if segment.count > 0 {
                    let segmentPts = self.findTextLocation(segment, size: width, center: center)
                    if segmentPts.count > 0 {
                        segments.append(segmentPts)
                    }
                } else {
                    
                }
                segment.removeAll(keepingCapacity: false)
            }
            
        }
        if segment.count > 0 {
            // if the segment count is not zero, the segment may lie completely in the view so check it again
            let segmentPts = self.findTextLocation(segment, size: width, center: center)
            if segmentPts.count > 0 {
                segments.append(segmentPts)
            }
        }
        if segments.count > 0 {
            return segments
        } else {
            return nil
        }
    }

    func findTextLocation(_ segment: [CGPoint], size: Double, center: Bool) -> [CGPoint] {
        var array = [CGPoint]()
        var distance = 0.0
        let step: Int = Int(ceil(fabs(Float(segment.count)/Float(MAXPOINTS))))
        
        var cgPts = [CGPoint]()
        for var i in 0...segment.count-1 {
            cgPts.append(segment[i])
            i += step
        }
        distance = self.computeSplineLength(cgPts)
        
        if distance > Double(size * textInflationFactor) {
            if !center {
                if segment.count > MAXPOINTS {
                    let step: Int = Int(ceil(fabs(Float(segment.count)/Float(MAXPOINTS))))
                    for var i in 0..<segment.count {
                        if i > segment.count - 1 {
                            NSLog("error computing text points")
                        }
                        array.append(segment[i])
                        i += step
                    }
                } else {
                    array += segment
                }
                return array
            }
            var textPoints = [CGPoint]()
            let pad = Double(Double(distance)-size)/2.0
            var offset = 0.0
            var j = 0
            
            // find the starting index to fit the name
            var subSegment = [CGPoint]()
            while offset < pad && j < cgPts.count - 1 {
                if j > segment.count - 1 {
                    NSLog("error computing text points")
                }
                let val = cgPts[j]
                subSegment.append(val)
                if j < 3 {
                    j += 1
                } else {
                    offset = self.computeSplineLength(subSegment)
                    j += 1
                }
            }
            
            // find the end index
            var length = 0.0
            let startIndex = j-1
            j = startIndex
            subSegment.removeAll(keepingCapacity: false)
            while length < size * textInflationFactor && j < cgPts.count - 1 {
                if j > cgPts.count - 1 {
                    NSLog("error computing text points")
                    
                }
                let val = cgPts[j]
                subSegment.append(val)
                if startIndex + 2 > cgPts.count - 1 {
                    return array
                }
                if j <= startIndex + 3 {
                    j += 1
                } else {
                    length = self.computeSplineLength(subSegment)
                    j += 1
                }
            }
            
            let endIndex = j-1
            if startIndex < 0 || endIndex > segment.count - 1 {
                NSLog("error computing text points")
                return array
            }
            
            // collect up the sample of points
            length = 0.0
            let step: Int = Int(ceil(fabs(Float(endIndex-startIndex)/Float(MAXPOINTS))))
            var index = startIndex
            while index < endIndex {
                if index > segment.count - 1 {
                    NSLog("error computing text points")
                }
                let val = cgPts[index]
                textPoints.append(val)
                index += step
            }
            if textPoints.count > MAXPOINTS {
                NSLog("error computing text points")
                return array
            }
            if textPoints.count > MAXPOINTS {
                let step: Int = Int(ceil(fabs(Float(textPoints.count)/Float(MAXPOINTS))))
                for var i in 0..<textPoints.count {
                    if i > textPoints.count - 1 {
                        NSLog("error computing text points")
                    }
                    array.append(textPoints[i])
                    i += step
                }
            } else {
                array += textPoints
            }
        } else {
            
        }
        return array
    }
    func computeSplineLength(_ spline: [CGPoint]) -> Double {
        var length: Double = 0.0
        var array = [CGPoint]()
        if spline.count > MAXPOINTS {
            let step: Int = Int(ceil(fabs(Float(spline.count)/Float(MAXPOINTS))))
            for var i in 0..<spline.count {
                if i > spline.count - 1 {
                    NSLog("error computing text points")
                }
                array.append(spline[i])
                i += step
            }
        } else {
            array += spline
        }
        
        length = 0.0
        var first = true
        var previousPt = CGPoint()
        let controlPoints = self.trailSystemMgr.computeControlPointsThroughCurve(array, length: 0.0)
        var points = [CGPoint]()
        points = controlPoints
        let steps = 100
        for i in 0...steps {
            let param: Double = Double(Double(i)/Double(steps))
            let cgpoint = GoogleMapVC.pointForOffset(param, points: points)
            if first {
                first = false
                previousPt = cgpoint
            } else {
                let currentViewPt = cgpoint
                let previousViewPt = previousPt
                let xDist = Double(currentViewPt.x - previousViewPt.x)
                let yDist = Double(currentViewPt.y - previousViewPt.y)
                length += sqrt((xDist * xDist) + (yDist * yDist))
                previousPt = cgpoint
            }
        }
        return length
    }

    static func bezier(_ t: Double, p0: Double, p1: Double, p2: Double, p3: Double) -> Double {
        let t1 = (1-t)*(1-t)*(1-t) * p0
        let t2 = 3 * (1-t)*(1-t) * t * p1
        let t3 = 3 * (1-t) * t*t * p2
        let t4 = t*t*t * p3
        return t1 + t2 + t3 + t4
    }
    
    static func pointForOffset(_ t: Double, points: [CGPoint]) -> CGPoint {
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        
        let x = GoogleMapVC.bezier(t, p0: Double(p0.x), p1: Double(p1.x), p2: Double(p2.x), p3: Double(p3.x))
        let y = GoogleMapVC.bezier(t, p0: Double(p0.y), p1: Double(p1.y), p2: Double(p2.y), p3: Double(p3.y))
        let pt = CGPoint(x: CGFloat(x), y: CGFloat(y))
        return pt
        
    }
}

