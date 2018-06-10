//
//  ViewController.swift
//  GPXParserPodTest
//
//  Created by Mark on 6/9/18.
//  Copyright © 2018 Inukshuk, LLC. All rights reserved.
//

import UIKit
import GPXXMLParser

class ViewController: UIViewController {
    
    var parser: GPXXMLParser?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = Bundle.main.url(forResource: "Mountain Park", withExtension: "GPX") {
            parser = GPXXMLParser(url: url)
        }
        // Do any additional setup after loading the view, typically from a nib.
        
        let tracks = parser?.tracks
        let track = tracks![0]
        let extensions = track.extensions()
        let trackextensions = extensions?.extensions()
        let meta = parser?.metadata
        let time = meta!.time()
        let waypoints = parser?.waypoints
        let waypoint = waypoints![0]
        let wayptextensions = waypoint.extensions()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

