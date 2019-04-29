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


private func LineBetweenPointsIntersectsRect(_ p0: MKMapPoint, _ p1: MKMapPoint, _ r:MKMapRect) -> Bool {
    let minX = min(p0.x, p1.x)
    let minY = min(p0.y, p1.y)
    let maxX = max(p0.x, p1.x)
    let maxY = max(p0.y, p1.y)
    
    let r2 = MKMapRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    return r.intersects(r2)
}


private func pow2<T: Numeric>(_ a: T) -> T {
    return a * a
}

@objc(CrumbPathRenderer)
class CrumbPathRenderer: MKOverlayRenderer {
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let crumbs = self.overlay as! CrumbPath
        
        let lineWidth = MKRoadWidthAtZoomScale(zoomScale)
        
        // outset the map rect by the line width so that points just outside
        // of the currently drawn rect are included in the generated path.
        let clipRect = mapRect.insetBy(dx: Double(-lineWidth), dy: Double(-lineWidth))
        
        var path: CGPath?
        crumbs.readPointsWithBlockAndWait {points in
            path = self.newPathForPoints(points,
                                         clipRect: clipRect,
                                         zoomScale: zoomScale)
        }
        
        if let path = path {
            context.addPath(path)
            context.setStrokeColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.5)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
    }
    
    
    //MARK: - Private Implementation
    
    private func newPathForPoints(_ points: [MKMapPoint],
                                  clipRect mapRect: MKMapRect,
                                  zoomScale: MKZoomScale) -> CGPath? {
        
        // The fastest way to draw a path in an MKOverlayView is to simplify the
        // geometry for the screen by eliding points that are too close together
        // and to omit any line segments that do not intersect the clipping rect.
        // While it is possible to just add all the points and let CoreGraphics
        // handle clipping and flatness, it is much faster to do it yourself:
        //
        guard points.count > 1 else {
            return nil
        }
        let path = CGMutablePath()
        
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
                if LineBetweenPointsIntersectsRect(point, lastPoint, mapRect) {
                    if needsMove {
                        let lastCGPoint = self.point(for: lastPoint)
                        path.move(to: lastCGPoint)
                    }
                    let cgPoint = self.point(for: point)
                    path.addLine(to: cgPoint)
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
        if LineBetweenPointsIntersectsRect(point, lastPoint, mapRect) {
            if needsMove {
                let lastCGPoint = self.point(for: lastPoint)
                path.move(to: lastCGPoint)
            }
            let cgPoint = self.point(for: point)
            path.addLine(to: cgPoint)
        }
        return path
        
    }
    
}
