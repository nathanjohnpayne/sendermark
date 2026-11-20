import Foundation

@main
struct SendermarkMain {
    static func main() {
        let outcome = CommandLineInterface.run(Array(CommandLine.arguments.dropFirst()))
        if !outcome.standardOutput.isEmpty {
            FileHandle.standardOutput.write(Data(outcome.standardOutput.utf8))
        }
        if !outcome.standardError.isEmpty {
            FileHandle.standardError.write(Data(outcome.standardError.utf8))
        }
        exit(outcome.exitStatus)
    }
}
