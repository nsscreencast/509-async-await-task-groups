import SwiftUI

struct MagicNumberService {
    
    struct InvalidMultiple: Error {}
    
    static func next() async throws -> Int {
        await Task.sleep(UInt64(Float(NSEC_PER_SEC) * (Float.random(in: 0.5...1.0))))
        let num = Int.random(in: 0...100)
        guard !num.isMultiple(of: 3) else { throw InvalidMultiple() }
        return num
    }
}

@MainActor
final class ViewModel: ObservableObject {
    @Published
    var output: [String] = []
    
    @Published
    var running = false
    
    private func num(_ label: String) async throws -> Int {
        outputMessage("Requesting \(label)...")
        let num = try await MagicNumberService.next()
        outputMessage("\(label) is \(num)")
        return num
    }
    
    func run() async {
        running = true
        outputMessage("Running...")
        
        let count = 5
        var numbers: [Int] = []
        
        do {
            try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 1...count {
                    group.addTask {
                        try await self.num("index: \(i)")
                    }
                }
                
                for try await n in group {
                    numbers.append(n)
                }
            }
            
            let sum = numbers.reduce(0, +)
            outputMessage("Sum is \(sum)")
            
        } catch {
            outputMessage("Ooops, got an error!")
        }
        
        
        running = false
    }
    
    private var lock = NSLock()
    private func outputMessage(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        output.append(string)
    }
}


struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(viewModel.output, id: \.self) { string in
                    Text(string)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.headline.monospaced())
        .padding(.vertical, 40)
        .padding(.horizontal, 10)
        .background(Color(white: 0.1).edgesIgnoringSafeArea(.all))
        .overlay(
            ZStack(alignment: .topTrailing) {
                Color.clear
                ProgressView()
                        .progressViewStyle(.circular)
                        .colorScheme(.dark)
                        .opacity(viewModel.running ? 1 : 0)
            }.padding()
        )
        .task {
            await viewModel.run()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
