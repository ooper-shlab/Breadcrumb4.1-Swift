//
//  BreadcrumbAppDelegate.swift
//  Breadcrumb
//
//  Translated by OOPer in cooperation with shlab.jp on 2014/12/19.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  Template delegate for the application.

 */

import UIKit
import MapKit // for MKUserTrackingModeNone

@objc(BreadcrumbAppDelegate)
@UIApplicationMain
class BreadcrumbAppDelegate: NSObject, UIApplicationDelegate {
    
    // The app delegate must implement the window @property
    // from UIApplicationDelegate @protocol to use a main storyboard file.
    var window: UIWindow?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // it is important to registerDefaults as soon as possible,
        // because it can change so much of how your app behaves
        //
        var defaultsDictionary: [String : AnyObject] = [:]
        
        // by default we track the user location while in the background
        defaultsDictionary[TrackLocationInBackgroundPrefsKey] = true as NSNumber
        
        // by default we use the best accuracy setting (kCLLocationAccuracyBest)
        defaultsDictionary[LocationTrackingAccuracyPrefsKey] = kCLLocationAccuracyBest as NSNumber
        
        // by default we play a sound in the background to signify a location change
        defaultsDictionary[PlaySoundOnLocationUpdatePrefsKey] = true as NSNumber
        
        UserDefaults.standard.register(defaults: defaultsDictionary)
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        //..
        return true
    }
    
}
