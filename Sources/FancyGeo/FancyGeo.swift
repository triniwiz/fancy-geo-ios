    //
    //  FancyGeo.swift
    //  FancyGeo
    //
    //  Created by Osei Fortune on 12/17/18.
    //  Copyright © 2018 Osei Fortune. All rights reserved.
    //
    
    import Foundation
    import CoreLocation
    import UserNotifications
    
    
    extension CLLocationManager {
        private struct FancyManagerProperties{
            static var fancyId: String? = nil
        }
        public var fancyId: String? {
            set {
                if let unwrappedValue = newValue{
                    objc_setAssociatedObject(self, &FancyManagerProperties.fancyId, unwrappedValue as NSString?, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            get {
                return objc_getAssociatedObject(self, &FancyManagerProperties.fancyId) as? String
            }
        }
    }
    
    @objc(FancyGeo)
    public class FancyGeo : NSObject, CLLocationManagerDelegate {
        private var locationManager: CLLocationManager?
        private var isGettingCurrentLocation: Bool = false
        typealias Codable = Encodable & Decodable
        public static let GEO_LOCATION_DATA: String = "FANCY_GEO_LOCATION_DATA"
        private var defaults: UserDefaults?
        private static var callbacks:[String: (String?, String?) -> Void] = [:]
        private static var managers: [String: CLLocationManager] = [:]
        private static var locationCallbacks:[String: (String?, String?) -> Void] = [:]
        private static var permissions:[String: FancyPermission] = [:]
        private var PREFIX = "_fancy_geo_"
        public static var onMessageReceivedListener: (() -> Void)?
        
        
        @objc class FancyPermission: NSObject {
            public let always: Bool
            public var callBack: ((Bool, String?) -> Void)?
            init(always: Bool) {
                self.always = always
            }
        }
    
        @objc public enum FenceTransition: Int, Codable{
            case ENTER
            case DWELL
            case EXIT
            case ENTER_EXIT
            case ENTER_DWELL
            case DWELL_EXIT
            case ALL
        }
        
        @objc public static func initNotificationsDelegate(delegate: UNUserNotificationCenterDelegate){
            let center = UNUserNotificationCenter.current()
            center.delegate = delegate
        }
        
        @objc public class FenceNotification : NSObject, Codable {
            public var id: Int
            public var title: String
            public var body: String
            public var requestId: String
            
            @objc public static func initWithIdTitleBody(id: Int, title: String, body: String) -> FenceNotification {
                return FenceNotification(id: id, title: title, body: body, requestId: UUID().uuidString)
            }
            
            init(id: Int, title: String, body: String, requestId: String) {
                self.id = id;
                self.title = title;
                self.body = body;
                self.requestId = requestId;
            }
        }
        
        @objc public class FancyCoordinate: NSObject, Codable {
            public let latitude: Double
            public let longitude: Double
            init(lat: Double, lon: Double) {
                self.latitude = lat
                self.longitude = lon
            }
            
            public func getCoordinates() -> CLLocationCoordinate2D {
                return CLLocationCoordinate2D.init(latitude: latitude, longitude: longitude)
            }
        }
        
        @objc public class FancyLocation: NSObject , Codable {
            public let coordinate: FancyCoordinate
            public let altitude: Double
            public let horizontalAccuracy: Double
            public let verticalAccuracy: Double
            public let speed:Double
            public let direction: Double
            public let timestamp: Double
            init(location: CLLocation) {
                coordinate = FancyCoordinate.init(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
                altitude = location.altitude
                direction = location.course
                horizontalAccuracy = location.horizontalAccuracy
                verticalAccuracy = location.verticalAccuracy
                speed = location.speed
                let ts = Date.init(timeInterval: 0, since: location.timestamp).timeIntervalSince1970
                timestamp = ts * 1000
            }
        }
        
        @objc public class FenceShape: NSObject , Codable {
            
            public var transition: FenceTransition
            
            public var loiteringDelay:Int
            
            public var coordinates: Array<Double>
            
            public var id: String
            
            public var type: String
            
            public var notification: FenceNotification?
            
            init(id: String, transition: FenceTransition,coordinates: Array<Double>, type: String, loiteringDelay: Int) {
                self.id = id
                self.transition = FenceTransition.ENTER
                self.coordinates = coordinates
                self.loiteringDelay = loiteringDelay
                self.type = type
            }
            
            init(id: String, transition: FenceTransition,coordinates: Array<Double>, type: String, loiteringDelay: Int, notification: FenceNotification?) {
                self.id = id
                self.transition = FenceTransition.ENTER
                self.coordinates = coordinates
                self.loiteringDelay = loiteringDelay
                self.type = type
                self.notification = notification
            }
            
            public func toJson() -> String {
                return String()
            }
            
        }
        
        @objc public static func getType(json: String) -> String {
            if (json.isEmpty) {
                return "";
            }
            let jsonData = json.data(using: .utf8)
            let decoder = JSONDecoder()
            do{
                let fence = try decoder.decode(FancyGeo.FenceShape.self, from: jsonData ?? Data())
                return fence.type
            }catch{
                return ""
            }
        }
        
        
        @objc public class CircleFence: FenceShape {
            
            public var radius: Double
            
            
            private enum CircleFenceKeys: CodingKey  {
                case radius
                case transition
                case coordinates
                case type
                case loiteringDelay
                case id
            }
            
            @objc public static func initWithIdTransitionCoordinatesRadiusNotification(id: String, transition: FenceTransition,coordinates: Array<Double>, radius: Double, notification: FenceNotification?) -> CircleFence{
                let circle: CircleFence = CircleFence.initWithIdTransitionCoordinatesRadiusLoiteringDelay(id: id , transition: transition, coordinates: coordinates, radius:radius,loiteringDelay: -1)
                circle.radius = radius
                circle.notification = notification
                return circle
            }
            
            @objc public static func initWithIdTransitionCoordinatesRadiusLoiteringDelay(id: String, transition: FenceTransition,coordinates: Array<Double>, radius: Double, loiteringDelay: Int) -> CircleFence{
                let circle: CircleFence = CircleFence.init(id: id , transition: transition, coordinates: coordinates, type: "circle", loiteringDelay: loiteringDelay)
                circle.radius = radius
                return circle
            }
            
            override init(id: String, transition: FenceTransition, coordinates: Array<Double>, type: String, loiteringDelay: Int) {
                self.radius = 0
                super.init(id: id, transition: transition, coordinates: coordinates, type: type, loiteringDelay: loiteringDelay)
            }
            
            
            public override func encode(to encoder: Encoder) throws {
                try super.encode(to: encoder)
                var values = encoder.container(keyedBy: CircleFenceKeys.self)
                try values.encode(radius, forKey: CircleFenceKeys.radius)
            }
            
            required init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CircleFenceKeys.self)
                self.radius = try values.decode(Double.self, forKey: .radius)
                try super.init(from: decoder)
            }
            
            @objc public override func toJson() -> String {
                let encoder = JSONEncoder()
                do{
                    let json = try encoder.encode(self)
                    return String(data: json, encoding: .utf8) ?? ""
                }catch{
                    return ""
                }
            }
            
            
            @objc public static func fromString (json: String) -> CircleFence? {
                let decoder = JSONDecoder()
                do{
                    let jsonData = json.data(using: .utf8) ?? Data()
                    let decoded = try decoder.decode(FancyGeo.CircleFence.self, from: jsonData)
                    return decoded
                }catch{
                    return nil
                }
            }
            
        }
        
        public override init() {
            super.init()
            defaults = UserDefaults.init(suiteName: FancyGeo.GEO_LOCATION_DATA)
            locationManager = CLLocationManager()
            locationManager?.delegate = self;
        }
        
        @objc public func requestNotificationsPermission(callback: @escaping (Bool,String?) -> Void){
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .badge]) { (hasPermission, requestError) in
                    DispatchQueue.main.async {
                    if(requestError != nil){
                        callback(false, requestError?.localizedDescription)
                    }else{
                        callback(hasPermission,nil)
                    }
                    }
                }
        }
        
        @objc public func hasNotificationsPermission(callback: @escaping (Bool, String?) -> Void){
                let center = UNUserNotificationCenter.current()
                center.getNotificationSettings { (settings) in
                    DispatchQueue.main.async {
                    switch(settings.authorizationStatus){
                    case .authorized:
                        callback(true,nil)
                        break
                    case .denied:
                        callback(false,"Authorization Denied.")
                        break
                    case .notDetermined:
                        callback(false,"Authorization Not Determined.")
                        break
                    case .provisional:
                        break
                    }
                    }
                }
        }
        
        @objc public func requestPermission(always: Bool, callback : ((_ hasPermission: Bool, _ error: String?) -> Void)?){
            let manager = CLLocationManager()
            manager.fancyId = UUID.init().uuidString
            FancyGeo.managers[manager.fancyId!] = manager
            let permission = FancyPermission(always: always)
            permission.callBack = callback
            if(callback != nil){
             FancyGeo.permissions[manager.fancyId!] = permission
            }
            manager.delegate = self
            
            if always {
                manager.requestAlwaysAuthorization()
            }else{
                manager.requestWhenInUseAuthorization()
            }
        }
        
        @objc public func hasPermission() -> Bool {
            return CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse
        }
        
        @objc public func getCurrentLocation(listener: () -> Void){
            let manager = CLLocationManager()
            manager.distanceFilter = kCLDistanceFilterNone
            manager.desiredAccuracy =  kCLLocationAccuracyBest
            manager.startUpdatingLocation()
            
        }
        
        @objc public func createFenceCircle(id: String?, transition: FenceTransition, notification: FenceNotification?, loiteringDelay: Int, points: Array<Double>,  radius: Double) -> Void{
            createFenceCircle(id: id, transition: transition,notification: notification ,loiteringDelay: loiteringDelay, points: points, radius: radius) { (id, error) in
                
            }
        }
        
        @objc public func createFenceCircle(id: String?, transition: FenceTransition, notification: FenceNotification?, loiteringDelay: Int, points: Array<Double>,  radius: Double, onListener : @escaping (_ id: String?, _ error: String?) -> Void ) -> Void{
            
            if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self){
                onListener(nil,"Geofencing is not supported on this device!")
                return;
            }
            
            if CLLocationManager.authorizationStatus() != .authorizedAlways {
                onListener(nil,"Authorization Denied.")
                return;
            }
            
            let requestId = id ?? UUID().uuidString
            let lat = CLLocationDegrees(points[0])
            let lon = CLLocationDegrees(points[1])
            let cordinates = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let maxRadius = locationManager?.maximumRegionMonitoringDistance ?? 0
            let inputRadius = CLLocationDistance(radius)
            let requestRadius = inputRadius > maxRadius ? maxRadius : inputRadius
            let circle = CircleFence.initWithIdTransitionCoordinatesRadiusLoiteringDelay(id: requestId, transition: transition, coordinates: points, radius: radius, loiteringDelay: loiteringDelay)
            circle.notification = notification
            let region = CLCircularRegion(center: cordinates, radius: requestRadius, identifier: requestId)
            
            switch transition {
            case .ENTER:
                region.notifyOnEntry = true;
                region.notifyOnExit = false;
            case .DWELL: break
            case .EXIT:
                region.notifyOnExit = true;
                region.notifyOnEntry = false;
            case .ENTER_DWELL:
                region.notifyOnEntry = true;
            case .DWELL_EXIT:
                region.notifyOnExit = true;
                region.notifyOnExit = false;
            case .ENTER_EXIT , .ALL:
                region.notifyOnEntry = true;
                region.notifyOnExit = true;
            }
            
            locationManager?.startMonitoring(for: region)
            print("stuff", circle.toJson())
            defaults?.set(circle.toJson(), forKey: makeKey(requestId))
            FancyGeo.callbacks[requestId] = onListener
        }
        
        
        private func makeKey(_ key: String) -> String{
            return PREFIX + key
        }
        
        @objc public func getAllFences() -> NSArray{
            let fences =  NSMutableArray()
            if(defaults != nil){
                let storedFences = defaults?.dictionaryRepresentation() ?? [:]
                let keys = storedFences.keys
                for key in keys {
                    if(key.starts(with: PREFIX)){
                        let fence = storedFences[key]
                        if(fence != nil){
                            fences.add(fence!)
                        }
                    }
                }
            }
            return fences
        }
        
        @objc public func getFence(id: String) -> String? {
            if(defaults != nil){
                return defaults?.value(forKey: PREFIX + id) as? String
            }
            return nil
        }
        
        @objc public func removeFence(id: String, onListener: ( (_ id: String) ->Void)?){
            let manager = CLLocationManager()
            print("remove", manager.monitoredRegions)
        }
        @objc public func removeAllFences() -> Void {
            
        }
        
        func createNotification(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
            let center =  UNUserNotificationCenter.current()
            print("createNotification", region.identifier)
            if(defaults != nil){
                let fenceJson = getFence(id: region.identifier)
                if(fenceJson != nil){
                    let fence = FancyGeo.getType(json: fenceJson!)
                    print("fence", fence)
                    switch(fence){
                    case "circle":
                        let circle = CircleFence.fromString(json: fenceJson!)
                        if(circle?.notification != nil){
                            let notification = circle?.notification
                            let content = UNMutableNotificationContent()
                            content.title = notification!.title
                            content.body = notification!.body
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                            let request = UNNotificationRequest(identifier: String(notification!.id), content: content, trigger: trigger)
                            center.add(request) { (error) in
                                if(error != nil){
                                    print("Notification Error " + (error?.localizedDescription)!)
                                }
                            }
                        }
                        break;
                    default:
                        return
                    }
                }
            }
        }
        
        
        public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
            let requestCallback =  FancyGeo.callbacks[region.identifier]
            if requestCallback != nil{
                requestCallback!(region.identifier,nil)
            }
        }
        
        public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
            print("monitoringDidFailFor")
            if(region != nil){
                let requestCallback = FancyGeo.callbacks[region?.identifier ?? ""]
                if requestCallback != nil{
                    requestCallback?(nil,error.localizedDescription)
                }
                
                if(defaults != nil){
                    defaults?.removeObject(forKey: makeKey(region?.identifier ?? ""))
                }
            }
        }
        
        public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
            
            
        }
        
        public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            
        }
        
        
        public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
            createNotification(manager, didExitRegion: region)
        }
        
        public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
            createNotification(manager, didExitRegion: region)
        }
        
        public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            if(manager.fancyId != nil){
                let request = FancyGeo.permissions[manager.fancyId ?? ""]
                let always = request?.always ?? false
                if(request?.callBack != nil){
                    switch(status){
                    case .authorizedAlways:
                        if(always){
                            request?.callBack!(true,nil)
                        }else{
                            request?.callBack!(false,"Authorization Denied.")
                        }
                        break;
                    case .authorizedWhenInUse:
                        if(!always){
                            request?.callBack!(true,nil)
                        }else{
                            request?.callBack!(false,"Authorization Denied.")
                        }
                        break;
                    case .denied:
                        request?.callBack!(false,"Authorization Denied.")
                        break;
                    case .notDetermined:
                        break;
                    case .restricted:
                        break;
                    }
                }
            }
        }
    }
