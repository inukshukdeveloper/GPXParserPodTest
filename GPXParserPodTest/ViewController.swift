//
//  ViewController.swift
//  GPXParserPodTest
//
//  Created by Mark on 6/9/18.
//  Copyright © 2018 Inukshuk, LLC. All rights reserved.
//

import UIKit
import GPXXMLParser
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var parser: GPXXMLParser?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = Bundle.main.url(forResource: "Mountain Park", withExtension: "GPX") {
            parser = GPXXMLParser(url: url)
        }
        // Do any additional setup after loading the view, typically from a nib.
        
        let tracks = parser?.tracks
        let track = tracks![0]
        let tracksegs = track.trksegments
        let trackseg = tracksegs[0]
        let trackpts = trackseg.trackpoints
        let extensions = track.extensions()
        let trackextensions = extensions?.extensions()
        let meta = parser?.metadata
        let time = meta!.time()
        let waypoints = parser?.waypoints
        let waypoint = waypoints![0]
        let wayptextensions = waypoint.extensions()

        
        // Do any additional setup after loading the view, typically from a nib.
        let coords1 = CLLocationCoordinate2D(latitude: 52.167894, longitude: 17.077399)
        let coords2 = CLLocationCoordinate2D(latitude: 52.168776, longitude: 17.081326)
        let coords3 = CLLocationCoordinate2D(latitude: 52.167921, longitude: 17.083730)
        let testcoords:[CLLocationCoordinate2D] = [coords1,coords2,coords3]
        
        let testline = MKPolyline(coordinates: testcoords, count: testcoords.count)
        
        //Add `MKPolyLine` as an overlay.
        mapView.add(testline)
        
        mapView.delegate = self
        
        
        // use basecamp to get approximate center, and then use bounds to set the span.
        mapView.centerCoordinate = coords2
        mapView.region = MKCoordinateRegion(center: coords2, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))

    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        //Return an `MKPolylineRenderer` for the `MKPolyline` in the `MKMapViewDelegate`s method
        if let polyline = overlay as? MKPolyline {
            let testlineRenderer = MKPolylineRenderer(polyline: polyline)
            testlineRenderer.strokeColor = .blue
            testlineRenderer.lineWidth = 2.0
            return testlineRenderer
        }
        fatalError("Something wrong...")
        //return MKOverlayRenderer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

