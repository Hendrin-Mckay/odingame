package metal

import "core:objc"
import "core:c" // For C types like char, int, bool if not directly from sys/darwin
// import "core:sys/darwin/Foundation" // If specific Foundation types are needed directly
// import "core:sys/darwin/Metal"      // If specific Metal types are needed directly
// import "core:sys/darwin/QuartzCore" // For CAMetalLayer if types are needed directly

// --- Foreign Frameworks ---
#foreign_system_library "Foundation"
#foreign_system_library "Metal"
#foreign_system_library "QuartzCore" // For CAMetalLayer

// --- Basic Types ---
// These might come from a more specific darwin system package if available and complete.
BOOL :: bool // In Objective-C, BOOL is typically a signed char (objc_bool in Odin's runtime). For simplicity, using Odin's bool.
NSInteger :: c.long
NSUInteger :: c.ulong
CGFloat :: f64 // Or f32 depending on context, usually f64 for CoreGraphics points/sizes. Let's use f64 for now.
NSString_Handle :: distinct rawptr // Represents NSString*
NSError_Handle :: distinct rawptr  // Represents NSError*
id :: rawptr // Generic Objective-C object type

// CGPoint and CGSize for drawableSize
CGPoint :: struct { x, y: CGFloat }
CGSize :: struct { width, height: CGFloat }
CGRect :: struct { origin: CGPoint, size: CGSize }


// --- Metal Object Handles (distinct rawptr for type safety) ---
MTLDevice_Handle :: distinct rawptr              // id<MTLDevice>
MTLCommandQueue_Handle :: distinct rawptr         // id<MTLCommandQueue>
MTLCommandBuffer_Handle :: distinct rawptr        // id<MTLCommandBuffer>
MTLRenderPassDescriptor_Handle :: distinct rawptr // MTLRenderPassDescriptor*
MTLRenderPipelineDescriptor_Handle :: distinct rawptr // MTLRenderPipelineDescriptor*
MTLRenderPipelineColorAttachmentDescriptor_Handle :: distinct rawptr // MTLRenderPipelineColorAttachmentDescriptor* (part of array)
MTLVertexDescriptor_Handle :: distinct rawptr       // MTLVertexDescriptor*
MTLVertexBufferLayoutDescriptor_Handle :: distinct rawptr // MTLVertexBufferLayoutDescriptor* (part of array)
MTLVertexAttributeDescriptor_Handle :: distinct rawptr  // MTLVertexAttributeDescriptor* (part of array)
MTLRenderCommandEncoder_Handle :: distinct rawptr // id<MTLRenderCommandEncoder>
MTLBuffer_Handle :: distinct rawptr             // id<MTLBuffer>
MTLTexture_Handle :: distinct rawptr            // id<MTLTexture>
MTLLibrary_Handle :: distinct rawptr            // id<MTLLibrary>
MTLFunction_Handle :: distinct rawptr           // id<MTLFunction>
MTLRenderPipelineState_Handle :: distinct rawptr  // id<MTLRenderPipelineState>
MTLDepthStencilState_Handle :: distinct rawptr // id<MTLDepthStencilState>
MTLSamplerState_Handle :: distinct rawptr      // id<MTLSamplerState>

// QuartzCore Handles
CAMetalLayer_Handle :: distinct rawptr          // CAMetalLayer*
MTLDrawable_Handle :: distinct rawptr           // id<CAMetalDrawable> (from layer.nextDrawable)
// Note: CAMetalDrawable is protocol, usually id<CAMetalDrawable>. MTLDrawable_Handle represents this.

// --- Common Objective-C Selectors ---
// These are used with objc.msg_send
sel_alloc :: objc.selector("alloc")
sel_init :: objc.selector("init") // Basic init
sel_release :: objc.selector("release")
sel_retain :: objc.selector("retain") // If manual retain/release is needed beyond ARC
sel_autorelease :: objc.selector("autorelease")

// MTLDevice selectors
sel_newCommandQueue :: objc.selector("newCommandQueue")
sel_newDefaultLibrary :: objc.selector("newDefaultLibrary") // Added
sel_newLibraryWithFile_error :: objc.selector("newLibraryWithFile:error:") // Added
sel_newLibraryWithSource_options_error :: objc.selector("newLibraryWithSource:options:error:")
sel_newRenderPipelineStateWithDescriptor_error :: objc.selector("newRenderPipelineStateWithDescriptor:error:")
sel_newDepthStencilStateWithDescriptor :: objc.selector("newDepthStencilStateWithDescriptor:")
sel_newBufferWithLength_options :: objc.selector("newBufferWithLength:options:")
sel_newBufferWithBytes_length_options :: objc.selector("newBufferWithBytes:length:options:") 
sel_newTextureWithDescriptor :: objc.selector("newTextureWithDescriptor:")
sel_newSamplerStateWithDescriptor :: objc.selector("newSamplerStateWithDescriptor:") // For Sampler States

