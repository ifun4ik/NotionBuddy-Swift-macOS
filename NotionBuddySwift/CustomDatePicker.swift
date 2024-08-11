import SwiftUI
import Foundation

struct CustomDatePicker: View {
    @Binding var selection: Date
    let disabled: Bool
    @State private var dateText: String = ""
    @State private var recognizedDate: Date?
    
    var body: some View {
        HStack {
            TextField("Enter date", text: $dateText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
                .foregroundColor(.textPrimary)
                .font(.custom("Onest-Regular", size: 16))
                .onChange(of: dateText) { newValue in
                    if let date = detectDate(from: newValue) {
                        recognizedDate = date
                        selection = date
                    } else {
                        recognizedDate = nil
                    }
                }
            
            Spacer()
            
            Image(systemName: "calendar")
                .foregroundColor(.textSecondary)
        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(recognizedDate != nil ? Color.cardStroke : Color.blue, lineWidth: 1)
//        )
        .opacity(disabled ? 0.5 : 1.0)
        .disabled(disabled)
        .onAppear {
            dateText = formatDate(selection)
        }
        .onChange(of: selection) { newDate in
            dateText = formatDate(newDate)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func detectDate(from text: String) -> Date? {
        let lowercasedText = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        switch lowercasedText {
        case "tod", "today":
            return today
        case "tom", "tmr", "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: today)
        case let str where str.starts(with: "next"):
            let components = str.components(separatedBy: " ")
            if components.count == 2, let weekday = getWeekdayFromName(components[1]) {
                return getNextWeekday(weekday)
            }
        default:
            return detectDateUsingDetector(from: text)
        }
        return nil
    }
    
    private func detectDateUsingDetector(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if let match = matches?.first, match.resultType == .date, let date = match.date {
            return date
        }
        return nil
    }
    
    private func getWeekdayFromName(_ name: String) -> Int? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        return weekdays[name.lowercased()]
    }

    private func getNextWeekday(_ weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        let calendar = Calendar.current
        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }
}
