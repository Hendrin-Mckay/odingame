package main

import "core:os"
import "core:fmt"

main :: proc() {
	fmt.println("Building MyOdinGameFramework...")

	// Define source files location
	src_path :: "src"

	// Define output executable name
	output_name :: "MyOdinGameFramework.exe" // or just MyOdinGameFramework for non-Windows

	// Placeholder for SDL3 linking
	// SDL3_LIBRARIES :: #config(SDL3_LIBS, "") // Example of how config might be used
	// SDL3_INCLUDE_PATHS :: #config(SDL3_INCLUDE, "")

	// Build command arguments
	args := []string{
		"build",
		src_path,
		"-out:" + output_name,
		// "-extra-linker-flags:" + SDL3_LIBRARIES, // Example
		// "-extra-compiler-flags:-I" + SDL3_INCLUDE_PATHS, // Example
	}

	// Execute the Odin build command
	res, err := os.execute(args)
	if err != 0 {
		fmt.eprintf("Build failed: %v\n", err)
		os.exit(err)
	} else {
		fmt.printf("Build successful! Output: %s\n", output_name)
		fmt.printf("Output from compiler: %s\n", string(res))
	}
}
