package graphics

import "../common" // For Engine_Error
// Import common types like Vector2, Color, etc.
// These are foundational types used across the engine.
import "../types" 

// Import graphics-specific types that were moved to the graphics.types package.
// This includes enums, structs for pipeline descriptions, vertex layouts, etc.
import "./types" 
import "core:math"


// --- Interfaces ---
// These are backend-agnostic handles to graphics resources.
// The actual implementation details are hidden behind these handles
// and managed by the specific graphics backend (OpenGL, Vulkan, etc.).

Gfx_Device :: struct {
	variant: rawptr // Will hold the backend-specific device pointer
}

is_valid :: proc(d: Gfx_Device) -> bool {
	return d.variant != nil
}

Gfx_Window :: struct {
	variant: rawptr // Will hold the backend-specific window pointer
}

Gfx_Shader :: struct {
	variant: rawptr // Will hold the backend-specific shader pointer
}

Gfx_Pipeline :: struct {
	variant: rawptr // Will hold the backend-specific pipeline pointer
}

Gfx_Buffer :: struct {
	variant: rawptr // Will hold the backend-specific buffer pointer
}

Gfx_Texture :: struct {
	variant: rawptr // Will hold the backend-specific texture pointer
}

Gfx_Framebuffer :: struct {
	variant: rawptr // Will hold the backend-specific framebuffer pointer
}

Gfx_Render_Pass :: struct {
	variant: rawptr // Will hold the backend-specific render pass object (e.g. for Vulkan)
}

// Gfx_Vertex_Array represents a Vertex Array Object (VAO) or its equivalent.
// It encapsulates the state of vertex buffers, index buffer, and vertex attribute configurations.
// This is a backend-specific concept, so it's a struct_variant.
Gfx_Vertex_Array :: struct_variant { // e.g. opengl: ^Gl_Vertex_Array
	vulkan: ^rawptr // Will hold ^vulkan.Vk_Vertex_Array_Internal
	// Metal doesn't have a direct VAO equivalent; state is set on the render command encoder.
	// A Metal backend might store a descriptor or a helper struct here.
}


// Import the composed API structure.
// The `api` subpackage contains the definitions for Gfx_Api_Composed and its constituent interfaces.
import "./api"
// `core:math` might not be directly needed here anymore if it was only for types now in `./types` or `../types`
// However, `matrix[4,4]f32` might still be used in some function signatures if not fully moved.
// For now, keep it, but this could be a point of cleanup later.
// import "core:math" // Commented out, as matrix type is likely through other imports now.

// Global instance of the composed graphics API.
// This variable will be populated by a specific graphics backend (e.g., OpenGL, Vulkan)
// during initialization. All engine systems will interact with the graphics hardware
// through this composed API.
gfx_api: api.Gfx_Api_Composed

// Helper to get a default clear options.
// This function now uses `types.Clear_Options` from the `graphics.types` package.
// It provides a convenient way to get a standard set of clearing parameters.
default_clear_options :: proc() -> types.Clear_Options {
    // Ensure that types.Clear_Options is correctly imported and accessible.
    // The path "./types" refers to `odingame/graphics/types/common_types.odin`
    // where Clear_Options is now defined.
    return types.Clear_Options{
        color          = {0.1, 0.1, 0.1, 1.0},
        depth_value    = 1.0, 
        stencil_value  = 0,
        clear_color    = true,
        clear_depth    = true,
        clear_stencil  = false,
    }
}
