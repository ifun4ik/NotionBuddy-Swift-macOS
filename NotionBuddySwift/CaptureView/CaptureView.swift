import SwiftUI
import SwiftUIIntrospect
import Combine

struct CaptureView: View {
    
    @FetchRequest(entity: Template.entity(), sortDescriptors: [])
    var templates: FetchedResults<Template>
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var fieldValidationStatus: [String: Bool] = [:]
    @State private var capturedText: String = ""
    @State private var selectedIndex: Int? = nil
    @State private var committedTemplate: Template? = nil
    @State private var activeFieldIndex: Int? = nil
    @State private var filledFields: Set<Int> = []
    @State private var isPlaceholderActive: Bool = true
    @State private var capturedData: [String: String] = [:]
    @State private var attemptedFinish: Bool = false
    @State private var optionsForFields: [String: [String]] = [:]
    @State private var activeOptionIndex: Int = 0
    @State private var selectedMultiOptions: [String] = []
    @State private var multiSelectFilterText: String = ""
    @State private var handledEvents: Set<NSEvent> = []
    
    @State private var recognizedDate: Date? = nil
    @State private var recognizedDateText: String = ""
    @State private var localEventMonitor: Any?

    
    
    var accessToken: String
    
    private var filteredTemplates: [Template] {
        return templates.filter {
            capturedText.isEmpty || $0.name?.lowercased().contains(capturedText.lowercased()) == true
        }
    }
    
    private var displayTemplates: [Template] {
        return Array(filteredTemplates.prefix(5))
    }
    
    private var displayFields: [EditableTemplateFieldViewData] {
        guard let committedTemplate = committedTemplate else { return [] }
        return TemplateViewModel(template: committedTemplate).templateFields.filter { $0.priority != "skip" }
    }
    
    private var textFieldPlaceholder: String {
        guard let index = activeFieldIndex, index < displayFields.count else {
            return "Type something..."
        }

        let field = displayFields[index]
        if filledFields.contains(index), let filledValue = capturedData[field.name], !filledValue.isEmpty {
            return filledValue
        }

        switch field.kind {
        case "date":
            return "Type date in a free format"
        case "number":
            return "Enter a number"
        case "email":
            return "Enter an email address"
        case "checkbox":
            return "Type true or false"
        case "multi_select":
            if let defaultValue = field.defaultValue as? String {
                let parsedArray = parseArrayString(defaultValue)
                return parsedArray.isEmpty ? "Type something..." : parsedArray.joined(separator: ", ")
            }
        default:
            return field.defaultValue as? String ?? "Type something..."
        }
    }
    
    // Additional State for managing sessions and data validation
    @State private var sessionID: UUID = UUID() // Unique identifier for each session

    private func resetCaptureSession() {
        // Reset all relevant states for a new capture session
        self.capturedText = ""
        self.selectedIndex = nil
        self.committedTemplate = nil
        self.fieldValidationStatus = [:]
        self.sessionID = UUID() // Generate a new session ID
    }




