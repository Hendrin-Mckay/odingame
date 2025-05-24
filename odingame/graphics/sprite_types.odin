package graphics

// Sprite_Sort_Mode defines how sprites are sorted before drawing.
Sprite_Sort_Mode :: enum {
    Deferred,         // Sprites are drawn when End is called, in the order they were submitted. (Default)
    Immediate,        // Sprites are drawn immediately with current state. (Not recommended for many sprites)
    Texture,          // Sprites are sorted by texture, then drawn. Minimizes texture swaps.
    Back_To_Front,    // Sprites are sorted by layer_depth (descending), then drawn.
    Front_To_Back,    // Sprites are sorted by layer_depth (ascending), then drawn.
}

// Sprite_Effects defines flipping operations for sprites.
Sprite_Effects :: enum {
    None              = 0,
    Flip_Horizontally = 1,
    Flip_Vertically   = 2,
    // Flip_Both      = Flip_Horizontally | Flip_Vertically, // Can be added later
}

// Blend_State_Type provides common pre-defined blend states.
// More detailed Blend_State structs can be used with custom Effects.
Blend_State_Type :: enum {
    Additive,         // Additive blending (e.g., for lighting effects)
    Alpha_Blend,      // Standard alpha blending (premultiplied alpha assumed by default in XNA)
    Non_Premultiplied,// Alpha blending for non-premultiplied alpha textures
    Opaque,           // No blending, source overwrites destination
}

// Sampler_State_Type provides common pre-defined sampler states.
Sampler_State_Type :: enum {
    Linear_Clamp,
    Linear_Wrap,
    Point_Clamp,
    Point_Wrap,
    Anisotropic_Clamp, // Requires anisotropic filtering support
    Anisotropic_Wrap,
    // Add more as needed (e.g., Mirror)
}

// Depth_Stencil_State_Type provides common pre-defined depth/stencil states.
Depth_Stencil_State_Type :: enum {
    None,             // No depth/stencil testing or writing.
    Depth_Default,    // Default depth testing (LessEqual, write enabled).
    Depth_Read,       // Depth testing enabled (LessEqual), depth writes disabled.
    // Depth_Read_Write // Same as Depth_Default for now.
}

// Rasterizer_State_Type provides common pre-defined rasterizer states.
Rasterizer_State_Type :: enum {
    Cull_Counter_Clockwise, // Default: Cull back faces, CCW front.
    Cull_Clockwise,         // Cull back faces, CW front.
    Cull_None,              // No culling, typically for 2D or special effects.
    Wireframe,              // Wireframe rendering (if supported and useful for sprites)
}

// Effect is a placeholder for custom shader effects.
// In a full implementation, this would manage shaders, parameters, and techniques.
Effect :: struct {
    // name: string,
    // Gfx_Pipeline might be cached here, or created on demand based on parameters.
    // For now, it's empty. SpriteBatch will use its default_pipeline if this is nil or basic.
}

// Helper to check if an effect is "simple" or implies default pipeline usage
is_default_effect :: proc(effect: ^Effect) -> bool {
    return effect == nil // For now, any non-nil effect is considered "custom"
}
