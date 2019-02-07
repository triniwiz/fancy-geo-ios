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
   @objcMembers public class FancyGeo : NSObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
        private static let GEO_TRANSITION_TYPE = "type"
        private static var manager: CLLocationManager?
        private var isGettingCurrentLocation: Bool = false
        typealias Codable = Encodable & Decodable
        public static let GEO_LOCATION_DATA: String = "FANCY_GEO_LOCATION_DATA"
        private var defaults: UserDefaults?
        private static var callbacks:[String: (String?, String?) -> Void] = [:]
        private static var managers: [String: CLLocationManager] = [:]
        private static var locationCallbacks:[String: (String?, String?) -> Void] = [:]
        private static var permissions:[String: FancyPermission] = [:]
        private static var notificationTapped: String?
        private static let PREFIX = "_fancy_geo_"
        private static var instance: FancyGeo?
        public static var onMessageReceivedListener: ((_ fence: String ) -> Void)?
        private static var didRegisterUserNotificationSettingsObserver: NSObjectProtocol?
        private static func isActive() -> Bool {
            return UIApplication.shared.applicationState == .active
        }
        
        @objc public static func handleNotificationLegacy(notification: UILocalNotification){
            let id = notification.userInfo?["id"] as? String
            let defaults = UserDefaults.init(suiteName: FancyGeo.GEO_LOCATION_DATA)
            if defaults != nil {
                let fences =  defaults?.dictionaryRepresentation() ?? [:]
                for fence in fences {
                    if(fence.key.starts(with: FancyGeo.PREFIX)){
                        let type = getType(json: fence.value as! String)
                        switch(type){
                        case "circle":
                            let circle = CircleFence.fromString(json: fence.value as! String)
                            if circle != nil && circle?.notification != nil{
                                let notification = circle?.notification
                                let notificationId = String(notification!.id)
                                if(id != nil && id!.elementsEqual(notificationId)){
                                    FancyGeo.notificationTapped = fence.value as? String
                                }
                            }
                            break
                        default:
                            return
                        }
                    }
                }
            }
            
            if(isActive() && notificationTapped != nil){
                onMessageReceivedListener?(notificationTapped!)
            }
            
        }
        
        @available(iOS 10.0, *)
        @objc public static func handleNotification(center: UNUserNotificationCenter , response: UNNotificationResponse){
            let id = response.notification.request.identifier
            let defaults = UserDefaults.init(suiteName: FancyGeo.GEO_LOCATION_DATA)
            if defaults != nil {
                let fences =  defaults?.dictionaryRepresentation() ?? [:]
                for fence in fences {
                    if(fence.key.starts(with: FancyGeo.PREFIX)){
                        let type = getType(json: fence.value as! String)
                        switch(type){
                        case "circle":
                            let circle = CircleFence.fromString(json: fence.value as! String)
                            if circle != nil && circle?.notification != nil{
                                let notification = circle?.notification
                                let notificationId = String(notification!.id)
                                if(id.elementsEqual(notificationId)){
                                    FancyGeo.notificationTapped = fence.value as? String
                                }
                            }
                            break
                        default:
                            return
                        }
                    }
                }
            }
            
            if(isActive() && notificationTapped != nil){
                onMessageReceivedListener?(notificationTapped!)
            }
        }
        
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
        
        @objc public static func sharedInstance() -> FancyGeo {
            setUpInstance()
            return instance!
        }
        
        private static func setUpInstance() {
            if(instance == nil){
                instance = FancyGeo()
                if(manager == nil){
                    manager = CLLocationManager()
                    manager?.allowsBackgroundLocationUpdates = true
                    manager?.delegate = instance;
                }
            }
        }
        
        @objc public static func initFancyGeo(){
            if #available(iOS 10.0, *){
                let center = UNUserNotificationCenter.current()
                center.delegate = sharedInstance()
            }
            
            if isActive() && notificationTapped != nil {
                onMessageReceivedListener?(notificationTapped!)
            }
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
        
        override init() {
            super.init()
            defaults = UserDefaults.init(suiteName: FancyGeo.GEO_LOCATION_DATA)
        }
        
        @objc public func requestNotificationsPermission(callback: @escaping (Bool,String?) -> Void){
            if #available(iOS 10.0, *){
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
            }else {
                let notificationCenter = NotificationCenter.default
                FancyGeo.didRegisterUserNotificationSettingsObserver =  notificationCenter.addObserver(forName: NSNotification.Name(rawValue: "didRegisterUserNotificationSettings"), object: nil, queue: OperationQueue.main) { (result) in
                    if(FancyGeo.didRegisterUserNotificationSettingsObserver != nil){
                        notificationCenter.removeObserver(FancyGeo.didRegisterUserNotificationSettingsObserver!)
                    }
                    FancyGeo.didRegisterUserNotificationSettingsObserver = nil
                    let granted = result.userInfo?["message"] as? String
                    if(granted != nil){
                        callback(granted!.elementsEqual("true"),nil)
                    }else{
                        callback(false,nil)
                    }
                }
                let types = (UIApplication.shared.currentUserNotificationSettings?.types)!.rawValue | UIUserNotificationType.alert.rawValue | UIUserNotificationType.badge.rawValue | UIUserNotificationType.sound.rawValue;
                let settings = UIUserNotificationSettings(types: UIUserNotificationType(rawValue: types), categories: nil)
                UIApplication.shared.registerUserNotificationSettings(settings)
            }
        }
        
        @objc public func hasNotificationsPermission(callback: @escaping (Bool, String?) -> Void){
            if #available(iOS 10.0, *){
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
            }else{
                let types: UIUserNotificationType? =  UIApplication.shared.currentUserNotificationSettings?.types
                let required = UIUserNotificationType.alert.rawValue | UIUserNotificationType.badge.rawValue | UIUserNotificationType.sound.rawValue
                if types != nil {
                    switch(types!.rawValue){
                    case required:
                        callback(true, nil)
                        break
                    default:
                        callback(false, "Authorization Denied.")
                        break
                    }
                }else{
                    callback(false, "Authorization Denied.")
                }
                //let settings = UIUserNotificationSettings()
                //UIApplication.shared.registerUserNotificationSettings(<#T##notificationSettings: UIUserNotificationSettings##UIUserNotificationSettings#>)
            }
        }
        
        @objc public static func requestPermission(always: Bool, callback : ((_ hasPermission: Bool, _ error: String?) -> Void)?){
            let manager = CLLocationManager()
            manager.fancyId = UUID.init().uuidString
            FancyGeo.managers[manager.fancyId!] = manager
            let permission = FancyPermission(always: always)
            permission.callBack = callback
            if(callback != nil){
                FancyGeo.permissions[manager.fancyId!] = permission
            }
            manager.delegate = sharedInstance()
            
            if always {
                manager.requestAlwaysAuthorization()
            }else{
                manager.requestWhenInUseAuthorization()
            }
        }
        
        @objc public static func hasPermission() -> Bool {
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
            let maxRadius = FancyGeo.manager?.maximumRegionMonitoringDistance ?? 0
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
            
            FancyGeo.manager?.startMonitoring(for: region)
            defaults?.set(circle.toJson(), forKey: makeKey(requestId))
            FancyGeo.callbacks[requestId] = onListener
        }
        
        
        private func makeKey(_ key: String) -> String{
            return FancyGeo.PREFIX + key
        }
        
        @objc public func getAllFences() -> NSArray{
            let fences =  NSMutableArray()
            if(defaults != nil){
                let storedFences = defaults?.dictionaryRepresentation() ?? [:]
                let keys = storedFences.keys
                for key in keys {
                    if(key.starts(with: FancyGeo.PREFIX)){
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
                return defaults?.value(forKey: FancyGeo.PREFIX + id) as? String
            }
            return nil
        }
        
        @objc public func removeFence(id: String, callback : ( (_ id: String?, _ error: String?) ->Void)?){
            let manager = CLLocationManager()
            if(defaults != nil){
                let fence =  getFence(id: id)
                if(fence != nil){
                    for region in manager.monitoredRegions {
                        if(region.identifier.elementsEqual(id)){
                            manager.stopMonitoring(for: region)
                            defaults?.removeObject(forKey: makeKey(id))
                            callback?(id,nil)
                        }
                    }
                }else{
                    callback?(nil, "Fence not found")
                }
            }else{
                callback?(nil, "Unknown error")
            }
        }
        
        @objc public func removeAllFences() -> Void {
            let manager = CLLocationManager()
            if(defaults != nil){
                let storedFences = defaults?.dictionaryRepresentation() ?? [:]
                let keys = storedFences.keys
                for key in keys {
                    if(key.starts(with: FancyGeo.PREFIX)){
                        let fence = storedFences[key] as? String
                        if(fence != nil){
                            for region in manager.monitoredRegions {
                                manager.stopMonitoring(for: region)
                                defaults?.removeObject(forKey: key)
                            }
                        }
                    }
                }
            }
        }
        
        func createNotification(_ manager: CLLocationManager, action: String ,region: CLRegion) {
            if(defaults != nil){
                let fenceJson = getFence(id: region.identifier)
                if(fenceJson != nil){
                    let fence = FancyGeo.getType(json: fenceJson!)
                    switch(fence){
                    case "circle":
                        let circle = CircleFence.fromString(json: fenceJson!)
                        if(circle?.notification != nil){
                            if #available(iOS 10.0, *){
                                let center =  UNUserNotificationCenter.current()
                                var extraInfo: [AnyHashable:Any] = [:]
                                extraInfo[FancyGeo.GEO_TRANSITION_TYPE] = action
                                let notification = circle?.notification
                                let content = UNMutableNotificationContent()
                                content.title = notification!.title
                                content.body = notification!.body
                                content.sound = UNNotificationSound.default()
                                content.userInfo = extraInfo
                                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                                let request = UNNotificationRequest(identifier: String(notification!.id), content: content, trigger: trigger)
                                center.add(request) { (error) in
                                    if(error != nil){
                                        print("Notification Error " + (error?.localizedDescription)!)
                                    }
                                }
                            }else{
                                let notification = circle?.notification
                                var extraInfo: [AnyHashable:Any] = [:]
                                extraInfo["id"] = String(notification!.id)
                                extraInfo[FancyGeo.GEO_TRANSITION_TYPE] = action
                                let legacyNotification = UILocalNotification()
                                legacyNotification.alertTitle = notification!.title
                                legacyNotification.alertBody = notification!.body
                                legacyNotification.soundName =  UILocalNotificationDefaultSoundName
                                legacyNotification.userInfo = extraInfo
                                legacyNotification.fireDate = Date()
                                UIApplication.shared.scheduleLocalNotification(legacyNotification)
                            }
                        }
                        break;
                    default:
                        return
                    }
                }
            }
        }
        
        @available(iOS 10.0, *)
        public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            FancyGeo.handleNotification(center: center, response: response)
            completionHandler()
        }
        
        @available(iOS 10.0, *)
        public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.badge,.sound,.alert])
        }
        
        
        public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
            let requestCallback =  FancyGeo.callbacks[region.identifier]
            if requestCallback != nil{
                requestCallback!(region.identifier,nil)
            }
        }
        
        public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
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
            createNotification(manager, action: "exit", region: region)
        }
        
        public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
            createNotification(manager, action: "enter" , region: region)
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
