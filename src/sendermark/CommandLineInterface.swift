import SendermarkCore

/// Argument handling for the `sendermark` tool.
///
/// The tool has no commands yet. It answers `--help` and `--version` and rejects
/// everything else, so that help never lists a command that is not implemented.
/// Each command is added by its own issue, together with its help entry.
enum CommandLineInterface {
    /// The outcome of one invocation: what to print, and the exit status.
    struct Outcome: Equatable {
        var standardOutput: String = ""
        var standardError: String = ""
        var exitStatus: Int32
    }

    /// `EX_USAGE` from sysexits(3): the command was used incorrectly.
    static let usageExitStatus: Int32 = 64

    /// Every option the tool accepts. Help is rendered from this list, so an
    /// option appears in help only if `run` handles it.
    static let options: [(flags: [String], summary: String)] = [
        (["-h", "--help"], "Show this help and exit."),
        (["--version"], "Show the version and exit."),
    ]

    static var helpText: String {
        var lines = [
            "OVERVIEW: Sendermark puts company names and logos on the businesses that text you.",
            "",
            "USAGE: sendermark [--help] [--version]",
            "",
            "OPTIONS:",
        ]
        for option in options {
            let flags = option.flags.joined(separator: ", ")
            let padding = String(repeating: " ", count: max(1, 16 - flags.count))
            lines.append("  \(flags)\(padding)\(option.summary)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static var versionText: String {
        "sendermark \(Sendermark.version)\n"
    }

    /// Runs one invocation. `arguments` excludes the program name.
    static func run(_ arguments: [String]) -> Outcome {
        guard let first = arguments.first else {
            return Outcome(standardOutput: helpText, exitStatus: 0)
        }
        guard arguments.count == 1 else {
            return usageError("expected at most one argument, got \(arguments.count)")
        }
        switch first {
        case "-h", "--help":
            return Outcome(standardOutput: helpText, exitStatus: 0)
        case "--version":
            return Outcome(standardOutput: versionText, exitStatus: 0)
        default:
            return usageError("unknown argument '\(first)'")
        }
    }

    private static func usageError(_ message: String) -> Outcome {
        Outcome(
            standardError: "error: \(message)\nRun 'sendermark --help' for usage.\n",
            exitStatus: usageExitStatus
        )
    }
}
