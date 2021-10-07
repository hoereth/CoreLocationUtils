import Foundation
import CoreLocation

public class OneTimeLocation : NSObject, CLLocationManagerDelegate {
    public enum LocationError : Error {
        case denied
        case restricted
        case timeout
        case unknown
    }
    
    let manager: CLLocationManager
    let completion: (Result<CLLocation, Error>)->()
    let timeout: TimeInterval

    fileprivate static let instancesQueue = DispatchQueue(label: "OneTimeLocation.instances")
    fileprivate static var instances = Set<OneTimeLocation>()
    
    /// Will either find you the current location or produce an error.
    /// - Parameters:
    ///   - desiredAccuracy: see CLLocationManager.desiredAccuracy
    ///   - timeout: Applies to actual finding a location. Dialogs are presented without timeout.
    public static func queryLocation(desiredAccuracy: CLLocationAccuracy, timeout: TimeInterval, completion: @escaping (Result<CLLocation, Error>)->()) {
        let oneTimeLocation = OneTimeLocation(desiredAccuracy: desiredAccuracy, completion: completion, timeout: timeout)
        oneTimeLocation.manager.delegate = oneTimeLocation
        
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            instancesQueue.sync {
                _ = instances.insert(oneTimeLocation)
                oneTimeLocation.manager.startUpdatingLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    oneTimeLocation.manager.stopUpdatingLocation()
                    if oneTimeLocation.removeInstance() != nil {
                        completion(Result.failure(LocationError.timeout))
                    }
                }
            }
        case .notDetermined:
            instancesQueue.sync {
                _ = instances.insert(oneTimeLocation)
                oneTimeLocation.manager.requestWhenInUseAuthorization()
            }
        case .denied:
            completion(Result.failure(LocationError.denied))
        case .restricted:
            completion(Result.failure(LocationError.restricted))
        @unknown default:
            completion(Result.failure(LocationError.unknown))
        }
    }
    
    @available(iOS 15.0.0, *)
    public static func queryLocation(desiredAccuracy: CLLocationAccuracy, timeout: TimeInterval) async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) -> Void in
            Self.queryLocation(desiredAccuracy: desiredAccuracy, timeout: timeout) { (result) in
                do {
                    continuation.resume(returning: try result.get())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    fileprivate init(desiredAccuracy: CLLocationAccuracy, completion: @escaping (Result<CLLocation, Error>)->(), timeout: TimeInterval) {
        self.manager = CLLocationManager()
        self.manager.desiredAccuracy = desiredAccuracy
        self.completion = completion
        self.timeout = timeout
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (locations.count > 0) {
            self.completion(Result.success(locations[0]))
        } else {
            self.completion(Result.failure(LocationError.unknown))
        }
        self.manager.stopUpdatingLocation()
        _ = self.removeInstance()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.completion(Result.failure(error))
        self.manager.stopUpdatingLocation()
        _ = self.removeInstance()
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            self.manager.startUpdatingLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                self.manager.stopUpdatingLocation()
                if self.removeInstance() != nil {
                    self.completion(Result.failure(LocationError.timeout))
                }
            }
        case .notDetermined:
            break;
        case .denied:
            completion(Result.failure(LocationError.denied))
            _ = self.removeInstance()
        case .restricted:
            completion(Result.failure(LocationError.restricted))
            _ = self.removeInstance()
        @unknown default:
            completion(Result.failure(LocationError.unknown))
            _ = self.removeInstance()
        }
    }
    
    fileprivate func removeInstance() -> OneTimeLocation? {
        Self.instancesQueue.sync {
            OneTimeLocation.instances.remove(self)
        }
    }
}
