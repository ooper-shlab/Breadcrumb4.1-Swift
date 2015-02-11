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
    
    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // it is important to registerDefaults as soon as possible,
        // because it can change so much of how your app behaves
        //
        var defaultsDictionary: [NSObject : AnyObject] = [:]
        
        // by default we track the user location while in the background
        defaultsDictionary[TrackLocationInBackgroundPrefsKey] = true
        
        // by default we use the best accuracy setting (kCLLocationAccuracyBest)
        defaultsDictionary[LocationTrackingAccuracyPrefsKey] = kCLLocationAccuracyBest
        
        // by default we play a sound in the background to signify a location change
        defaultsDictionary[PlaySoundOnLocationUpdatePrefsKey] = true
        
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultsDictionary)
        
        return true
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        //..
        return true
    }
    
}
