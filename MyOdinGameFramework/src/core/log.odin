package core

import "core:fmt"
import "core:os"

// LogInfo prints an informational message to stdout.
LogInfo :: proc(message: string, args: ..any) {
	fmt.printf("[INFO] " + message + "\n", ..args)
}

// LogWarning prints a warning message to stderr.
LogWarning :: proc(message: string, args: ..any) {
	fmt.eprintf("[WARN] " + message + "\n", ..args)
}

// LogError prints an error message to stderr.
LogError :: proc(message: string, args: ..any) {
	fmt.eprintf("[ERROR] " + message + "\n", ..args)
}

// LogErrorAndExit prints an error message to stderr and then exits the program with status 1.
LogErrorAndExit :: proc(message: string, args: ..any) {
    fmt.eprintf("[FATAL] " + message + "\n", ..args)
    os.exit(1)
}
