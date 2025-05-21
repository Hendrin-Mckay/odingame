# Odingame - Simple Example

## Overview

This example demonstrates a basic application using the Odingame framework. It displays a window and allows the user to move a (placeholder) sprite using the arrow keys. The Escape key exits the game.

The sprite texture (`sprite.png`) is currently a placeholder text file (`sprite.png.txt`). To see an actual image, replace `examples/simple_game/sprite.png.txt` with a real `sprite.png` image file (e.g., a 32x32 PNG). The game will attempt to load `sprite.png` first; if that fails, it notes the placeholder.

## How to Build and Run

1.  **Prerequisites:**
    *   Odin compiler installed (see [odin-lang.org](https://odin-lang.org/)).
    *   SDL2 development libraries installed.
    *   SDL2_image development libraries installed.
    *   The Odingame framework source code (assumed to be in a directory named `odingame` parallel to this `examples` directory).

2.  **Build Command:**
    Open your terminal. Navigate to the root directory of the entire Odingame project (the one containing the `odingame` framework directory and the `examples` directory).

    Then, run the following command:

    ```bash
    odin build examples/simple_game -collection:odingame=odingame
    ```

    *   `odin build examples/simple_game`: Tells the compiler to build the code in the `examples/simple_game` directory. The output executable will typically be named after the directory (e.g., `simple_game` or `simple_game.exe`).
    *   `-collection:odingame=odingame`: This flag tells the Odin compiler where to find the `odingame` framework packages. It maps the import prefix `odingame:` (used in `main.odin` like `import ocore "../../odingame/core"`, which resolves to `odingame:core` effectively) to the actual directory named `odingame` in the project root.

3.  **Run:**
    After successful compilation, an executable will be created (usually in the current directory where you ran the build command, or in a `bin` subdirectory, depending on your Odin setup).

    Run this executable from the project root directory:
    - On Linux/macOS: `./simple_game` (or `./bin/simple_game`)
    - On Windows: `simple_game.exe` (or `bin\simple_game.exe`)

    The executable needs to be run from a context where the relative path `examples/simple_game/sprite.png` (or `sprite.png.txt`) is valid if you want it to attempt loading the image file. Running from the project root usually works for this.

## Controls

-   **Arrow Keys (Up, Down, Left, Right):** Move the sprite.
-   **Escape (ESC):** Exit the game.
