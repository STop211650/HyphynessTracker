import SwiftUI

struct ParsingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing bet screenshot...")
                .font(.headline)
            
            Text("Please wait while we extract bet details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 300, height: 200)
    }
}