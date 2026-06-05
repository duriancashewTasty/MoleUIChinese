import Foundation

/// Error translator: Translates CLI errors into user-friendly messages
enum ErrorTranslator {
    struct UserFriendlyError {
        let title: String
        let message: String
        let suggestion: String?
        let nextSteps: [String]
        let technicalDetails: String?
        let severity: Severity

        enum Severity {
            case info
            case warning
            case error
            case critical
        }
    }

    /// Translate CLI error
    static func translate(
        error: Error,
        context: String? = nil
    ) -> UserFriendlyError {
        // 1. Handle known error types
        if let cliError = error as? CLIExecutor.ExecutionError {
            return translateCLIError(cliError, context: context)
        }

        // 2. Handle system errors
        if let nsError = error as NSError? {
            return translateSystemError(nsError, context: context)
        }

        // 3. Default error
        return UserFriendlyError(
            title: LanguageManager.tr("Operation Failed"),
            message: LanguageManager.tr("An unknown error occurred"),
            suggestion: LanguageManager.tr("Please try again. If the problem persists, contact support"),
            nextSteps: [
                LanguageManager.tr("Retry operation"),
                LanguageManager.tr("Check system logs"),
                LanguageManager.tr("Contact support"),
            ],
            technicalDetails: error.localizedDescription,
            severity: .error
        )
    }

    // MARK: - CLI Error Translation

    private static func translateCLIError(
        _ error: CLIExecutor.ExecutionError,
        context: String?
    ) -> UserFriendlyError {
        switch error {
        case .timeout:
            UserFriendlyError(
                title: LanguageManager.tr("Operation Timeout"),
                message: LanguageManager.tr("Operation took too long and was automatically cancelled"),
                suggestion: LanguageManager.tr("This may be due to too many files to clean or high system load"),
                nextSteps: [
                    LanguageManager.tr("Try cleaning a smaller scope"),
                    LanguageManager.tr("Close other resource-intensive apps"),
                    LanguageManager.tr("Try again later"),
                ],
                technicalDetails: "Execution timeout",
                severity: .warning
            )

        case .cancelled:
            UserFriendlyError(
                title: LanguageManager.tr("Operation Cancelled"),
                message: LanguageManager.tr("You have cancelled the current operation"),
                suggestion: nil,
                nextSteps: [LanguageManager.tr("Restart operation")],
                technicalDetails: "User cancelled",
                severity: .info
            )

        case .commandNotFound(let cmd):
            UserFriendlyError(
                title: LanguageManager.tr("Command Not Found"),
                message: LanguageManager.tr("Cannot find \(cmd) command"),
                suggestion: LanguageManager.tr("Mole CLI may not be properly installed"),
                nextSteps: [
                    LanguageManager.tr("Reinstall the app"),
                    LanguageManager.tr("Check app permissions"),
                    LanguageManager.tr("Contact support"),
                ],
                technicalDetails: "Command not found: \(cmd)",
                severity: .critical
            )

        case .nonZeroExit(let code, let stderr):
            translateExitCode(code, stderr: stderr, context: context)

        case .invalidOutput(let msg):
            UserFriendlyError(
                title: LanguageManager.tr("Output Parsing Failed"),
                message: LanguageManager.tr("Cannot understand command output"),
                suggestion: LanguageManager.tr("This may be due to Mole CLI version incompatibility"),
                nextSteps: [
                    LanguageManager.tr("Update app to latest version"),
                    LanguageManager.tr("Retry operation"),
                    LanguageManager.tr("Contact support"),
                ],
                technicalDetails: msg,
                severity: .error
            )
        }
    }

    // MARK: - Exit Code Translation

    private static func translateExitCode(
        _ code: Int32,
        stderr: String,
        context: String?
    ) -> UserFriendlyError {
        // Analyze stderr content
        let stderrLower = stderr.lowercased()

        // Permission errors
        if stderrLower.contains("permission denied") ||
            stderrLower.contains("operation not permitted")
        {
            return UserFriendlyError(
                title: LanguageManager.tr("Permission Denied"),
                message: LanguageManager.tr("Insufficient permissions to perform this operation"),
                suggestion: LanguageManager.tr("Some system files require administrator privileges to clean"),
                nextSteps: [
                    LanguageManager.tr("Click 'Use Administrator Privileges' button"),
                    LanguageManager.tr("Or skip files that require permissions"),
                ],
                technicalDetails: "Exit code: \(code)\n\(stderr)",
                severity: .warning
            )
        }

        // Default error
        return UserFriendlyError(
            title: LanguageManager.tr("Operation Failed"),
            message: context ?? LanguageManager.tr("An error occurred while executing command"),
            suggestion: LanguageManager.tr("Please check details for more information"),
            nextSteps: [
                LanguageManager.tr("Retry operation"),
                LanguageManager.tr("View technical details"),
                LanguageManager.tr("Contact support"),
            ],
            technicalDetails: "Exit code: \(code)\n\(stderr)",
            severity: .error
        )
    }

    // MARK: - System Error Translation

    private static func translateSystemError(
        _ error: NSError,
        context: String?
    ) -> UserFriendlyError {
        UserFriendlyError(
            title: LanguageManager.tr("System Error"),
            message: error.localizedDescription,
            suggestion: LanguageManager.tr("This is a system-level error"),
            nextSteps: [
                LanguageManager.tr("Retry operation"),
                LanguageManager.tr("Restart app"),
                LanguageManager.tr("Contact support"),
            ],
            technicalDetails: "\(error.domain): \(error.code)",
            severity: .error
        )
    }
}
