import Foundation
import CoreLocation

public class OneTimeLocation : NSObject, CLLocationManagerDelegate {
    public enum LocationError : Error {
        case denied
        case restricted
        case unknown
    }
    
    let manager: CLLocationManager
    let completion: (Result<CLLocation, Error>)->()

    fileprivate static let instancesQueue = DispatchQueue(label: "OneTimeLocation.instances")
    fileprivate static var instances = Set<OneTimeLocation>()
    
    public static func queryLocation(desiredAccuracy: CLLocationAccuracy, timeout: TimeInterval, completion: @escaping (Result<CLLocation, Error>)->()) {
        let oneTimeLocation = OneTimeLocation(desiredAccuracy: desiredAccuracy, completion: completion)
        oneTimeLocation.manager.delegate = oneTimeLocation
        
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            instancesQueue.sync {
                oneTimeLocation.manager.startUpdatingLocation()
                _ = instances.insert(oneTimeLocation)
            }
        case .notDetermined:
            instancesQueue.sync {
                oneTimeLocation.manager.requestWhenInUseAuthorization()
                _ = instances.insert(oneTimeLocation)
            }
        case .denied:
            completion(Result.failure(LocationError.denied))
        case .restricted:
            completion(Result.failure(LocationError.restricted))
        @unknown default:
            completion(Result.failure(LocationError.unknown))
        }
    }
    
    fileprivate init(desiredAccuracy: CLLocationAccuracy, completion: @escaping (Result<CLLocation, Error>)->()) {
        self.manager = CLLocationManager()
        self.manager.desiredAccuracy = desiredAccuracy
        self.completion = completion
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (locations.count > 0) {
            self.completion(Result.success(locations[0]))
        } else {
            self.completion(Result.failure(LocationError.unknown))
        }
        self.manager.stopUpdatingLocation()
        Self.instancesQueue.sync {
            _ = OneTimeLocation.instances.remove(self)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.completion(Result.failure(error))
        self.manager.stopUpdatingLocation()
        Self.instancesQueue.sync {
            _ = OneTimeLocation.instances.remove(self)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            self.manager.startUpdatingLocation()
        case .notDetermined:
            break;
        case .denied:
            completion(Result.failure(LocationError.denied))
            Self.instancesQueue.sync {
                _ = OneTimeLocation.instances.remove(self)
            }
        case .restricted:
            completion(Result.failure(LocationError.restricted))
            Self.instancesQueue.sync {
                _ = OneTimeLocation.instances.remove(self)
            }
        @unknown default:
            completion(Result.failure(LocationError.unknown))
            Self.instancesQueue.sync {
                _ = OneTimeLocation.instances.remove(self)
            }
        }
    }
}