// MTLLibrary selectors
sel_newFunctionWithName :: objc.selector("newFunctionWithName:") // Added
// sel_functionNames :: objc.selector("functionNames") // Returns NSArray<NSString*>*, useful for inspection

// MTLFunction selectors
// No specific selectors other than IUnknown needed for basic use (e.g. name, device are properties)

// MTLCompileOptions selectors (if used)
// sel_setLanguageVersion :: objc.selector("setLanguageVersion:")

// MTLBuffer selectors
sel_contents :: objc.selector("contents") // Added
sel_didModifyRange :: objc.selector("didModifyRange:") // Added
// Length, options, setPurgeableState, etc. can be added if needed.

// MTLCommandQueue selectors
sel_commandBuffer :: objc.selector("commandBuffer")

// MTLCommandBuffer selectors
sel_presentDrawable :: objc.selector("presentDrawable:")
sel_commit :: objc.selector("commit")
sel_waitUntilCompleted :: objc.selector("waitUntilCompleted")
sel_renderCommandEncoderWithDescriptor :: objc.selector("renderCommandEncoderWithDescriptor:")

// MTLRenderCommandEncoder selectors
sel_setRenderPipelineState :: objc.selector("setRenderPipelineState:")
sel_setVertexBuffer_offset_atIndex :: objc.selector("setVertexBuffer:offset:atIndex:")
sel_setFragmentTexture_atIndex :: objc.selector("setFragmentTexture:atIndex:")
sel_setFragmentSamplerState_atIndex :: objc.selector("setFragmentSamplerState:atIndex:")
sel_drawPrimitives_vertexStart_vertexCount :: objc.selector("drawPrimitives:vertexStart:vertexCount:")
sel_drawIndexedPrimitives_indexCount_indexType_indexBuffer_indexBufferOffset :: objc.selector("drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:")
sel_endEncoding :: objc.selector("endEncoding")
sel_setViewport :: objc.selector("setViewport:") // Takes MTLViewport struct
sel_setDepthStencilState :: objc.selector("setDepthStencilState:")
sel_setCullMode :: objc.selector("setCullMode:") // Added for dynamic rasterizer state
sel_setFrontFacingWinding :: objc.selector("setFrontFacingWinding:") // Added
sel_setDepthClipMode :: objc.selector("setDepthClipMode:") // Added
sel_setDepthBias_slopeScale_clamp :: objc.selector("setDepthBias:slopeScale:clamp:") // Added

// MTLRenderPipelineDescriptor selectors
sel_label :: objc.selector("label")
sel_setLabel :: objc.selector("setLabel:")
sel_vertexFunction :: objc.selector("vertexFunction")
sel_setVertexFunction :: objc.selector("setVertexFunction:")
sel_fragmentFunction :: objc.selector("fragmentFunction")
sel_setFragmentFunction :: objc.selector("setFragmentFunction:")
sel_vertexDescriptor :: objc.selector("vertexDescriptor")
sel_setVertexDescriptor :: objc.selector("setVertexDescriptor:")
sel_colorAttachments :: objc.selector("colorAttachments") // Already exists, used for RenderPass too
sel_depthAttachmentPixelFormat :: objc.selector("depthAttachmentPixelFormat")
sel_setDepthAttachmentPixelFormat :: objc.selector("setDepthAttachmentPixelFormat:")
sel_stencilAttachmentPixelFormat :: objc.selector("stencilAttachmentPixelFormat")
sel_setStencilAttachmentPixelFormat :: objc.selector("setStencilAttachmentPixelFormat:")
// sel_inputPrimitiveTopology :: objc.selector("inputPrimitiveTopology") // For tessellation/mesh shaders
// sel_setInputPrimitiveTopology :: objc.selector("setInputPrimitiveTopology:")

