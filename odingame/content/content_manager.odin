package content

import "core:mem"
import "core:log"
import "core:strings"
import "core:path/filepath" 
import "../core" // For ^core.Game, to access services like GraphicsDevice
import "../graphics" // For graphics.Texture2D, graphics.Graphics_Device, graphics.load_texture_from_file, graphics._new_texture2D_from_gfx_texture etc.
import "../common"
import "../gfx_interface" // For gfx_api

// IDisposable interface
IDisposable :: interface {
    dispose: proc(self: ^IDisposable), 
}

Content_Manager :: struct {
    game_ref:          ^core.Game, 
    root_directory:    string,
    _loaded_assets:    map[string]rawptr, 
    _disposable_assets: [dynamic]^IDisposable, // For generic disposable items, not explicitly used for Texture2D yet
    allocator:         mem.Allocator,
}

// --- Constructor and Destructor ---
new_content_manager :: proc(
    game: ^core.Game, 
    root_dir: string, 
    alloc: mem.Allocator = context.allocator,
) -> ^Content_Manager {
    cm := new(Content_Manager, alloc)
    cm.game_ref = game
    cm.root_directory = filepath.clean(root_dir) 
    cm.allocator = alloc
    
    cm._loaded_assets = make(map[string]rawptr, alloc)
    cm._disposable_assets = make([dynamic]^IDisposable, 0, 16, alloc)

    log.infof("ContentManager initialized with root directory: '%s'", cm.root_directory)
    return cm
}

destroy_content_manager :: proc(cm: ^Content_Manager) {
    if cm == nil { return }
    log.info("Destroying ContentManager...")
    content_unload_all(cm) 
    
    delete(cm._loaded_assets)    
    delete(cm._disposable_assets) 

    free(cm, cm.allocator)
    log.info("ContentManager destroyed.")
}

// --- Asset Loading ---
_normalize_asset_name :: proc(asset_name: string) -> string {
    return strings.replace_all(asset_name, "\\", "/")
}

_internal_load_texture2D_from_file :: proc(
    cm: ^Content_Manager, 
    full_path: string, 
) -> (^graphics.Texture2D, common.Engine_Error) {
    
    if cm.game_ref == nil || cm.game_ref.graphics_device_manager == nil || 
       cm.game_ref.graphics_device_manager.graphics_device == nil {
        log.errorf("_internal_load_texture2D_from_file: Graphics_Device not available for path '%s'. Game or GDM is nil.", full_path)
        return nil, .Invalid_Operation
    }
    gd_wrapper := cm.game_ref.graphics_device_manager.graphics_device
    if gd_wrapper == nil || gd_wrapper._gfx_device.variant == nil {
         log.errorf("_internal_load_texture2D_from_file: Graphics_Device._gfx_device is invalid for path '%s'", full_path)
        return nil, .Invalid_Handle
    }
    low_level_device := gd_wrapper._gfx_device

    // Call the updated graphics.load_texture_from_file which returns (Gfx_Texture, original_format, error)
    gfx_texture_handle, original_gfx_fmt, err := graphics.load_texture_from_file(low_level_device, full_path, true)
    if err != .None {
        // Error already logged by graphics.load_texture_from_file or its callees
        return nil, err 
    }

    // Gfx_Texture from gfx_interface might not have mip_levels directly.
    // Assuming it's 1 if not generated, or CreateTexture stores it.
    // For now, default to 1. The create_texture might need to return this.
    // The `gfx_interface.Gfx_Texture` struct definition itself has `width, height, format, mip_levels`.
    num_mip_levels := gfx_texture_handle.mip_levels
    if num_mip_levels == 0 { num_mip_levels = 1 }


    tex2d := graphics._new_texture2D_from_gfx_texture(
        gd_wrapper, 
        gfx_texture_handle,
        gfx_texture_handle.width, 
        gfx_texture_handle.height,
        original_gfx_fmt, 
        num_mip_levels, 
        cm.allocator,
    )
    
    return tex2d, .None
}

