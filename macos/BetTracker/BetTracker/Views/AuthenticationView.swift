import SwiftUI

struct AuthenticationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isShowingPassword = false
    @State private var isSuccess = false
    
    let onAuthenticated: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Sign In to BetTracker")
                .font(.title2)
                .bold()
            
            // Status messages
            if isSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Successfully signed in!")
                        .foregroundColor(.green)
                }
                .font(.caption)
                .padding(.horizontal)
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            // Form fields
            VStack(spacing: 16) {
                // Email field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                        .disabled(isLoading)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        if isShowingPassword {
                            TextField("Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isLoading)
                        } else {
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isLoading)
                        }
                        Button(action: { isShowingPassword.toggle() }) {
                            Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
            }
            .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)
                .disabled(isLoading)
                
                Button("Sign In") {
                    signIn()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .frame(width: 350, height: 320)
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let authToken = try await AuthenticationManager.shared.signIn(email: email, password: password)
                await MainActor.run {
                    isSuccess = true
                    isLoading = false
                    // Delay slightly to show success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onAuthenticated(authToken)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// Preview provider
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView(
            onAuthenticated: { _ in print("Authenticated") },
            onDismiss: { print("Dismissed") }
        )
    }
}