// MTLRenderPipelineColorAttachmentDescriptor (obtained via [pipelineDescriptor.colorAttachments objectAtIndexedSubscript:i])
// sel_pixelFormat exists on CAMetalLayer, also on this descriptor
// sel_setPixelFormat exists on CAMetalLayer, also on this descriptor
sel_isBlendingEnabled :: objc.selector("isBlendingEnabled")
sel_setBlendingEnabled :: objc.selector("setBlendingEnabled:")
sel_sourceRGBBlendFactor :: objc.selector("sourceRGBBlendFactor")
sel_setSourceRGBBlendFactor :: objc.selector("setSourceRGBBlendFactor:")
sel_destinationRGBBlendFactor :: objc.selector("destinationRGBBlendFactor")
sel_setDestinationRGBBlendFactor :: objc.selector("setDestinationRGBBlendFactor:")
sel_rgbBlendOperation :: objc.selector("rgbBlendOperation")
sel_setRgbBlendOperation :: objc.selector("setRgbBlendOperation:")
sel_sourceAlphaBlendFactor :: objc.selector("sourceAlphaBlendFactor")
sel_setSourceAlphaBlendFactor :: objc.selector("setSourceAlphaBlendFactor:")
sel_destinationAlphaBlendFactor :: objc.selector("destinationAlphaBlendFactor")
sel_setDestinationAlphaBlendFactor :: objc.selector("setDestinationAlphaBlendFactor:")
sel_alphaBlendOperation :: objc.selector("alphaBlendOperation")
sel_setAlphaBlendOperation :: objc.selector("setAlphaBlendOperation:")
sel_writeMask :: objc.selector("writeMask")
sel_setWriteMask :: objc.selector("setWriteMask:")


// MTLVertexDescriptor selectors
sel_layouts :: objc.selector("layouts") // Returns MTLVertexBufferLayoutDescriptorArray
sel_attributes :: objc.selector("attributes") // Returns MTLVertexAttributeDescriptorArray
// MTLVertexBufferLayoutDescriptorArray and MTLVertexAttributeDescriptorArray use objectAtIndexedSubscript

// MTLVertexBufferLayoutDescriptor selectors
sel_stride :: objc.selector("stride")
sel_setStride :: objc.selector("setStride:")
sel_stepFunction :: objc.selector("stepFunction")
sel_setStepFunction :: objc.selector("setStepFunction:")
sel_stepRate :: objc.selector("stepRate")
sel_setStepRate :: objc.selector("setStepRate:")

// MTLVertexAttributeDescriptor selectors
// sel_format :: objc.selector("format") // Already covered by pixelFormat
// sel_setFormat :: objc.selector("setFormat:")
sel_offset :: objc.selector("offset")
sel_setOffset :: objc.selector("setOffset:")
sel_bufferIndex :: objc.selector("bufferIndex")
sel_setBufferIndex :: objc.selector("setBufferIndex:")


// CAMetalLayer selectors
sel_layer :: objc.selector("layer") // Class method for CAMetalLayer
sel_device :: objc.selector("device") // Property accessor
sel_setDevice :: objc.selector("setDevice:") // Property accessor
sel_pixelFormat :: objc.selector("pixelFormat")
sel_setPixelFormat :: objc.selector("setPixelFormat:")
sel_framebufferOnly :: objc.selector("framebufferOnly")
sel_setFramebufferOnly :: objc.selector("setFramebufferOnly:")
sel_drawableSize :: objc.selector("drawableSize") // Returns CGSize
sel_setDrawableSize :: objc.selector("setDrawableSize:") // Takes CGSize
sel_nextDrawable :: objc.selector("nextDrawable") // Returns id<CAMetalDrawable>

// id<CAMetalDrawable> selectors
sel_texture :: objc.selector("texture") // Returns id<MTLTexture>

// MTLRenderPassDescriptor selectors
sel_colorAttachments :: objc.selector("colorAttachments") // Returns MTLRenderPassColorAttachmentDescriptorArray
// MTLRenderPassColorAttachmentDescriptorArray selectors
sel_objectAtIndexedSubscript :: objc.selector("objectAtIndexedSubscript:") // Access color attachment
// MTLRenderPassColorAttachmentDescriptor selectors
sel_setTexture :: objc.selector("setTexture:")
sel_loadAction :: objc.selector("loadAction")
sel_setLoadAction :: objc.selector("setLoadAction:")
sel_storeAction :: objc.selector("storeAction")
sel_setStoreAction :: objc.selector("setStoreAction:")
sel_clearColor :: objc.selector("clearColor") // Returns MTLClearColor
sel_setClearColor :: objc.selector("setClearColor:") // Takes MTLClearColor

// NSView selectors (for getting the layer)
sel_setWantsLayer :: objc.selector("setWantsLayer:") // Takes BOOL
sel_setLayer :: objc.selector("setLayer:") // Takes CALayer*

// NSString selectors
sel_stringWithUTF8String :: objc.selector("stringWithUTF8String:") // Class method on NSString
sel_UTF8String :: objc.selector("UTF8String") // Instance method, returns const char*

