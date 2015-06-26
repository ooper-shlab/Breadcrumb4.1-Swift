//
//  CrumbPathRenderer.swift
//  Breadcrumb
//
//  Translated by OOPer in cooperation with shlab.jp on 2014/12/19.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  CrumbPathView is an MKOverlayView subclass that displays a path that changes over time.
  This class also demonstrates the fastest way to convert a list of MKMapPoints into a CGPath for drawing in an overlay view.

 */

import MapKit


private func LineBetweenPointsIntersectsRect(p0: MKMapPoint, p1: MKMapPoint, r:MKMapRect) -> Bool {
    let minX = min(p0.x, p1.x)
    let minY = min(p0.y, p1.y)
    let maxX = max(p0.x, p1.x)
    let maxY = max(p0.y, p1.y)
    
    let r2 = MKMapRectMake(minX, minY, maxX - minX, maxY - minY)
    return MKMapRectIntersectsRect(r, r2)
}


private func pow2<T: ArithmeticType>(a: T) -> T {
    return a * a
}

@objc(CrumbPathRenderer)
class CrumbPathRenderer: MKOverlayRenderer {
    
    override func drawMapRect(mapRect: MKMapRect, zoomScale: MKZoomScale, inContext context: CGContext) {
        let crumbs = self.overlay as! CrumbPath
        
        let lineWidth = MKRoadWidthAtZoomScale(zoomScale)
        
        // outset the map rect by the line width so that points just outside
        // of the currently drawn rect are included in the generated path.
        let clipRect = MKMapRectInset(mapRect, Double(-lineWidth), Double(-lineWidth))
        
        var path: CGPath?
        crumbs.readPointsWithBlockAndWait {points in
            path = self.newPathForPoints(points,
                clipRect: clipRect,
                zoomScale: zoomScale)
        }
        
        if path != nil {
            CGContextAddPath(context, path)
            CGContextSetRGBStrokeColor(context, 0.0, 0.0, 1.0, 0.5)
            CGContextSetLineJoin(context, CGLineJoin.Round)
            CGContextSetLineCap(context, CGLineCap.Round)
            CGContextSetLineWidth(context, lineWidth)
            CGContextStrokePath(context)
        }
    }
    
    
    //MARK: - Private Implementation
    
    private func newPathForPoints(points: [MKMapPoint],
        clipRect mapRect: MKMapRect,
        zoomScale: MKZoomScale) -> CGPath? {
            var path: CGMutablePath?
            
            // The fastest way to draw a path in an MKOverlayView is to simplify the
            // geometry for the screen by eliding points that are too close together
            // and to omit any line segments that do not intersect the clipping rect.
            // While it is possible to just add all the points and let CoreGraphics
            // handle clipping and flatness, it is much faster to do it yourself:
            //
            if points.count > 1 {
                path = CGPathCreateMutable()
                
                var needsMove = true
                
                // Calculate the minimum distance between any two points by figuring out
                // how many map points correspond to MIN_POINT_DELTA of screen points
                // at the current zoomScale.
                let MIN_POINT_DELTA = 5.0
                let minPointDelta = MIN_POINT_DELTA / Double(zoomScale)
                let c2 = pow2(minPointDelta)
                
                var lastPoint = points[0]
                for i in 1..<points.count - 1 {
                    let point = points[i]
                    let a2b2 = pow2(point.x - lastPoint.x) + pow2(point.y - lastPoint.y)
                    if a2b2 >= c2 {
                        if LineBetweenPointsIntersectsRect(point, p1: lastPoint, r: mapRect) {
                            if needsMove {
                                let lastCGPoint = self.pointForMapPoint(lastPoint)
                                CGPathMoveToPoint(path, nil, lastCGPoint.x, lastCGPoint.y)
                            }
                            let cgPoint = self.pointForMapPoint(point)
                            CGPathAddLineToPoint(path, nil, cgPoint.x, cgPoint.y)
                            needsMove = false
                        } else {
                            // discontinuity, lift the pen
                            needsMove = true
                        }
                        lastPoint = point
                    }
                }
                
                // If the last line segment intersects the mapRect at all, add it unconditionally
                let point = points.last!
                if LineBetweenPointsIntersectsRect(point, p1: lastPoint, r: mapRect) {
                    if needsMove {
                        let lastCGPoint = self.pointForMapPoint(lastPoint)
                        CGPathMoveToPoint(path, nil, lastCGPoint.x, lastCGPoint.y)
                    }
                    let cgPoint = self.pointForMapPoint(point)
                    CGPathAddLineToPoint(path, nil, cgPoint.x, cgPoint.y)
                }
            }
            return path
    }
    
}