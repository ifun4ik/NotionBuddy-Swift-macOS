import Foundation
import CoreData

extension NSManagedObject {
    @objc class func dataFromTransformable(_ transformable: Any?) -> Data? {
        guard let transformable = transformable else { return nil }
        
        if let data = transformable as? Data {
            return data
        } else if let array = transformable as? [String] {
            return try? NSKeyedArchiver.archivedData(withRootObject: array, requiringSecureCoding: false)
        } else {
            print("Unexpected type for options: \(type(of: transformable))")
            return nil
        }
    }
}