// NSError selectors
sel_localizedDescription :: objc.selector("localizedDescription") // Returns NSString*

// --- Metal Enums (subset, define as needed) ---
MTLPixelFormat :: enum NSUInteger {
    Invalid = 0,
    // Color formats
    BGRA8Unorm = 80,
    BGRA8Unorm_sRGB = 81,
    RGBA8Unorm = 70,
    RGBA8Unorm_sRGB = 71,
    // Depth formats
    Depth32Float = 252,
    Depth24Unorm_Stencil8 = 261, // macOS only
    // Stencil formats
    Stencil8 = 253, // macOS only
}

MTLLoadAction :: enum NSUInteger {
    DontCare = 0,
    Load     = 1,
    Clear    = 2,
}

MTLStoreAction :: enum NSUInteger {
    DontCare = 0,
    Store    = 1,
    MultisampleResolve = 2,
    StoreAndMultisampleResolve = 3, // Not for single sample
    Unknown = 4,
    CustomSampleDepthStore = 5, 
}

MTLPrimitiveType :: enum NSUInteger { // Matches D3D_PRIMITIVE_TOPOLOGY somewhat
    Point = 0,
    Line = 1,
    LineStrip = 2,
    Triangle = 3,
    TriangleStrip = 4,
    // TriangleFan is not directly supported, needs conversion to TriangleList or TriangleStrip
}

MTLResourceOptions :: enum NSUInteger {
    CPUCacheModeDefaultCache  = 0 << 0,
    CPUCacheModeWriteCombined = 1 << 0,

    StorageModeShared  = 0 << 4, // Accessible by both CPU and GPU
    StorageModeManaged = 1 << 4, // macOS only, CPU and GPU maintain separate copies
    StorageModePrivate = 2 << 4, // GPU only
    StorageModeMemoryless = 3 << 4, // iOS/tvOS only, on-tile memory

    HazardTrackingModeDefault = 0 << 8, // Deprecated
    HazardTrackingModeUntracked = 1 << 8,
    HazardTrackingModeTracked = 1 << 9, // New name for default
    // Allow CPU access to the resource - useful for MTLResourceStorageModeManaged
    ResourceCPUCacheModeDefaultCache = CPUCacheModeDefaultCache,
    ResourceCPUCacheModeWriteCombined = CPUCacheModeWriteCombined,
}

MTLIndexType :: enum NSUInteger {
    UInt16 = 0,
    UInt32 = 1,
}

MTLBlendFactor :: enum NSUInteger {
    Zero = 0, One = 1,
    SourceColor = 2, OneMinusSourceColor = 3,
    SourceAlpha = 4, OneMinusSourceAlpha = 5,
    DestinationColor = 6, OneMinusDestinationColor = 7,
    DestinationAlpha = 8, OneMinusDestinationAlpha = 9,
    SourceAlphaSaturated = 10,
    BlendColor = 11, OneMinusBlendColor = 12,
    BlendAlpha = 13, OneMinusBlendAlpha = 14,
    Source1Color = 15, OneMinusSource1Color = 16, // Dual source blending
    Source1Alpha = 17, OneMinusSource1Alpha = 18,
}

MTLBlendOperation :: enum NSUInteger {
    Add = 0, Subtract = 1, ReverseSubtract = 2, Min = 3, Max = 4,
}

MTLColorWriteMask :: enum_flags NSUInteger { // Use enum_flags if Odin supports it on NSUInteger
    None  = 0,
    Red   = 0x1 << 3,
    Green = 0x1 << 2,
    Blue  = 0x1 << 1,
    Alpha = 0x1 << 0,
    All   = Red | Green | Blue | Alpha,
}

MTLPrimitiveTopologyClass :: enum NSUInteger { // For pipeline descriptor
    Unspecified = 0, Point = 1, Line = 2, Triangle = 3,
}

MTLVertexFormat :: enum NSUInteger { // Subset, maps to DXGI_FORMAT somewhat
    Invalid = 0,
    UChar2Normalized = 1, UChar3Normalized = 2, UChar4Normalized = 3, // .ByteN_Norm types
    Char2Normalized = 5, Char3Normalized = 6, Char4Normalized = 7,
    UShort2Normalized = 9, UShort3Normalized = 10, UShort4Normalized = 11,
    Short2Normalized = 13, Short3Normalized = 14, Short4Normalized = 15,
    Half2 = 17, Half3 = 18, Half4 = 19,
    Float = 21, Float2 = 22, Float3 = 23, Float4 = 24,
    Int = 25, Int2 = 26, Int3 = 27, Int4 = 28,
    UInt = 29, UInt2 = 30, UInt3 = 31, UInt4 = 32,
    // Add more as needed
}