content_load_texture2D :: proc(cm: ^Content_Manager, asset_name: string) -> (^graphics.Texture2D, common.Engine_Error) {
    if cm == nil { return nil, .Invalid_Parameter }
    
    normalized_name := _normalize_asset_name(asset_name)
    
    if loaded_asset_ptr, found := cm._loaded_assets[normalized_name]; found {
        return (^graphics.Texture2D)(loaded_asset_ptr), .None
    }

    full_path: string
    if cm.root_directory == "" || cm.root_directory == "." || filepath.is_abs(normalized_name) {
        full_path = normalized_name
    } else {
        full_path = filepath.join({cm.root_directory, normalized_name}, cm.allocator)
        // Simpler join if filepath.join is problematic with temp allocators or styles:
        // full_path = strings.concatenate({cm.root_directory, "/", normalized_name}, cm.allocator)
        // For now, assume filepath.join works as expected or paths are simple.
        // If using temp allocator for join, defer free. For now, assume cm.allocator is okay or path is not too long for stack.
        // Let's use a simpler join for now:
        if strings.has_suffix(cm.root_directory, "/") || strings.has_suffix(cm.root_directory, "\\") {
             full_path = cm.root_directory + normalized_name
        } else {
             full_path = cm.root_directory + "/" + normalized_name
        }
        full_path = filepath.clean(full_path) // Clean the joined path
    }


    log.debugf("ContentManager: Attempting to load Texture2D '%s' (normalized) from path '%s'", normalized_name, full_path)
    texture_asset, err := _internal_load_texture2D_from_file(cm, full_path)

    // If filepath.join allocated memory for full_path, it should be freed here if necessary.
    // If using the simpler concatenation, no free needed for full_path itself unless root_directory or asset_name were allocated.

    if err != .None || texture_asset == nil {
        return nil, err
    }

    cm._loaded_assets[normalized_name] = rawptr(texture_asset)
    
    // IDisposable handling:
    // Texture2D is expected to have a dispose method. If it were a generic IDisposable system:
    // if disp_iface, ok := (^IDisposable)(rawptr(texture_asset)); ok { // This cast is potentially unsafe / needs care
    //     append(&cm._disposable_assets, disp_iface)
    // }
    // For now, type-specific handling in UnloadAll is safer.

    log.infof("ContentManager: Texture2D '%s' loaded and cached.", normalized_name)
    return texture_asset, .None
}

// --- Asset Unloading ---
content_unload_all :: proc(cm: ^Content_Manager) {
    if cm == nil { return }
    log.info("ContentManager: Unloading all assets...")

    // Dispose IDisposable assets (generic path, not used for Texture2D in this simplified version)
    for i := len(cm._disposable_assets) - 1; i >= 0; i -= 1 {
        disposable_asset := cm._disposable_assets[i]
        if disposable_asset != nil {
            // This requires the pointer stored to be directly callable as ^IDisposable
            // disposable_asset.dispose() // This line requires IDisposable to be a concrete type or careful casting.
            // For now, this loop is conceptual.
        }
    }
    clear(&cm._disposable_assets)

    // Iterate all loaded assets and dispose/free them based on known types
    for asset_name, asset_ptr in cm._loaded_assets {
        log.debugf("ContentManager: Unloading asset '%s' (%p)", asset_name, asset_ptr)
        
        // For now, assume all loaded assets are ^graphics.Texture2D
        tex2d_asset := (^graphics.Texture2D)(asset_ptr)
        if tex2d_asset != nil {
            // 1. Call the Texture2D's own dispose method (marks as disposed)
            graphics.texture2D_dispose(tex2d_asset) 
            
            // 2. Explicitly destroy the underlying Gfx_Texture GPU resource
            if tex2d_asset._gfx_texture.variant != nil {
                can_destroy_gpu_resource := false
                if cm.game_ref != nil && cm.game_ref.graphics_device_manager != nil &&
                   cm.game_ref.graphics_device_manager.graphics_device != nil &&
                   cm.game_ref.graphics_device_manager.graphics_device._gfx_device.variant != nil {
                    can_destroy_gpu_resource = true
                }

                if can_destroy_gpu_resource {
                    // destroy_texture from graphics/texture.odin takes Gfx_Texture by value
                    // and handles ref counting for GL. For DX, it's direct release.
                    // The gfx_api.destroy_texture is the one to call.
                    gfx_api.destroy_texture(tex2d_asset._gfx_texture) 
                } else {
                    log.errorf("ContentManager: Cannot destroy _gfx_texture for '%s', Graphics_Device not available during unload.", asset_name)
                }
            }
            // 3. Free the Texture2D struct itself (allocated by ContentManager)
            free(tex2d_asset, cm.allocator) 
        }
    }
    clear(&cm._loaded_assets) 

    log.info("ContentManager: All assets unloaded.")
}


// Generic content_load (conceptual for now)
content_load :: proc(cm: ^Content_Manager, $T: typeid, asset_name: string) -> (asset: ^T, err: common.Engine_Error) {
    #partial switch T {
    case graphics.Texture2D:
        // This cast is okay because content_load_texture2D returns ^graphics.Texture2D
        tex, load_err := content_load_texture2D(cm, asset_name)
        return tex, load_err
    // case audio.Sound_Effect:
    //     return content_load_sound_effect(cm, asset_name)
    // ... other types
    case:
        log.errorf("Content_Manager: Cannot load asset of type %v for asset '%s'", T, asset_name)
        return nil, .Unsupported_Asset_Type
    }
}
