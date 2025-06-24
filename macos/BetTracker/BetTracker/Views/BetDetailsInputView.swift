import SwiftUI

struct BetDetailsInputView: View {
    let screenshotPath: String
    let onContinue: (String) -> Void
    let onCancel: () -> Void
    
    @State private var participantsText = ""
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Who's in on this bet?")
                .font(.title2)
                .bold()
            
            // Instructions
            Text("Enter participants and their stakes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Text input area
            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Sam, Alex, Jordan split equally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Sam 50, Alex 30, Jordan 20")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Sam: $50, Alex: $30, Jordan: $20")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
                
                TextField("Enter participants...", text: $participantsText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .disabled(isProcessing)
                    .onSubmit {
                        handleContinue()
                    }
            }
            .padding(.horizontal)
            
            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                .disabled(isProcessing)
                
                Button("Continue") {
                    handleContinue()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(participantsText.isEmpty || isProcessing)
            }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            // Focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func handleContinue() {
        // Basic validation
        let trimmed = participantsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "Please enter participant information"
            return
        }
        
        // Parse to check for basic errors
        let parseResult = ParticipantParser.parse(trimmed)
        if !parseResult.errors.isEmpty && parseResult.participants.isEmpty {
            errorMessage = parseResult.errors.first ?? "Invalid participant format"
            return
        }
        
        isProcessing = true
        errorMessage = ""
        onContinue(trimmed)
    }
}