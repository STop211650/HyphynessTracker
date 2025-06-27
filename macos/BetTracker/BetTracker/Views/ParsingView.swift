import SwiftUI

struct ParsingView: View {
    let message: String
    
    init(message: String = "Analyzing bet screenshot...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
            
            Text("Please wait")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 300, height: 200)
    }
}