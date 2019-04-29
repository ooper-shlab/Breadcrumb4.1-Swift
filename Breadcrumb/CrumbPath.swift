//
//  CrumbPath.swift
//  Breadcrumb
//
//  Translated by OOPer in cooperation with shlab.jp on 2014/12/19.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  CrumbPath is an MKOverlay model class representing a path that changes over time.

 */

import MapKit


let MINIMUM_DELTA_METERS = 10.0


@objc(CrumbPath)
class CrumbPath: NSObject, MKOverlay {
    
    // Updated by -addCoordinate:boundingMapRectChanged: if needed to contain the new coordinate.
    var boundingMapRect: MKMapRect
    
    private var pointBuffer: [MKMapPoint] = []
    
    private var rwLock = pthread_rwlock_t()
    
    
    
    //MARK: -
    
    // Initialize the CrumbPath with the starting coordinate.
    // The CrumbPath's boundingMapRect will be set to a sufficiently large square
    // centered on the starting coordinate.
    //
    init(center coord: CLLocationCoordinate2D) {
        // Initialize point storage and place this first coordinate in it
        pointBuffer.reserveCapacity(1000)
        let origin = MKMapPoint(coord)
        pointBuffer.append(origin)
        
        // Default -boundingMapRect size is 1km^2 centered on coord
        let oneKilometerInMapPoints = 1000 * MKMapPointsPerMeterAtLatitude(coord.latitude)
        let oneSquareKilometer = MKMapSize(width: oneKilometerInMapPoints, height: oneKilometerInMapPoints)
        boundingMapRect = MKMapRect(origin: origin, size: oneSquareKilometer)
        super.init()
        
        // Clamp the rect to be within the world
        boundingMapRect = boundingMapRect.intersection(.world)
        
        // Initialize read-write lock for drawing and updates
        //
        // We didn't use this lock during this method because
        // it's our user's responsibility not to use us before
        // -init completes.
        pthread_rwlock_init(&rwLock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&rwLock)
    }
    
    var coordinate : CLLocationCoordinate2D {
        var centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.readPointsWithBlockAndWait {pointsArray in
            centerCoordinate = pointsArray[0].coordinate
        }
        return centerCoordinate
    }
    
    // Synchronously evaluate a block with the current buffer of points.
    func readPointsWithBlockAndWait(_ block: ([MKMapPoint]) -> Void) {
        // Acquire the write lock so the list of points isn't changed while we read it
        pthread_rwlock_wrlock(&rwLock)
        block(pointBuffer)
        pthread_rwlock_unlock(&rwLock)
    }
    
    private func growOverlayBounds(_ overlayBounds: MKMapRect, toInclude otherRect: MKMapRect) -> MKMapRect {
        // The -boundingMapRect we choose was too small.
        // We grow it to be both rects, plus about
        // an extra kilometer in every direction that was too small before.
        // Usually the crumb-trail will keep growing in the direction it grew before
        // so this minimizes having to regrow, without growing off-trail.
        
        var grownBounds = overlayBounds.union(otherRect)
        
        // Pedantically, to grow the overlay by one real kilometer, we would need to
        // grow different sides by a different number of map points, to account for
        // the number of map points per meter changing with latitude.
        // But we don't need to be exact. The center of the rect that ran over
        // is a good enough estimate for where we'll be growing the overlay.
        
        let oneKilometerInMapPoints = 1000*MKMapPointsPerMeterAtLatitude(otherRect.origin.coordinate.latitude)
        
        // Grow by an extra kilometer in the direction of each overrun.
        if otherRect.minY < overlayBounds.minY {
            grownBounds.origin.y -= oneKilometerInMapPoints
            grownBounds.size.height += oneKilometerInMapPoints
        }
        if otherRect.maxX > overlayBounds.maxX {
            grownBounds.size.height += oneKilometerInMapPoints
        }
        if otherRect.minX < overlayBounds.minX {
            grownBounds.origin.x -= oneKilometerInMapPoints
            grownBounds.size.width += oneKilometerInMapPoints
        }
        if otherRect.maxX > overlayBounds.maxX {
            grownBounds.size.width += oneKilometerInMapPoints
        }
        
        // Clip to world size
        grownBounds = grownBounds.intersection(.world)
        
        return grownBounds
    }
    
    private func mapRectContainingPoint(_ p1: MKMapPoint, andPoint p2: MKMapPoint) -> MKMapRect {
        let pointSize = MKMapSize(width: 0, height: 0)
        let newPointRect = MKMapRect(origin: p1, size: pointSize)
        let prevPointRect = MKMapRect(origin: p2, size: pointSize)
        return newPointRect.union(prevPointRect)
    }
    
    // Add a location observation. A MKMapRect containing the newly added point
    // and the previously added point is returned so that the view can be updated
    // in that rectangle.  If the added coordinate has not moved far enough from
    // the previously added coordinate it will not be added to the list and
    // MKMapRectNull will be returned.
    //
    func addCoordinate(_ newCoord: CLLocationCoordinate2D, boundingMapRectChanged boundingMapRectChangedOut: UnsafeMutablePointer<Bool>?) -> MKMapRect {
        // Acquire the write lock because we are going to be changing the list of points
        pthread_rwlock_wrlock(&rwLock)
        
        //Assume no changes until we make one.
        var boundingMapRectChanged = false
        var updateRect = MKMapRect.null
        
        // Convert to map space
        let newPoint = MKMapPoint(newCoord)
        
        // Get the distance between this new point and the previous point.
        let prevPoint = pointBuffer.last!
        let metersApart = newPoint.distance(to: prevPoint)
        
        // Ignore the point if it's too close to the previous one.
        if metersApart > MINIMUM_DELTA_METERS {
            
            // Add the new point to the points buffer
            pointBuffer.append(newPoint)
            
            // Compute MKMapRect bounding prevPoint and newPoint
            updateRect = self.mapRectContainingPoint(newPoint, andPoint: prevPoint)
            
            //Update the -boundingMapRect to hold the new point if needed
            let overlayBounds = self.boundingMapRect
            if !overlayBounds.contains(updateRect) {
                self.boundingMapRect = self.growOverlayBounds(overlayBounds, toInclude: updateRect)
                boundingMapRectChanged = true
            }
        }
        
        // Report if -boundingMapRect changed
        boundingMapRectChangedOut?.pointee = boundingMapRectChanged
        
        pthread_rwlock_unlock(&rwLock)
        
        return updateRect
    }
    
}
