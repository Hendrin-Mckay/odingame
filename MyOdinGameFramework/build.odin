package main

import "core:os"
import "core:fmt"

import "core:strings" // For joining paths if needed

// Configuration for SDL3 - users might need to set these via env variables
// or by modifying this build script if SDL3 is not in a standard location.
SDL3_LIB_NAME :: #config(SDL3_LIB, "SDL3") // e.g., "SDL3" or "SDL3-static"
SDL3_LIB_PATH :: #config(SDL3_LIB_PATH, "") // e.g., "/usr/local/lib" or "C:/SDL3/lib"
SDL3_INCLUDE_PATH :: #config(SDL3_INCLUDE_PATH, "") // e.g., "/usr/local/include/SDL3" or "C:/SDL3/include"

// Later, for SDL_image, SDL_mixer, SDL_ttf
SDL_IMAGE_LIB_NAME :: #config(SDL_IMAGE_LIB, "SDL3_image")
SDL_MIXER_LIB_NAME :: #config(SDL_MIXER_LIB, "SDL3_mixer")
SDL_TTF_LIB_NAME :: #config(SDL_TTF_LIB, "SDL3_ttf")


main :: proc() {
	fmt.println("Building MyOdinGameFramework...")

	src_path :: "src"
	output_name :: "MyOdinGameFramework" // .exe will be added automatically on windows

	// Build command arguments
	base_args := []string{
		"build",
		src_path,
		"-out:" + output_name,
		"-collection:src=src", // Name the collection for imports like "src:core"
		// "-debug", // Optional: add debug information
	}

	// --- SDL3 Linker and Compiler Flags ---
	linker_flags := ""
	compiler_flags := ""

	// Library name (e.g., -lSDL3)
	if SDL3_LIB_NAME != "" {
		linker_flags = strings.concatenate([]string{linker_flags, " -l", SDL3_LIB_NAME})
	}
    // SDL_image (e.g., -lSDL3_image)
	if SDL_IMAGE_LIB_NAME != "" {
		linker_flags = strings.concatenate([]string{linker_flags, " -l", SDL_IMAGE_LIB_NAME})
	}
    // SDL_mixer (e.g., -lSDL3_mixer)
	if SDL_MIXER_LIB_NAME != "" {
		linker_flags = strings.concatenate([]string{linker_flags, " -l", SDL_MIXER_LIB_NAME})
	}
    // SDL_ttf (e.g., -lSDL3_ttf)
	if SDL_TTF_LIB_NAME != "" {
		linker_flags = strings.concatenate([]string{linker_flags, " -l", SDL_TTF_LIB_NAME})
	}


	// Library path (e.g., -L/usr/local/lib)
	if SDL3_LIB_PATH != "" {
		linker_flags = strings.concatenate([]string{linker_flags, " -L", SDL3_LIB_PATH})
		// On some systems, you might need to add this to rpath as well for dynamic linking
		// linker_flags = strings.concatenate([]string{linker_flags, " -Wl,-rpath,", SDL3_LIB_PATH})
	}

	// Include path (e.g., -I/usr/local/include/SDL3)
	if SDL3_INCLUDE_PATH != "" {
		compiler_flags = strings.concatenate([]string{compiler_flags, " -I", SDL3_INCLUDE_PATH})
	}

	final_args := base_args
	if strings.trim_space(linker_flags) != "" {
		final_args = append(final_args, "-extra-linker-flags:" + strings.trim_space(linker_flags))
	}
	if strings.trim_space(compiler_flags) != "" {
		// For Odin, include paths are often passed via -extra-compiler-flags or directly if the compiler supports it
		// Depending on the Odin version and how it handles system vs external includes,
		// you might also need to ensure the SDL headers are wrapped in a module or directly accessible.
		// For now, adding -I to extra-compiler-flags is a common approach.
		final_args = append(final_args, "-extra-compiler-flags:" + strings.trim_space(compiler_flags))
	}
	
	// Add defines for foreign blocks if necessary, e.g. when using SDL_main
	// final_args = append(final_args, "-define:ODIN_SDL_MAIN_HANDLED=true") // If we handle SDL_main entry point

	fmt.printf("Build arguments: %v\n", final_args)

	res, err := os.execute(final_args)
	if err != 0 {
		fmt.eprintf("Build failed. Error code: %d\n", err)
		// The output from os.execute is often in `res` even on error.
        if len(res) > 0 {
		    fmt.eprintf("Compiler/Linker Output:\n%s\n", string(res))
        }
		os.exit(err)
	} else {
		fmt.printf("Build successful! Output: %s\n", output_name)
        if len(res) > 0 {
		    fmt.printf("Compiler/Linker Output:\n%s\n", string(res))
        }

	}
}
