//
//  BreadcrumbViewController.swift
//  Breadcrumb
//
//  Translated by OOPer in cooperation with shlab.jp on 2014/12/19.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  Main view controller for the application.
  Displays the user location along with the path traveled on an MKMapView.
  Implements the MKMapViewDelegate messages for tracking user location and managing overlays.

 */
import UIKit
import MapKit
import AVFoundation       // for AVAudioSession

//-DkDebugShowArea
// for debugging purposes, draw the map polygon area in which the breacrumbs path is drawn

private func DescriptionOfCLAuthorizationStatus(_ st: CLAuthorizationStatus) -> String {
    switch st {
    case .notDetermined:
        return "kCLAuthorizationStatusNotDetermined"
    case .restricted:
        return "kCLAuthorizationStatusRestricted"
    case .denied:
        return "kCLAuthorizationStatusDenied"
        //case kCLAuthorizationStatusAuthorized: is the same as
        //kCLAuthorizationStatusAuthorizedAlways
    case .authorizedAlways: //iOS 8.2 or later        
        return "kCLAuthorizationStatusAuthorizedAlways"
        
    case .authorizedWhenInUse:
        return "kCLAuthorizationStatusAuthorizedWhenInUse"
    @unknown default:
        return "Unknown CLAuthorizationStatus value: \(st.rawValue)"
    }
}


@objc(BreadcrumbViewController)
class BreadcrumbViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, AVAudioPlayerDelegate {
    
    private var audioPlayer: AVAudioPlayer!
    
    private var crumbs: CrumbPath?
    private var crumbPathRenderer: CrumbPathRenderer?
    private var drawingAreaRenderer: MKPolygonRenderer?   // shown if kDebugShowArea is set to 1
    
    @IBOutlet private weak var map: MKMapView!
    
    private var locationManager: CLLocationManager!
    
    
    //MARK: -
    
    // called for NSUserDefaultsDidChangeNotification
    @objc func settingsDidChange(_ notification: NSNotification) {
        let settings = UserDefaults.standard
        
        // update our location manager for these settings changes:
        
        // accuracy (CLLocationAccuracy)
        let desiredAccuracy = settings.double(forKey: LocationTrackingAccuracyPrefsKey) as CLLocationAccuracy
        self.locationManager?.desiredAccuracy = desiredAccuracy
        
        // note:
        // for "PlaySoundOnLocationUpdatePrefsKey", code to play the sound later will read this default value
        // for "TrackLocationInBackgroundPrefsKey", code to track location in background will read this default value
    }
    
    
    //MARK: - View Layout
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initilizeAudioPlayer()
        self.initilizeLocationTracking()
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(BreadcrumbViewController.settingsDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil)
        
