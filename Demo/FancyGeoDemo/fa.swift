//
//  ViewController.swift
//  FancyGeoDemo
//
//  Created by Osei Fortune on 12/20/18.
//  Copyright © 2018 Osei Fortune. All rights reserved.
//

import UIKit
import GoogleMaps
import FancyGeo
class ViewController: UIViewController, GMSMapViewDelegate {
    var fancy: FancyGeo?
    var mapView: GMSMapView?
    override func viewDidLoad() {
        super.viewDidLoad()
        fancy = FancyGeo.sharedInstance()
        FancyGeo.onMessageReceivedListener = ({(fence) in
            print("message tapped", fence)
        })
        let camera = GMSCameraPosition.camera(withLatitude: 37.422, longitude:-122.084, zoom: 12.0)
        self.mapView = GMSMapView.map(withFrame: CGRect.zero, camera: camera)
        self.view = mapView
        
        // Creates a marker in the center of the map.
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: 37.422, longitude:-122.084)
        marker.title = "Google"
        marker.snippet = "Plex"
        marker.map = mapView
        mapView!.delegate = self;
        if(fancy?.hasPermission() ?? false){
            self.mapView!.isMyLocationEnabled = true
        }
        let fences = fancy?.getAllFences() ?? []
        print("fences",fences.count)
        for fence in fences as! [String]{
            let type = FancyGeo.getType(json: fence)
            if(type == "circle"){
                let circle =  FancyGeo.CircleFence.fromString(json: fence)
                if(circle != nil){
                    let coordinates = CLLocationCoordinate2D.init(latitude: circle?.coordinates.first ?? 0, longitude: circle?.coordinates.last ?? 0)
                    let marker = GMSCircle(position: coordinates, radius: circle?.radius ?? 0)
                    marker.strokeColor = .black
                    marker.strokeWidth = 5
                    marker.map = mapView
                }
            }
        }
        
    }
    
    func createFence(coordinate: CLLocationCoordinate2D) {
        let notification =  FancyGeo.FenceNotification.initWithIdTitleBody(id: 0, title: "Test", body: "Test Body")
        fancy?.createFenceCircle(id: nil, transition: .ENTER_EXIT, notification: notification ,loiteringDelay: 0, points: [coordinate.latitude, coordinate.longitude], radius: 1000) { (id, error) in
            if(id != nil){
                let circle = GMSCircle(position: coordinate, radius: 1000)
                circle.strokeColor = .black
                circle.strokeWidth = 5
                circle.map = self.mapView
            }
        }
    }
    
    func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        let hasPermission = fancy?.hasPermission() ?? false
        fancy?.hasNotificationsPermission(callback: { (hasNotificationPermission, notificationPermissionError) in
            if(hasNotificationPermission){
                if !hasPermission {
                    self.fancy?.requestPermission(always: true, callback: { (hasPermission, error ) in
                        if(hasPermission){
                            mapView.isMyLocationEnabled = true
                            self.createFence(coordinate: coordinate)
                        }
                    })
                }else{
                    mapView.isMyLocationEnabled = true
                    self.createFence(coordinate: coordinate)
                }
            }else{
                self.fancy?.requestNotificationsPermission(callback: { (has, e) in
                    if(has){
                        if !hasPermission {
                            self.fancy?.requestPermission(always: true, callback: { (hasPermission, error ) in
                                if(hasPermission){
                                    mapView.isMyLocationEnabled = true
                                    self.createFence(coordinate: coordinate)
                                }
                            })
                        }else{
                            mapView.isMyLocationEnabled = true
                            self.createFence(coordinate: coordinate)
                        }
                    }
                })
            }
        })
    }
    
    
    
    
}

