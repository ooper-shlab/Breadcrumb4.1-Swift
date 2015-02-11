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

private func DescriptionOfCLAuthorizationStatus(st: CLAuthorizationStatus) -> String {
    switch st {
    case .NotDetermined:
        return "kCLAuthorizationStatusNotDetermined"
    case .Restricted:
        return "kCLAuthorizationStatusRestricted"
    case .Denied:
        return "kCLAuthorizationStatusDenied"
        //case kCLAuthorizationStatusAuthorized: is the same as
        //kCLAuthorizationStatusAuthorizedAlways
    case .AuthorizedAlways: //iOS 8.2 or later        
        return "kCLAuthorizationStatusAuthorizedAlways"
        
    case .AuthorizedWhenInUse:
        return "kCLAuthorizationStatusAuthorizedWhenInUse"
    default:
        "Unknown CLAuthorizationStatus value: \(st.rawValue)"
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
    func settingsDidChange(notification: NSNotification) {
        let settings = NSUserDefaults.standardUserDefaults()
        
        // update our location manager for these settings changes:
        
        // accuracy (CLLocationAccuracy)
        let desiredAccuracy = settings.doubleForKey(LocationTrackingAccuracyPrefsKey) as CLLocationAccuracy
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
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "settingsDidChange:",
            name: NSUserDefaultsDidChangeNotification,
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
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
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
        if self.locationManager.respondsToSelector("requestWhenInUseAuthorization") {
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
            NSUserDefaults.standardUserDefaults().doubleForKey(LocationTrackingAccuracyPrefsKey)
        
        // start tracking the user's location
        self.locationManager.startUpdatingLocation()
        
        // Observe the application going in and out of the background, so we can toggle location tracking.
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "handleUIApplicationDidEnterBackgroundNotification:",
            name: UIApplicationDidEnterBackgroundNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "handleUIApplicationWillEnterForegroundNotification:",
            name: UIApplicationWillEnterForegroundNotification,
            object: nil)
    }
    
    func handleUIApplicationDidEnterBackgroundNotification(note: NSNotification) {
        self.switchToBackgroundMode(true)
    }
    
    func handleUIApplicationWillEnterForegroundNotification(note: NSNotification) {
        self.switchToBackgroundMode(false)
    }
    
    // called when the app is moved to the background (user presses the home button) or to the foreground
    
    private func switchToBackgroundMode(background: Bool) {
        if NSUserDefaults.standardUserDefaults().boolForKey(TrackLocationInBackgroundPrefsKey) {
            return
        }
        
        if background {
            self.locationManager.stopUpdatingLocation()
        } else {
            self.locationManager.startUpdatingLocation()
        }
    }
    
    private func coordinateRegionWithCenter(centerCoordinate: CLLocationCoordinate2D, approximateRadiusInMeters radiusInMeters: CLLocationDistance) -> MKCoordinateRegion {
        // Multiplying by MKMapPointsPerMeterAtLatitude at the center is only approximate, since latitude isn't fixed
        //
        let radiusInMapPoints = radiusInMeters * MKMapPointsPerMeterAtLatitude(centerCoordinate.latitude)
        let radiusSquared = MKMapSize(width: radiusInMapPoints, height: radiusInMapPoints)
        
        let regionOrigin = MKMapPointForCoordinate(centerCoordinate)
        var regionRect = MKMapRect(origin: regionOrigin, size: radiusSquared)
        
        regionRect = MKMapRectOffset(regionRect, -radiusInMapPoints/2, -radiusInMapPoints/2)
        
        // clamp the rect to be within the world
        regionRect = MKMapRectIntersection(regionRect, MKMapRectWorld)
        
        let region = MKCoordinateRegionForMapRect(regionRect)
        return region
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if locations != nil && locations.count > 0 {
            if NSUserDefaults.standardUserDefaults().boolForKey(PlaySoundOnLocationUpdatePrefsKey) {
                self.setSessionActiveWithMixing(true)
                self.playSound()
            }
            
            // we are not using deferred location updates, so always use the latest location
            let newLocation = locations[0] as! CLLocation
            
            if self.crumbs == nil {
                // This is the first time we're getting a location update, so create
                // the CrumbPath and add it to the map.
                //
                crumbs = CrumbPath(centerCoordinate: newLocation.coordinate)
                self.map.addOverlay(self.crumbs, level: .AboveRoads)
                
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
                    self.map.addOverlay(self.crumbs, level: .AboveRoads)
                    
                    let r = self.crumbs!.boundingMapRect
                    var pts: [MKMapPoint] = [
                        MKMapPointMake(MKMapRectGetMinX(r), MKMapRectGetMinY(r)),
                        MKMapPointMake(MKMapRectGetMinX(r), MKMapRectGetMaxY(r)),
                        MKMapPointMake(MKMapRectGetMaxX(r), MKMapRectGetMaxY(r)),
                        MKMapPointMake(MKMapRectGetMaxX(r), MKMapRectGetMinY(r)),
                    ]
                    let count = pts.count
                    let boundingMapRectOverlay = MKPolygon(points: &pts, count: count)
                    self.map.addOverlay(boundingMapRectOverlay, level: .AboveRoads)
                } else if !MKMapRectIsNull(updateRect) {
                    // There is a non null update rect.
                    // Compute the currently visible map zoom scale
                    let currentZoomScale = MKZoomScale(self.map.bounds.size.width / CGFloat(self.map.visibleMapRect.size.width))
                    // Find out the line width at this zoom scale and outset the updateRect by that amount
                    let lineWidth = MKRoadWidthAtZoomScale(currentZoomScale)
                    updateRect = MKMapRectInset(updateRect, Double(-lineWidth), Double(-lineWidth))
                    // Ask the overlay view to update just the changed area.
                    self.crumbPathRenderer?.setNeedsDisplayInMapRect(updateRect)
                }
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        NSLog("%@:%d %@", __FILE__, __LINE__, error);
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSLog("%@:%d %@", __FILE__, __LINE__, DescriptionOfCLAuthorizationStatus(status));
    }
    
    
    //MARK: - MapKit
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
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
                    self.drawingAreaRenderer!.fillColor = UIColor.blueColor().colorWithAlphaComponent(0.25)
                }
                renderer = self.drawingAreaRenderer
            #endif
        }
        
        return renderer
    }
    
    
    //MARK: - Audio Support
    
    private func initilizeAudioPlayer() {
        // set our default audio session state
        self.setSessionActiveWithMixing(false)
        
        let heroSoundURL = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("Hero", ofType: "aiff")!)!
        audioPlayer = AVAudioPlayer(contentsOfURL: heroSoundURL, error: nil)
    }
    
    private func setSessionActiveWithMixing(duckIfOtherAucioIsPlaying: Bool) {
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: .MixWithOthers, error: nil)
        
        if AVAudioSession.sharedInstance().otherAudioPlaying && duckIfOtherAucioIsPlaying {
            AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: .MixWithOthers | .DuckOthers, error: nil)
        }
        
        AVAudioSession.sharedInstance().setActive(true, error: nil)
    }
    
    private func playSound() {
        if self.audioPlayer?.playing == false {
            self.audioPlayer.prepareToPlay()
            self.audioPlayer.play()
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        AVAudioSession.sharedInstance().setActive(false, error: nil)
    }
    
}
