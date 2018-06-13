//
//  ViewController.swift
//  GPXParserPodTest
//
//  Created by Mark on 6/9/18.
//  Copyright © 2018 Inukshuk, LLC. All rights reserved.
//

import UIKit
import MapKit
import GPXXMLParser

class ViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    override func viewDidLoad() {
        var parser: GPXXMLParser?
        super.viewDidLoad()
        if let url = Bundle.main.url(forResource: "Oregon Outback", withExtension: "GPX") {
            parser = GPXXMLParser(url: url)
        }

        guard let gpxParser = parser else {
            print("error creating parser")
            abort()
        }
        
        // extract test data from gpx
        let tracks = gpxParser.tracks
        let track = tracks[0]
        let tracksegs = track.trksegments
        let trackseg = tracksegs[0]
        let trackpts = trackseg.trackpoints
        let meta = gpxParser.metadata
        
        var coords = [CLLocationCoordinate2D]()
        for pt in trackpts {
            let lat = (pt.lat as NSString).floatValue
            let lon = (pt.lon as NSString).floatValue
            let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon))
            coords.append(coord)
        }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        
        //Add `MKPolyLine` as an overlay.
        mapView.add(polyline)
        
        mapView.delegate = self
        
        // use basecamp to get approximate center, and then use bounds to set the span.
        let bounds = meta.bounds()
        let minLat = (bounds!.minlat as NSString).floatValue
        let maxLat = (bounds!.maxlat as NSString).floatValue
        let minLon = (bounds!.minlon as NSString).floatValue
        let maxLon = (bounds!.maxlon as NSString).floatValue
        
        let latDelta = abs(maxLat - minLat)
        let lonDelta = abs(maxLon - minLon)
        let centerLat = minLat + (latDelta/2.0)
        let centerLon =  minLon + (lonDelta/2.0)
        let center = CLLocationCoordinate2D(latitude: CLLocationDegrees(centerLat), longitude: CLLocationDegrees(centerLon))
        
        mapView.centerCoordinate = center
        mapView.region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: CLLocationDegrees(latDelta), longitudeDelta: CLLocationDegrees(lonDelta)))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        //Return an `MKPolylineRenderer` for the `MKPolyline` in the `MKMapViewDelegate`s method
        if let polyline = overlay as? MKPolyline {
            let testlineRenderer = MKPolylineRenderer(polyline: polyline)
            testlineRenderer.strokeColor = .blue
            testlineRenderer.lineWidth = 2.0
            return testlineRenderer
        }
        fatalError("error creating renderer")
        //return MKOverlayRenderer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

