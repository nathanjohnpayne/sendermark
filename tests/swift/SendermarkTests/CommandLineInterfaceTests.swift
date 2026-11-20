import Testing
import SendermarkCore
@testable import sendermark

// These tests call the argument handler directly. They do not start the tool,
// open Contacts or read the Messages database.

@Suite("sendermark command line")
struct CommandLineInterfaceTests {
    @Test("--version prints the package version")
    func version() {
        let outcome = CommandLineInterface.run(["--version"])
        #expect(outcome == .init(standardOutput: "sendermark \(Sendermark.version)\n", exitStatus: 0))
    }

    @Test("--help, -h and no arguments print help", arguments: [["--help"], ["-h"], []])
    func help(arguments: [String]) {
        let outcome = CommandLineInterface.run(arguments)
        #expect(outcome.exitStatus == 0)
        #expect(outcome.standardError.isEmpty)
        #expect(outcome.standardOutput == CommandLineInterface.helpText)
        #expect(outcome.standardOutput.contains("USAGE: sendermark [--help] [--version]"))
    }

    @Test("help lists only the options the tool implements, and no commands")
    func helpListsNothingUnimplemented() {
        let help = CommandLineInterface.helpText
        #expect(!help.uppercased().contains("COMMANDS"))

        // Every flag-like word in help must be accepted by the tool.
        let words = help.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "," || $0 == "[" || $0 == "]" })
        let flags = Set(words.filter { $0.hasPrefix("-") }.map(String.init))
        #expect(flags == ["-h", "--help", "--version"])
        for flag in flags {
            #expect(CommandLineInterface.run([flag]).exitStatus == 0, "help lists \(flag) but the tool rejects it")
        }

        // Each OPTIONS line is rendered from the implemented list.
        let optionLines = help.split(separator: "\n").drop(while: { $0 != "OPTIONS:" }).dropFirst()
        #expect(optionLines.count == CommandLineInterface.options.count)
    }

    @Test(
        "commands that are planned but not implemented are rejected",
        arguments: ["scan", "logos", "review", "apply", "undo", "help", "version", "--verbose", "-v"]
    )
    func unimplementedIsRejected(argument: String) {
        let outcome = CommandLineInterface.run([argument])
        #expect(outcome.exitStatus == CommandLineInterface.usageExitStatus)
        #expect(outcome.standardOutput.isEmpty)
        #expect(outcome.standardError.contains("unknown argument '\(argument)'"))
    }

    @Test("more than one argument is a usage error")
    func tooManyArguments() {
        let outcome = CommandLineInterface.run(["--help", "--version"])
        #expect(outcome.exitStatus == CommandLineInterface.usageExitStatus)
        #expect(outcome.standardOutput.isEmpty)
    }
}

@Suite("SendermarkCore")
struct SendermarkCoreTests {
    @Test("the architecture's modules exist as public, empty namespaces")
    func moduleStubsExist() {
        // PRD § Architecture. PhoneLookup is P1 work (#52) and is deliberately absent.
        let modules: [Any.Type] = [
            ContactsStore.self,
            MessagesReader.self,
            LogoClient.self,
            LogoNormalizer.self,
            Attribution.self,
            State.self,
        ]
        #expect(modules.map { String(describing: $0) } == [
            "ContactsStore", "MessagesReader", "LogoClient", "LogoNormalizer", "Attribution", "State",
        ])
    }

    @Test("the version is a semantic version")
    func versionShape() {
        let parts = Sendermark.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
