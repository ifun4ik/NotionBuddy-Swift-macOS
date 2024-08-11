import Foundation

class StringArrayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        print("1")
        return NSData.self
    }

    override class func allowsReverseTransformation() -> Bool {
        print("2")
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let stringArray = value as? [String] else { return nil }
        do {
            print("3")
            return try NSKeyedArchiver.archivedData(withRootObject: stringArray, requiringSecureCoding: false)
        } catch {
            print("Failed to transform string array: \(error)")
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            print("4")
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String]
        } catch {
            print("Failed to reverse transform string array: \(error)")
            return nil
        }
    }
    
    static func register() {
        print("5")
        let transformer = StringArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: NSValueTransformerName("StringArrayTransformer"))
    }
}
