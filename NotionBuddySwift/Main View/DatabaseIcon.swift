import Foundation

enum DatabaseIcon: Equatable {
    case emoji(String)
    case url(String)
    case custom(Data)
}

