import BtmxFocusDriver
import BtmxFocusUIContract
import Foundation

// `focus-drive`: the E2E driver from the command line, for exploring the
// running E2E build by hand or from an agent (ADR 0010).

let usage = """
usage: swift run focus-drive <command>
  launch [args…]   quit any running E2E app, launch it (args go to the app,
                   e.g. --e2e-focus-seconds 3 --e2e-reset-settings)
  quit             quit the E2E app
  tree             print the app's accessibility tree (status item included)
  click <id>       click the element with this accessibility identifier
                   (`statusItem` for the status item, `outside` for the
                   empty menu bar)
  key <keys>       press keys, e.g. space, cmd+w, escape
  shot <name>      save a checkpoint screenshot; prints its path
  state            print who has the keyboard and any held keys/buttons
  release          release modifier keys a run left held down
Screenshots go to $E2E_OUTPUT_DIR or build/e2e/<timestamp>/.
"""

func main() throws {
    var arguments = Array(CommandLine.arguments.dropFirst())
    guard !arguments.isEmpty else {
        print(usage)
        exit(2)
    }
    let command = arguments.removeFirst()
    let app = FocusApp()
    switch command {
    case "launch":
        try app.launch(arguments)
        print("Launched \(E2EContract.appName) (pid \(app.pid ?? 0))")
    case "quit":
        if FocusApp.runningPID() != nil {
            try app.attach()
            try app.quit()
        }
    case "state":
        if FocusApp.runningPID() != nil {
            try app.attach()
        }
        print(app.inputState())
    case "release":
        print(app.releaseLeakedInput().map { "released \($0)" } ?? "nothing held")
    case "tree", "click", "key", "shot":
        try app.attach()
        try drive(app, command, argument: arguments.first)
    default:
        print(usage)
        exit(2)
    }
}

/// Commands on the running app.
func drive(_ app: FocusApp, _ command: String, argument: String?) throws {
    switch command {
    case "tree":
        try print(app.tree())
    case "click":
        guard let identifier = argument else { throw DriverError("click needs an identifier") }
        switch identifier {
        case "statusItem", AccessibilityID.statusItem: try app.clickStatusItem()
        case "outside": try app.clickOutside()
        default: try app.click(identifier)
        }
    case "key":
        guard let keys = argument else { throw DriverError("key needs keys, e.g. space") }
        try app.key(keys)
    default:
        for url in try app.screenshot(argument ?? "shot") {
            print(url.path)
        }
    }
}

do {
    try main()
} catch {
    FileHandle.standardError.write(Data("focus-drive: \(error)\n".utf8))
    exit(1)
}
