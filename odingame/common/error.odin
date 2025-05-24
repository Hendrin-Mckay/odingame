package common

// Engine_Error defines all possible error types in the engine
// This is used to standardize error handling across the codebase
Engine_Error :: enum {
    None,                      // No error occurred
    
    // General errors
    Invalid_Parameter,         // Invalid parameter passed to a function
    Invalid_Operation,         // Operation not valid in current state
    Not_Implemented,           // Feature not implemented yet
    Resource_Not_Found,        // Resource (file, asset, etc.) not found
    Out_Of_Memory,             // Memory allocation failed
    OpenGL_Error,              // Generic OpenGL error
    
    // Graphics errors
    Graphics_Initialization_Failed,  // Graphics system initialization failed
    Device_Creation_Failed,          // Graphics device creation failed
    Window_Creation_Failed,          // Window creation failed
    Shader_Compilation_Failed,       // Shader compilation failed
    Pipeline_Creation_Failed,        // Pipeline creation failed
    Buffer_Creation_Failed,          // Buffer creation failed
    Texture_Creation_Failed,         // Texture creation failed
    Framebuffer_Creation_Failed,     // Framebuffer creation failed
    Invalid_Handle,                  // Invalid graphics handle
    Invalid_Argument,              // Invalid argument specifically for graphics functions
    Unsupported_Format,            // Unsupported texture/buffer format

    
    // Input errors
    Input_Initialization_Failed,     // Input system initialization failed
    
    // Audio errors
    Audio_Initialization_Failed,     // Audio system initialization failed
    Sound_Loading_Failed,            // Sound loading failed
    
    // File I/O errors
    File_Not_Found,                  // File not found
    File_Access_Denied,              // File access denied
    File_Read_Error,                 // Error reading from file
    File_Write_Error,                // Error writing to file
    
    // Scene errors
    Scene_Creation_Failed,           // Scene creation failed
    Component_Creation_Failed,       // Component creation failed

    // Vulkan specific errors (can be more granular if needed)
    Vulkan_Error,                    // Generic Vulkan error
    Vulkan_Surface_Error,            // Error related to Vulkan surface
    Vulkan_Swapchain_Error,          // Error related to Vulkan swapchain
    Vulkan_Validation_Layers_Not_Supported, // Validation layers requested but not available
    
    // DirectX specific errors
    DirectX_Error,                   // Generic DirectX error
    
    // Metal specific errors
    Metal_Error,                     // Generic Metal error

    // JSON errors
    Json_Parse_Error,
    Json_Marshal_Error,

    // Scripting errors
    Script_Error,

    // Physics errors
    Physics_Error,

    // Network errors
    Network_Error,

    // UI errors
    UI_Error,

    // Animation errors
    Animation_Error,

    // Generic errors from external libraries
    External_Library_Error,

    // Engine specific states/errors
    Not_Ready,                       // A system or resource is not ready for the operation
    Already_Initialized,             // System or resource already initialized
    System_Not_Initialized,          // A required system is not initialized
}

// Convert an Engine_Error to a string description
engine_error_to_string :: proc(err: Engine_Error) -> string {
    #partial switch err {
    case .None:                        return "No error"
    case .Invalid_Parameter:           return "Invalid parameter"
    case .Invalid_Operation:           return "Invalid operation"
    case .Not_Implemented:             return "Not implemented"
    case .Resource_Not_Found:          return "Resource not found"
    case .Out_Of_Memory:               return "Out of memory"
    case .OpenGL_Error:                return "OpenGL error"
    case .Graphics_Initialization_Failed: return "Graphics initialization failed"
    case .Device_Creation_Failed:      return "Device creation failed"
    case .Window_Creation_Failed:      return "Window creation failed"
    case .Shader_Compilation_Failed:   return "Shader compilation failed"
    case .Pipeline_Creation_Failed:    return "Pipeline creation failed"
    case .Buffer_Creation_Failed:      return "Buffer creation failed"
    case .Texture_Creation_Failed:     return "Texture creation failed"
    case .Framebuffer_Creation_Failed: return "Framebuffer creation failed"
    case .Invalid_Handle:              return "Invalid handle"
    case .Invalid_Argument:            return "Invalid graphics argument"
    case .Unsupported_Format:          return "Unsupported graphics format"
    case .Input_Initialization_Failed: return "Input initialization failed"
    case .Audio_Initialization_Failed: return "Audio initialization failed"
    case .Sound_Loading_Failed:        return "Sound loading failed"
    case .File_Not_Found:              return "File not found"
    case .File_Access_Denied:          return "File access denied"
    case .File_Read_Error:             return "File read error"
    case .File_Write_Error:            return "File write error"
    case .Scene_Creation_Failed:       return "Scene creation failed"
    case .Component_Creation_Failed:   return "Component creation failed"
    case .Vulkan_Error:                return "Vulkan error"
    case .Vulkan_Surface_Error:        return "Vulkan surface error"
    case .Vulkan_Swapchain_Error:      return "Vulkan swapchain error"
    case .Vulkan_Validation_Layers_Not_Supported: return "Vulkan validation layers not supported"
    case .DirectX_Error:               return "DirectX error"
    case .Metal_Error:                 return "Metal error"
    case .Json_Parse_Error:            return "JSON parse error"
    case .Json_Marshal_Error:          return "JSON marshal error"
    case .Script_Error:                return "Scripting error"
    case .Physics_Error:               return "Physics error"
    case .Network_Error:               return "Network error"
    case .UI_Error:                    return "UI error"
    case .Animation_Error:             return "Animation error"
    case .External_Library_Error:      return "External library error"
    case .Not_Ready:                   return "System or resource not ready"
    case .Already_Initialized:         return "System or resource already initialized"
    case .System_Not_Initialized:      return "Required system not initialized"
    }
    return "Unknown error code"
}
