import SwiftUI

struct PaymentEntryView: View {
    let onSubmit: (String, String, Double, String?, String?) -> Void
    let onCancel: () -> Void
    
    @State private var fromPerson = ""
    @State private var toPerson = ""
    @State private var amountText = ""
    @State private var paymentMethod = ""
    @State private var note = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case from, to, amount, method, note
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Record Payment")
                .font(.headline)
                .padding(.top)
            
            // Form
            Form {
                Section("Payment Details") {
                    TextField("From (who is paying)", text: $fromPerson)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .from)
                        .onSubmit { focusedField = .to }
                    
                    TextField("To (who is receiving)", text: $toPerson)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .to)
                        .onSubmit { focusedField = .amount }
                    
                    HStack {
                        Text("Amount: $")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amountText)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .amount)
                            .onSubmit { focusedField = .method }
                    }
                }
                
                Section("Additional Information") {
                    TextField("Payment Method (optional)", text: $paymentMethod)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .method)
                        .onSubmit { focusedField = .note }
                    
                    TextField("Note (optional)", text: $note)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .note)
                        .onSubmit { submitPayment() }
                }
            }
            .formStyle(GroupedFormStyle())
            
            // Error message
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Record Payment") {
                    submitPayment()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(fromPerson.isEmpty || toPerson.isEmpty || amountText.isEmpty)
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 480)
        .onAppear {
            // Focus the first text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .from
            }
        }
        .onEscapeKey {
            onCancel()
        }
    }
    
    private func submitPayment() {
        // Validate input
        guard !fromPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorMessage("Please enter who is paying")
            return
        }
        
        guard !toPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorMessage("Please enter who is receiving")
            return
        }
        
        let trimmedFrom = fromPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTo = toPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedFrom.lowercased() != trimmedTo.lowercased() else {
            showErrorMessage("Cannot record payment from someone to themselves")
            return
        }
        
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")),
              amount > 0 else {
            showErrorMessage("Please enter a valid amount greater than 0")
            return
        }
        
        // Submit the payment
        let method = paymentMethod.isEmpty ? nil : paymentMethod
        let paymentNote = note.isEmpty ? nil : note
        
        onSubmit(trimmedFrom, trimmedTo, amount, method, paymentNote)
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // Hide error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
}

// Preview
struct PaymentEntryView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentEntryView(
            onSubmit: { _, _, _, _, _ in },
            onCancel: { }
        )
    }
}