        // allow the user to change the tracking mode on the map view by placing this button in the navigation bar
        let userTrackingButton = MKUserTrackingBarButtonItem(mapView: self.map)
        self.navigationItem.leftBarButtonItem = userTrackingButton
    }
    
    deinit {
        // even though we are using ARC we still need to:
        
        // 1) properly balance the unregister from the NSNotificationCenter,
        // which was registered previously in "viewDidLoad"
        //
        NotificationCenter.default.removeObserver(self)
        
        // 2) manually unregister for delegate callbacks,
        // As of iOS 7, most system objects still use __unsafe_unretained delegates for compatibility.
        //
        self.locationManager.delegate = nil
        self.audioPlayer.delegate = nil
    }
    
    
    //MARK: - Location Tracking
    
    private func initilizeLocationTracking() {
        locationManager = CLLocationManager()
        assert(self.locationManager != nil)
        
        self.locationManager.delegate = self
        
        // iOS 8 introduced a more powerful privacy model: <https://developer.apple.com/videos/wwdc/2014/?id=706>.
        // We use -respondsToSelector: to only call the new authorization API on systems that support it.
        //
        if #available(iOS 8.0, *) {
            //Info.plist contains the entry for NSLocationWhenInUseUsageDescription.
            self.locationManager.requestWhenInUseAuthorization()
            
            // note: doing so will provide the blue status bar indicating iOS
            // will be tracking your location, when this sample is backgrounded
        }
        
        // By default we use the best accuracy setting (kCLLocationAccuracyBest)
        //
        // You may instead want to use kCLLocationAccuracyBestForNavigation, which is the highest possible
        // accuracy and combine it with additional sensor data.  Note that level of accuracy is intended
        // for use in navigation applications that require precise position information at all times and
        // are intended to be used only while the device is plugged in.
        //
        self.locationManager.desiredAccuracy =
            UserDefaults.standard.double(forKey: LocationTrackingAccuracyPrefsKey)
        
        // start tracking the user's location
        self.locationManager.startUpdatingLocation()
        
        // Observe the application going in and out of the background, so we can toggle location tracking.
        NotificationCenter.default.addObserver(self,
            selector: #selector(BreadcrumbViewController.handleUIApplicationDidEnterBackgroundNotification(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(BreadcrumbViewController.handleUIApplicationWillEnterForegroundNotification(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }
    
    @objc func handleUIApplicationDidEnterBackgroundNotification(_ note: NSNotification) {
        self.switchToBackgroundMode(true)
    }
    
    @objc func handleUIApplicationWillEnterForegroundNotification(_ note: NSNotification) {
        self.switchToBackgroundMode(false)
    }
    
    // called when the app is moved to the background (user presses the home button) or to the foreground
    
    private func switchToBackgroundMode(_ background: Bool) {
        if UserDefaults.standard.bool(forKey: TrackLocationInBackgroundPrefsKey) {
            return
        }
        
        if background {
            self.locationManager.stopUpdatingLocation()
        } else {
            self.locationManager.startUpdatingLocation()
        }
    }
    
    private func coordinateRegionWithCenter(_ centerCoordinate: CLLocationCoordinate2D, approximateRadiusInMeters radiusInMeters: CLLocationDistance) -> MKCoordinateRegion {
        // Multiplying by MKMapPointsPerMeterAtLatitude at the center is only approximate, since latitude isn't fixed
        //
        let radiusInMapPoints = radiusInMeters * MKMapPointsPerMeterAtLatitude(centerCoordinate.latitude)
        let radiusSquared = MKMapSize(width: radiusInMapPoints, height: radiusInMapPoints)
        
        let regionOrigin = MKMapPoint(centerCoordinate)
        var regionRect = MKMapRect(origin: regionOrigin, size: radiusSquared)
        
        regionRect = regionRect.offsetBy(dx: -radiusInMapPoints/2, dy: -radiusInMapPoints/2)
        
        // clamp the rect to be within the world
        regionRect = regionRect.intersection(.world)
        
        let region = MKCoordinateRegion(regionRect)
        return region
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            if UserDefaults.standard.bool(forKey: PlaySoundOnLocationUpdatePrefsKey) {
                self.setSessionActiveWithMixing(true)
                self.playSound()
            }
            
            // we are not using deferred location updates, so always use the latest location
            let newLocation = locations[0]
            
            if self.crumbs == nil {
                // This is the first time we're getting a location update, so create
                // the CrumbPath and add it to the map.
                //
                crumbs = CrumbPath(center: newLocation.coordinate)
                self.map.addOverlay(self.crumbs!, level: .aboveRoads)
                
                // on the first location update only, zoom map to user location
                let newCoordinate = newLocation.coordinate
                
                // default -boundingMapRect size is 1km^2 centered on coord
                let region = self.coordinateRegionWithCenter(newCoordinate, approximateRadiusInMeters: 2500)
                
                self.map.setRegion(region, animated: true)
            } else {
                // This is a subsequent location update.
                //
                // If the crumbs MKOverlay model object determines that the current location has moved
                // far enough from the previous location, use the returned updateRect to redraw just
                // the changed area.
                //
                // note: cell-based devices will locate you using the triangulation of the cell towers.
                // so you may experience spikes in location data (in small time intervals)
                // due to cell tower triangulation.
                //
                var boundingMapRectChanged = false
                var updateRect = self.crumbs!.addCoordinate(newLocation.coordinate, boundingMapRectChanged: &boundingMapRectChanged)
                if boundingMapRectChanged {
                    // MKMapView expects an overlay's boundingMapRect to never change (it's a readonly @property).
                    // So for the MapView to recognize the overlay's size has changed, we remove it, then add it again.
                    self.map.removeOverlays(self.map.overlays)
                    crumbPathRenderer = nil
                    self.map.addOverlay(self.crumbs!, level: .aboveRoads)
                    
                    let r = self.crumbs!.boundingMapRect
                    var pts: [MKMapPoint] = [
                        MKMapPoint(x: r.minX, y: r.minY),
                        MKMapPoint(x: r.minX, y: r.maxY),
                        MKMapPoint(x: r.maxX, y: r.maxY),
                        MKMapPoint(x: r.maxX, y: r.minY),
                    ]
                    let count = pts.count
                    let boundingMapRectOverlay = MKPolygon(points: &pts, count: count)
                    self.map.addOverlay(boundingMapRectOverlay, level: .aboveRoads)
                } else if !updateRect.isNull {
                    // There is a non null update rect.
                    // Compute the currently visible map zoom scale
                    let currentZoomScale = MKZoomScale(self.map.bounds.size.width / CGFloat(self.map.visibleMapRect.size.width))
                    // Find out the line width at this zoom scale and outset the updateRect by that amount
                    let lineWidth = MKRoadWidthAtZoomScale(currentZoomScale)
                    updateRect = updateRect.insetBy(dx: Double(-lineWidth), dy: Double(-lineWidth))
                    // Ask the overlay view to update just the changed area.
                    self.crumbPathRenderer?.setNeedsDisplay(updateRect)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("\(#file):\(#line) \(error)");
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NSLog("\(#file):\(#line) \(DescriptionOfCLAuthorizationStatus(status))")
    }
    
    
    //MARK: - MapKit
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        var renderer: MKOverlayRenderer? = nil
        
        if overlay is CrumbPath {
            if self.crumbPathRenderer == nil {
                crumbPathRenderer = CrumbPathRenderer(overlay: overlay)
            }
            renderer = self.crumbPathRenderer
        } else if overlay is MKPolygon {
            #if kDebugShowArea
                if self.drawingAreaRenderer?.polygon !== overlay {
                    drawingAreaRenderer = MKPolygonRenderer(polygon: overlay as! MKPolygon)
                    self.drawingAreaRenderer!.fillColor = UIColor.blue.withAlphaComponent(0.25)
                }
                renderer = self.drawingAreaRenderer
            #endif
        }
        
        return renderer ?? MKOverlayRenderer(overlay: overlay)
    }
    
    
    //MARK: - Audio Support
    
    private func initilizeAudioPlayer() {
        // set our default audio session state
        self.setSessionActiveWithMixing(false)
        
        let heroSoundURL = Bundle.main.url(forResource: "Hero", withExtension: "aiff")!
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: heroSoundURL)
        } catch _ {
            audioPlayer = nil
        }
    }
    
    private func setSessionActiveWithMixing(_ duckIfOtherAucioIsPlaying: Bool) {
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            }
        } catch _ {
        }
        
        if AVAudioSession.sharedInstance().isOtherAudioPlaying && duckIfOtherAucioIsPlaying {
            do {
                if #available(iOS 10.0, *) {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                } else {
                    try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers, .duckOthers])
                }
            } catch _ {
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch _ {
        }
    }
    
    private func playSound() {
        if self.audioPlayer?.isPlaying == false {
            self.audioPlayer.prepareToPlay()
            self.audioPlayer.play()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch _ {
        }
    }
    
}