    private func parseArrayString(_ arrayString: String) -> [String] {
        // Remove brackets and split by comma
        let trimmedString = arrayString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let elements = trimmedString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Further trimming to remove quotes if needed
        return elements.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }

    
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.iconSecondary)
                
                if let committedTemplate = committedTemplate {
                    HStack(spacing: 4) {
                        Text(committedTemplate.name ?? "")
                            .font(Font.custom("SF Pro Text", size: 16).weight(.medium))
                            .foregroundColor(Constants.textPrimary)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Constants.iconSecondary)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                
                TextField(textFieldPlaceholder, text: $capturedText)
                    .frame(height: 22)
                    .padding(.top, 2)
                    .textFieldStyle(.plain)
                    .font(Font.custom("SF Pro Text", size: 16).weight(.medium))
                    .foregroundColor(getTextFieldColor())
                    .introspect(.textField, on: .macOS(.v10_15, .v11, .v12, .v13, .v14)) { textField in
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            textField.becomeFirstResponder()
                            textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
                            
                            if committedTemplate != nil, let index = activeFieldIndex, index < displayFields.count {
                                isPlaceholderActive = displayFields[index].defaultValue != nil
                            } else if committedTemplate != nil {
                                activeFieldIndex = 0
                                isPlaceholderActive = displayFields.first?.defaultValue != nil
                            }
                            
                            if let placeholderString = textField.placeholderString {
                                let placeholderFont = NSFont(name: "SF Pro Text", size: 16) ?? NSFont.systemFont(ofSize: 16)
                                let placeholderAttributes: [NSAttributedString.Key: Any] = [
                                    .foregroundColor: NSColor(Constants.textSecondary),
                                    .font: placeholderFont
                                ]
                                textField.placeholderAttributedString = NSAttributedString(string: placeholderString, attributes: placeholderAttributes)
                            }
                            
                            textField.toolTip = recognizedDate != nil ? recognizedDateText : nil
                        }
                    }
                    .onChange(of: capturedText) { newValue in
                        handleCapturedTextChange(newValue)
                    }

                    .onAppear {
                        var capturedDataCopy = capturedData
                        capturedDataCopy = [:]
                        setupKeyEventHandling()
                        capturedData = capturedDataCopy
                    }
                    .onDisappear {
                        // If there's an event monitor, remove it to prevent capturing new events.
                        if let localEventMonitor = self.localEventMonitor {
                            NSEvent.removeMonitor(localEventMonitor)
                            self.localEventMonitor = nil
                        }
                    }


            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 1)
                    .stroke(Constants.bgPrimaryStroke, lineWidth: 1)
            )
            
            if let activeField = getActiveField() {
                if ["select", "multi_select", "status"].contains(activeField.kind) {
                    if let options = optionsForFields[activeField.name] {
                        SelectOptionsView(
                            options: options,
                            onOptionSelected: { selectedOptions in
                                handleOptionSelection(activeField: activeField, selectedOptions: selectedOptions)
                            },
                            filterText: $multiSelectFilterText,
                            maxVisibleOptions: 4,
                            activeOptionIndex: $activeOptionIndex,
                            selectedOptions: $selectedMultiOptions,
                            isMultiSelect: activeField.kind == "multi_select"
                        )
                    }
                }
            }

            
            VStack(spacing: 0) {
                if let committedTemplate = committedTemplate {
                    ForEach(Array(displayFields.enumerated()), id: \.element.id) { index, field in
                        HStack(spacing: 16) {
                            iconForField(field: field, index: index)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.name)
                                    .font(Font.custom("Onest", size: 16).weight(.semibold))
                                    .foregroundColor(Constants.textPrimary)
                                
                                Text(field.kind ?? "Unknown")
                                    .font(Font.custom("Onest", size: 14).weight(.medium))
                                    .foregroundColor(Constants.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                        .background(index == activeFieldIndex ? Constants.bgPrimaryHover : Color.clear)
                        .onTapGesture {
                            activeFieldIndex = index
                        }
                    }
                } else if displayTemplates.isEmpty {
                    Text("Nothing found")
                        .font(Font.custom("Manrope", size: 16).weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                } else {
                    ForEach(Array(displayTemplates.enumerated()), id: \.element) { index, template in
                        TemplateRowView(template: template, index: index, enableHover: false, enableEdit: false,
                                        enableDelete: false){
                            
                        }
//                        HStack {
//                            Text(template.name ?? "No template name")
//                                .font(Font.custom("Onest", size: 16).weight(.semibold))
//                                .foregroundColor(Constants.textPrimary)
//                        }
//                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                        .background(index == selectedIndex ? Constants.bgPrimaryHover : Color.clear)
                        .onTapGesture {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 1)
                    .stroke(Constants.bgPrimaryStroke, lineWidth: 1)
            )
        }
        
    }
    
    private func handleOptionSelection(activeField: EditableTemplateFieldViewData, selectedOptions: [String]) {
        if activeField.kind == "multi_select" {
            selectedMultiOptions = selectedOptions
            capturedData[activeField.name] = selectedOptions.joined(separator: ", ")
        }
    }
    
    private func getTextFieldColor() -> Color {
        if let activeField = getActiveField(), activeField.kind == "date", recognizedDate != nil {
            return Constants.colorPrimary
        } else {
            return Constants.textPrimary
        }
    }

    
    
    //MARK: Select view
    struct SelectOptionsView: View {
      var options: [String]
      let onOptionSelected: ([String]) -> Void
      @Binding var filterText: String
      let maxVisibleOptions: Int
      @Binding var activeOptionIndex: Int
      @Binding var selectedOptions: [String]
      let isMultiSelect: Bool

      private var filteredOptions: [String] {
        options.filter { option in
          filterText.isEmpty || option.lowercased().contains(filterText.lowercased())
        }
      }

      private let optionHeight: CGFloat = 44

      var body: some View {
        VStack(alignment: .leading) {
          ScrollViewReader { scrollViewProxy in
            ScrollView {
              LazyVStack(alignment: .leading) {
                ForEach(Array(filteredOptions.enumerated()), id: \.element) { index, option in
                  HStack {
                    if isMultiSelect {
                      if selectedOptions.contains(option) {
                        Image(systemName: "checkmark.square.fill")
                          .foregroundColor(Constants.colorPrimary)
                      } else {
                        Image(systemName: "square")
                          .foregroundColor(Constants.textSecondary)
                      }
                    }
                    Text(option)
                      .font(Font.custom("Onest", size: 16).weight(.semibold))
                      .foregroundColor(Constants.textPrimary)
                      .id(index)
                  }
                  .padding(.horizontal, 16)
                  .frame(maxWidth: .infinity, minHeight: optionHeight, maxHeight: optionHeight, alignment: .leading)
                  .background(index == activeOptionIndex ? Constants.bgPrimaryHover : Color.clear)
                  .onTapGesture {
                    toggleOptionSelection(option)
                  }
                }
              }
            }
            .onChange(of: activeOptionIndex) { newIndex in
                DispatchQueue.main.async {
                    withAnimation {
                        scrollViewProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
          .frame(minHeight: CGFloat(min(filteredOptions.count, maxVisibleOptions)) * optionHeight)
        }
        .background(Constants.bgPrimary)
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .inset(by: 1)
            .stroke(Constants.bgPrimaryStroke, lineWidth: 1)
        )
      }

      private func toggleOptionSelection(_ option: String) {
        if isMultiSelect {
          if selectedOptions.contains(option) {
            selectedOptions.removeAll(where: { $0 == option })
          } else {
            selectedOptions.append(option)
          }
          onOptionSelected(selectedOptions) // For multi-select, pass the entire array
        } else {
          // For single select, clear the existing selection and add the new one
          selectedOptions = [option]
          onOptionSelected([option]) // Pass an array with the single selected item
        }
      }
    }



    
    // Helper function to get the currently active field
    func getActiveField() -> EditableTemplateFieldViewData? {
        guard let activeFieldIndex = activeFieldIndex, displayFields.indices.contains(activeFieldIndex) else { return nil }
        let activeField = displayFields[activeFieldIndex]

        // Include "multi_select" and "status" in the check
        if ["select", "multi_select", "status"].contains(activeField.kind),
           let options = activeField.options, !options.isEmpty {
        }

        return activeField
    }

    
    
    func fetchOptionsForFields(from databaseId: String) {
        guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)") else {
            print("Invalid URL for database ID: \(databaseId)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("2021-05-13", forHTTPHeaderField: "Notion-Version")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching options: \(error)")
                return
            }

            guard let data = data else {
                print("No data received for options")
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let properties = jsonResponse["properties"] as? [String: Any] {
                        DispatchQueue.main.async {
                            self.extractOptionsFromProperties(properties)
                        }
                    }
                }
            } catch {
                print("Error parsing options: \(error)")
            }
        }.resume()
    }



    // Extract options for 'select', 'multi_select', and 'status' fields
    func extractOptionsFromProperties(_ properties: [String: Any]) {
        var allOptions: [String: [String]] = [:]

        for (key, value) in properties {
            if let propertyDict = value as? [String: Any],
               let fieldType = propertyDict["type"] as? String,
               fieldType == "select" || fieldType == "multi_select" || fieldType == "status",
               let selectDict = propertyDict[fieldType] as? [String: Any],
               let options = selectDict["options"] as? [[String: Any]] {
                allOptions[key] = options.compactMap { $0["name"] as? String }
            }
        }

        DispatchQueue.main.async {
            self.optionsForFields = allOptions
        }
    }

    
    
    private func prepareForCapture() {
        capturedData = [:]
        setupKeyEventHandling()
    }
    
    private func setupKeyEventHandling() {
        // If there's an existing key event monitor, deregister it first
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        
        // Add a new local monitor
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if !self.handledEvents.contains(event) {
                self.handledEvents.insert(event)
                self.handleKeyEvent(event)
                self.handledEvents.remove(event)
            }
            return event
        }
    }



    private func handleKeyEvent(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 36 {
            print("Cmd+Enter")
            cmdEnterPressed()
            return
        }

        if let committedTemplate = committedTemplate, let activeFieldIndex = activeFieldIndex {
            switch event.keyCode {
            case 36:  // Enter/Return key
                captureCurrentFieldData()

                if let activeField = getActiveField(), activeField.kind == "multi_select" {
                    let selectedOption = optionsForFields[activeField.name]?[safe: activeOptionIndex] ?? ""
                    toggleMultiSelectOption(selectedOption)
                } else {
                    moveToNextFieldOrFinish()
                }
            case 48:  // Tab key
                if shouldCaptureData() {
                    captureCurrentFieldData()  // Capture data when there's input
                }
                if event.modifierFlags.contains(.shift) {
                    switchToPreviousField()
                } else {
                    switchToNextField()
                }
            default:
                if let activeField = getActiveField() {
                    handleArrowKeyEvents(event, for: activeField)
                }
            }
        } else {
            handleTemplateSelection(event: event)
        }
    }
    
    private func shouldCaptureData() -> Bool {
        guard let activeFieldIndex = activeFieldIndex,
              displayFields.indices.contains(activeFieldIndex) else { return false }

        let activeField = displayFields[activeFieldIndex]

        switch activeField.kind {
        case "multi_select":
            return !selectedMultiOptions.isEmpty
        case "select", "status":
            return !capturedText.isEmpty
        default:
            return !(capturedData[activeField.name]?.isEmpty ?? true)
        }
    }


    private func handleArrowKeyEvents(_ event: NSEvent, for activeField: EditableTemplateFieldViewData) {
        switch activeField.kind {
        case "select", "status":
            handleSelectFieldKeyEvent(keyCode: event.keyCode, for: activeField)
        case "multi_select":
            handleMultiSelectFieldKeyEvent(keyCode: event.keyCode)
        default:
            break
        }
    }

    
    private func handleSelectFieldKeyEvent(keyCode: UInt16, for activeField: EditableTemplateFieldViewData) {
        guard let options = optionsForFields[activeField.name] else { return }

        switch keyCode {
        case 125: // Down arrow key
            activeOptionIndex = (activeOptionIndex + 1) % options.count
            capturedText = options[safe: activeOptionIndex] ?? ""
        case 126: // Up arrow key
            activeOptionIndex = activeOptionIndex == 0 ? options.count - 1 : activeOptionIndex - 1
            capturedText = options[safe: activeOptionIndex] ?? ""
        default:
            break
        }

        capturedData[activeField.name] = capturedText
    }



    
    private func handleMultiSelectFieldKeyEvent(keyCode: UInt16) {
        guard let activeField = getActiveField(), let options = optionsForFields[activeField.name] else { return }

        switch keyCode {
        case 125: // Down arrow key
            activeOptionIndex = (activeOptionIndex + 1) % options.count
        case 126: // Up arrow key
            activeOptionIndex = activeOptionIndex == 0 ? options.count - 1 : activeOptionIndex - 1
        default:
            break
        }

        updateCapturedTextForMultiSelect()
    }



    private func toggleMultiSelectOption(_ option: String) {
        if let index = selectedMultiOptions.firstIndex(of: option) {
            selectedMultiOptions.remove(at: index)
        } else {
            selectedMultiOptions.append(option)
        }
        updateCapturedTextForMultiSelect()
    }


    private func updateCapturedDataForField() {
        guard let activeField = getActiveField() else { return }

        switch activeField.kind {
        case "multi_select":
            capturedData[activeField.name] = selectedMultiOptions.joined(separator: ",")
        case "select", "status":
            capturedData[activeField.name] = capturedText
        default:
            capturedData[activeField.name] = capturedText.isEmpty ? (activeField.defaultValue ?? "") : capturedText
        }
    }

    private func updateCapturedTextForMultiSelect() {
        capturedText = selectedMultiOptions.joined(separator: ", ")
    }


    private func handleSelectFieldArrowKeyEvent(_ event: NSEvent) {
        if let activeField = getActiveField(), ["select", "multi_select", "status"].contains(activeField.kind), let options = optionsForFields[activeField.name] {
            switch event.keyCode {
            case 125:  // Down arrow key
                activeOptionIndex = (activeOptionIndex + 1) % options.count
            case 126:  // Up arrow key
                activeOptionIndex = (activeOptionIndex - 1 + options.count) % options.count
            default:
                break
            }
        }
    }


    private func switchToNextField() {
        guard let index = activeFieldIndex, displayFields.indices.contains(index) else { return }

        let currentField = displayFields[index]
        if currentField.priority == "mandatory" && (capturedData[currentField.name]?.isEmpty ?? true) {
            // If current field is mandatory and empty, don't move to next field
            attemptedFinish = true
        } else {
            activeFieldIndex = index < displayFields.count - 1 ? index + 1 : 0
            updatePlaceholder()  // Call a function to update the placeholder
        }
        
        updateMultiSelectOnFieldChange(newIndex: index + 1)
    }
    
    private func updatePlaceholder() {
        if let index = activeFieldIndex, index < displayFields.count {
            let field = displayFields[index]
            if field.kind == "multi_select" {
                if let defaultValue = field.defaultValue as? String {
                    let parsedArray = parseArrayString(defaultValue)
                    capturedText = parsedArray.isEmpty ? "" : parsedArray.joined(separator: ", ")
                }
            } else {
                capturedText = field.defaultValue as? String ?? ""
            }
            isPlaceholderActive = true  // Reset the placeholder active status
        }
    }



    private func switchToPreviousField() {
        if let currentIndex = activeFieldIndex, currentIndex > 0 {
            // Decrement the index to move to the previous field
            activeFieldIndex = currentIndex - 1
            // Update multi-select options for the new active field
            updateMultiSelectOnFieldChange(newIndex: activeFieldIndex!)
        } else {
            // Loop to the last field if at the first field
            activeFieldIndex = displayFields.count - 1
            updateMultiSelectOnFieldChange(newIndex: activeFieldIndex!)
        }
    }

    
    private func updateMultiSelectOnFieldChange(newIndex: Int) {
        guard newIndex < displayFields.count else { return }

        let newField = displayFields[newIndex]

        if newField.kind == "multi_select" {
            // If switching to a multi-select field, update the selection based on capturedData
            selectedMultiOptions = parseArrayString(capturedData[newField.name] ?? "")
            updateCapturedTextForMultiSelect()
        } else {
            // If switching to a non-multi-select field, clear the selection
            selectedMultiOptions = []
            capturedText = capturedData[newField.name] ?? ""
        }
    }



    private func captureCurrentFieldData() {
        guard let activeField = getActiveField() else { return }

        switch activeField.kind {
        case "multi_select":
            capturedData[activeField.name] = selectedMultiOptions.joined(separator: ",")
        case "select", "status":
            capturedData[activeField.name] = capturedText
        case "date":
            // Use the recognized date text if available, otherwise use the raw input
            let dateText = recognizedDate != nil ? recognizedDateText : capturedText
            capturedData[activeField.name] = dateText
        case "checkbox":
                capturedData[activeField.name] = capturedText.lowercased() == "true" ? "true" : "false"
        default:
            capturedData[activeField.name] = capturedText.isEmpty ? (activeField.defaultValue ?? "") : capturedText
        }
        filledFields.insert(activeFieldIndex ?? -1)
    }



    private func moveToNextFieldOrFinish() {
        // Check if activeFieldIndex is valid before proceeding
        guard let activeFieldIndex = activeFieldIndex, displayFields.indices.contains(activeFieldIndex) else { return }

        if activeFieldIndex == displayFields.count - 1 {
            if validateRequiredFields() {
                finishCapture()
            } else {
                highlightUnfilledRequiredFields()
                // Notify user to fill mandatory fields
            }
        } else {
            self.activeFieldIndex! += 1
            capturedText = ""
        }
    }

    private func handleTemplateSelection(event: NSEvent) {
        switch event.keyCode {
        case 125:  // Down arrow key
            if let currentIndex = selectedIndex, currentIndex < displayTemplates.count - 1 {
                selectedIndex = currentIndex + 1
            } else {
                selectedIndex = 0
            }
        case 126:  // Up arrow key
            if let currentIndex = selectedIndex, currentIndex > 0 {
                selectedIndex = currentIndex - 1
            } else {
                selectedIndex = displayTemplates.count - 1
            }
        case 36:  // Enter/Return key
            if let index = selectedIndex {
                commitTemplate(displayTemplates[index])
            }
        default:
            break
        }
    }

    private func cmdEnterPressed() {
        // Capture data for the current field
        captureCurrentFieldData()

        // Validate all fields, especially the mandatory ones
        if validateRequiredFields() {
            // If validation passes, capture all field data and finish capture
            captureAllFieldData()
            finishCapture()
        } else {
            // If validation fails, set attemptedFinish to true to indicate a failed attempt
            attemptedFinish = true
            highlightUnfilledRequiredFields() // Highlight unfilled mandatory fields
        }
    }


    private func captureAllFieldData() {
        for (index, field) in displayFields.enumerated() {
            let fieldValue = (capturedData[field.name] ?? field.defaultValue ?? "")
            
            capturedData[field.name] = fieldValue
            filledFields.insert(index)
        }
    }

    private func validateRequiredFields() -> Bool {
        for field in displayFields where field.priority == "mandatory" {
            if (capturedData[field.name] ?? "").isEmpty {
                return false
            }
        }
        return true
    }

    private func highlightUnfilledRequiredFields() {
        for (index, field) in displayFields.enumerated() {
            if field.priority == "mandatory" && (capturedData[field.name] ?? "").isEmpty {
                filledFields.remove(index)
                // Additional logic to visually highlight the field
            }
        }
    }
    
    private func constructProperties(from capturedData: [String: String]) -> [String: Any] {
        var properties: [String: Any] = [:]

        for fieldData in displayFields {
            let fieldName = fieldData.name
            let fieldValue = capturedData[fieldName] ?? ""
            
            print("Field Name: \(fieldName), Field Kind: \(fieldData.kind ?? "unknown"), Field Value: \(fieldValue)")
            
            // Skip the field if the value is empty
            if fieldValue.isEmpty {
                continue
            }

            switch fieldData.kind {
            case "title":
                properties[fieldName] = ["title": [["text": ["content": fieldValue]]]]
            case "rich_text", "text":
                properties[fieldName] = ["rich_text": [["text": ["content": fieldValue]]]]
            case "number":
                if let number = Double(fieldValue) {
                    properties[fieldName] = ["number": number]
                } else {
                    print("Failed to convert \(fieldValue) to a number for field \(fieldName)")
                }
            case "url":
                properties[fieldName] = ["url": fieldValue]
            case "email":
                properties[fieldName] = ["email": fieldValue]
            case "date":
                if isValidDate(fieldValue) {
                    properties[fieldName] = ["date": ["start": fieldValue, "end": nil]]
                }
            case "checkbox":
                properties[fieldName] = ["checkbox": fieldValue.lowercased() == "true"]
            case "select":
                properties[fieldName] = ["select": ["name": fieldValue]]
            case "status":
                properties[fieldName] = ["status": ["name": fieldValue]]
            case "multi_select":
                let options = fieldValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                properties[fieldName] = ["multi_select": options.map { ["name": $0] }]
            default:
                print("Unhandled field type: \(fieldData.kind ?? "unknown") for field: \(fieldName)")
            }
        }
        
        print("Final properties being sent: \(properties)")
        
        return properties
    }

    
    func sendCapturedDataToDatabase(databaseId: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://api.notion.com/v1/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("2021-08-16", forHTTPHeaderField: "Notion-Version")

        let properties = constructProperties(from: capturedData)
        let body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": properties
        ]

        print("Raw captured data: \(capturedData)")
        print("Constructed body: \(body)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error serializing body: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response from Notion API: \(responseString)")
                }
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    print("Data sent successfully")
                    self.clearCapturedData()
                    completion(true)
                } else {
                    print("Error: Unexpected response")
                    completion(false)
                }
            }
        }.resume()
    }

    private func clearCapturedData() {
        capturedData = [:]
        committedTemplate = nil
        capturedText = ""
        activeFieldIndex = nil
        filledFields = []
        // Reset any other relevant state variables
    }

    private func finishCapture() {
        if validateRequiredFields() {
            if let databaseId = committedTemplate?.databaseId {
                sendCapturedDataToDatabase(databaseId: databaseId) { success in
                    if success {
                        print("Capture completed and data sent successfully")
                        // Optionally, update UI or perform any post-capture actions
                    } else {
                        print("Failed to send data to Notion")
                        // Handle the error, perhaps by showing an alert to the user
                    }
                }
            } else {
                print("Error: Database ID not found.")
            }
        } else {
            attemptedFinish = true
            highlightUnfilledRequiredFields()
            // Notify user to fill mandatory fields
        }
    }

    

    func commitTemplate(_ template: Template) {
        committedTemplate = template
        activeFieldIndex = 0
        capturedText = ""
        selectedIndex = nil
        filledFields = []
        capturedData = [:] // Reset captured data for the new template
        fetchOptionsForFields(from: template.databaseId!)
        
        // Call fetchOptionsForSelectField here
        if let databaseId = template.databaseId {
            fetchOptionsForFields(from: databaseId)
        }
    }


    private func handleCommit(_ selectedTemplate: Template) {
        committedTemplate = selectedTemplate
        capturedText = ""
        selectedIndex = templates.firstIndex(of: selectedTemplate)
        NotificationCenter.default.post(name: NSNotification.Name("CloseCaptureWindow"), object: nil)
    }
    
    private func detectDateUsingDetector(from text: String) -> Date? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Try parsing the date with the current year first
        let testDateString = "\(text) \(currentYear)"
        if let testDate = parseDate(testDateString), calendar.isDateInFuture(testDate) {
            return testDate
        }

        // If the test date is not in the future, parse it with the next year
        let nextYearDateString = "\(text) \(currentYear + 1)"
        return parseDate(nextYearDateString)
    }

    // Function to parse a date string
    private func parseDate(_ dateString: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: dateString, options: [], range: NSRange(location: 0, length: dateString.utf16.count))

        if let match = matches?.first, match.resultType == .date, let date = match.date {
            return date
        }
        return nil
    }

    private func appropriateYearForMonth(text: String) -> Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        let currentDay = calendar.component(.day, from: Date())
        
        let monthIndex = monthIndexFromText(text)
        let day = dayOfMonthFromText(text) ?? 32 // Use a day that will never match the current day

        // If the date (month and day) has already occurred this year, use the next year
        if monthIndex < currentMonth || (monthIndex == currentMonth && day <= currentDay) {
            return currentYear + 1
        } else {
            // Otherwise, use the current year
            return currentYear
        }
    }

    // Function to get the index of a month from a text
    private func monthIndexFromText(_ text: String) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        guard let months = dateFormatter.shortMonthSymbols else { return 0 }

        let lowercasedText = text.lowercased()
        for (index, month) in months.enumerated() {
            if lowercasedText.contains(month.lowercased()) {
                return index + 1 // month indices start at 1
            }
        }
        return 0 // Return 0 if no month is found
    }

    // Function to get the day of the month from text
    private func dayOfMonthFromText(_ text: String) -> Int? {
        let words = text.split { !$0.isNumber }
        if let dayString = words.first, let day = Int(dayString) {
            return day
        }
        return nil
    }
    
    private func textContainsYear(_ text: String) -> Bool {
        // Regex pattern to find a year in the text (e.g., "2024", "24")
        let yearPattern = "\\b\\d{2,4}\\b"
        return text.range(of: yearPattern, options: .regularExpression) != nil
    }

    // Check for relative date phrases
    private func handleRelativeDatePhrases(_ text: String) -> Date? {
        let lowercasedText = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        switch lowercasedText {
        case "today":
            return today
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: today)
        case let str where str.starts(with: "next"):
            let components = str.components(separatedBy: " ")
            if components.count == 2, let weekday = getWeekdayFromName(components[1]) {
                return getNextWeekday(weekday)
            }
        default:
            break
        }

        return nil
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
       // ... other cases for 'yesterday', 'next', etc.
       default:
           return detectDateUsingDetector(from: text)
       }
   }

    // Get weekday from name
    private func getWeekdayFromName(_ name: String) -> Int? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        return weekdays[name.lowercased()]
    }

    // Get next occurrence of a weekday
    private func getNextWeekday(_ weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        let nextWeekday = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
        return nextWeekday
    }

    // Check if the input text is likely a complete date
    private func isLikelyCompleteDate(_ text: String) -> Bool {
        // Patterns covering various date formats
        let patterns = [
            "\\d{2}/\\d{2}/\\d{2,4}", "\\d{2}-\\d{2}-\\d{2,4}", "\\d{2}, [A-Za-z]+ \\d{2,4}",
            "[A-Za-z]+ \\d{2}, \\d{2,4}", "\\d{2} [A-Za-z]{3}, \\d{2,4}", "[A-Za-z]{3} \\d{2}, \\d{2,4}",
            "\\d{4}/\\d{2}/\\d{2}", "\\d{4}-\\d{2}-\\d{2}", "\\d{4}, [A-Za-z]+ \\d{2}",
            "\\d{2}/\\d{2}/\\d{2}", "\\d{2}-\\d{2}-\\d{2}", "\\d{2}, [A-Za-z]+ \\d{2}",
            "[A-Za-z]+ \\d{2}, \\d{2}", "\\d{2} [A-Za-z]{3}, \\d{2}", "[A-Za-z]{3} \\d{2}, \\d{2}"
        ]

        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    
    private func handleCapturedTextChange(_ newValue: String) {
        if let activeField = getActiveField() {
            switch activeField.kind {
            case "date":
                recognizedDate = detectDate(from: newValue)
                if let date = recognizedDate {
                    recognizedDateText = notionAPICompatibleDateString(from: date)
                } else {
                    recognizedDateText = ""
                }
            case "number":
                // Only allow numeric input
                let numericValue = newValue.filter { $0.isNumber || $0 == "." }
                capturedData[activeField.name] = numericValue
            case "email":
                // Store the email regardless of validation
                capturedData[activeField.name] = newValue
            case "url":
                // Store the URL regardless of validation
                capturedData[activeField.name] = newValue
            case "multi_select":
                let inputOptions = newValue.components(separatedBy: ", ").filter { !$0.isEmpty }
                selectedMultiOptions = inputOptions
            case "select", "status":
                capturedData[activeField.name] = newValue
            default:
                // For text and other types, store as is
                capturedData[activeField.name] = newValue
            }
        }
    }

    // Email validation function
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }

    
    private func formatAsDate(_ input: String) -> String {
        var cleanedInput = input.filter { "0123456789".contains($0) }
        if cleanedInput.count > 8 { cleanedInput = String(cleanedInput.prefix(8)) }

        var formattedDate = ""
        for (index, char) in cleanedInput.enumerated() {
            if index == 2 || index == 4 {
                formattedDate.append(" / ")
            }
            formattedDate.append(char)
        }

        // Fill with placeholder if needed
        let placeholders = ["MM", "DD", "YYYY"]
        let components = formattedDate.split(separator: "/").map(String.init)
        for i in components.count..<3 {
            if !formattedDate.isEmpty { formattedDate.append("/") }
            formattedDate.append(placeholders[i])
        }

        return formattedDate
    }


    private func notionAPICompatibleDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        // Notion API uses ISO 8601 format for dates
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // Update the isValidDate function to use the DateFormatter
    func isValidDate(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) != nil
    }


    private func iconForField(field: EditableTemplateFieldViewData, index: Int) -> some View {
        let iconName: String
        let iconColor: Color
        let isFieldValid = fieldValidationStatus[field.name] ?? true // Assume valid if not explicitly invalid

        if !isFieldValid {
            iconName = "exclamationmark.triangle"
            iconColor = Color.red
        } else if filledFields.contains(index) || !(capturedData[field.name] ?? "").isEmpty {
            iconName = "checkmark.square"
            iconColor = Constants.iconSecondary
        } else if field.priority == "mandatory" {
            iconName = "square"
            iconColor = Color.orange
        } else {
            iconName = "square"
            iconColor = Constants.iconSecondary
        }

        return Image(systemName: iconName)
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundColor(iconColor)
    }


}
    
    
    struct Constants {
        static let bgPrimary: Color = .white
        static let bgPrimaryStroke: Color = Color(red: 0.91, green: 0.91, blue: 0.91)
        static let iconSecondary: Color = Color(red: 0.62, green: 0.62, blue: 0.65)
        static let textPrimary: Color = Color(red: 0.27, green: 0.29, blue: 0.38)
        static let textSecondary: Color = Color(red: 0.43, green: 0.42, blue: 0.44)
        static let bgPrimaryHover: Color = Color(red: 0.95, green: 0.95, blue: 0.95)
        static let colorPrimary: Color = Color(red: 0.42, green: 0.50, blue: 1.00)
    }


extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Calendar {
    func isDateInFuture(_ date: Date) -> Bool {
        return date > Date()
    }
}