MTLVertexStepFunction :: enum NSUInteger {
    Constant = 0,
    PerVertex = 1,
    PerInstance = 2,
    PerPatch = 3, // Tessellation
    PerPatchControlPoint = 4, // Tessellation
}

MTLCompareFunction :: enum NSUInteger { // For depth/stencil
    Never = 0, Less = 1, Equal = 2, LessEqual = 3, Greater = 4, NotEqual = 5, GreaterEqual = 6, Always = 7,
}

MTLStencilOperation :: enum NSUInteger { // For depth/stencil
    Keep = 0, Zero = 1, Replace = 2, IncrementClamp = 3, DecrementClamp = 4, Invert = 5, IncrementWrap = 6, DecrementWrap = 7,
}

MTLCullMode :: enum NSUInteger { None = 0, Front = 1, Back = 2, }
MTLWinding :: enum NSUInteger { Clockwise = 0, CounterClockwise = 1, }
MTLDepthClipMode :: enum NSUInteger { Clip = 0, Clamp = 1, }

// MTLViewport is a struct, not an object handle
MTLViewport :: struct { originX, originY, width, height, znear, zfar: f64 }


// --- Foundation Types (Subset) ---
NSRange :: struct { location: NSUInteger, length: NSUInteger }


// --- Foreign Function for Device Creation ---
@(link_name="MTLCreateSystemDefaultDevice")
MTLCreateSystemDefaultDevice :: proc() -> MTLDevice_Handle --- "c" 
// The "c" calling convention might need to be adjusted if it's an ObjC specific ABI.
// For simple functions returning an object, "c" often works.


// --- Helper Procedures for ObjC interaction ---

// Generic release for any ObjC object handle
objc_release :: proc(obj_handle: id) {
    if obj_handle != nil {
        objc.msg_send(nil, obj_handle, sel_release)
    }
}
// Generic retain (if needed)
objc_retain :: proc(obj_handle: id) -> id {
    if obj_handle != nil {
        return objc.msg_send(id, obj_handle, sel_retain)
    }
    return nil
}

// Get NSString from Odin string
nsstring_from_odin_string :: proc(s: string, allocator := context.allocator) -> NSString_Handle {
    cstr := strings.clone_to_cstring(s, allocator)
    defer delete(cstr, allocator) // Ensure C-string is freed
    
    // Get NSString class
    NSString_class := objc.look_up_class("NSString")
    if NSString_class == nil {
        log.error("Failed to get NSString class.")
        return nil
    }
    return objc.msg_send(NSString_Handle, id(NSString_class), sel_stringWithUTF8String, cstr)
}

nsstring_retain_and_odin_string :: proc(ns_str_autoreleased: NSString_Handle, allocator := context.allocator) -> string {
    if ns_str_autoreleased == nil { return "" }
    // Retain the autoreleased string if we need to hold it longer than current autorelease pool
    // For localizedDescription, it's often okay if we convert immediately.
    // objc_retain(id(ns_str_autoreleased)) // Use with caution
    res := odin_string_from_nsstring(ns_str_autoreleased, allocator)
    // objc_release(id(ns_str_autoreleased)) // Release if retained
    return res
}


// Get Odin string from NSString
odin_string_from_nsstring :: proc(ns_str: NSString_Handle, allocator := context.allocator) -> string {
    if ns_str == nil { return "" }
    utf8_cstr := objc.msg_send(^c.char, id(ns_str), sel_UTF8String)
    if utf8_cstr == nil { return "" }
    return strings.clone_from_cstring(utf8_cstr, allocator)
}

// Get localized description from NSError
nserror_localized_description :: proc(ns_err: NSError_Handle, allocator := context.allocator) -> string {
    if ns_err == nil { return "" }
    // localizedDescription returns an autoreleased NSString.
    desc_ns_str_autoreleased := objc.msg_send(NSString_Handle, id(ns_err), sel_localizedDescription)
    // Convert to Odin string. If the NSString needs to live longer, it should be retained.
    // For immediate conversion, this is usually fine.
    return odin_string_from_nsstring(desc_ns_str_autoreleased, allocator)
}

// MTLClearColor
MTLClearColor :: struct { red, green, blue, alpha: f64 }

// Helper to get class (for class methods like [CAMetalLayer layer])
get_class :: proc(class_name: string) -> id {
    cstr := strings.clone_to_cstring(class_name, context.temp_allocator)
    defer delete(cstr, context.temp_allocator)
    return objc.look_up_class(cstr)
}
