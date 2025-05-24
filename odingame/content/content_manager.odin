package content

import "core:mem"
import "core:log"
import "core:strings"
import "core:path/filepath" 
import "../core" // For ^core.Game, to access services like GraphicsDevice
import "../graphics" // For graphics.Texture2D, graphics.Graphics_Device, graphics.load_texture_from_file, graphics._new_texture2D_from_gfx_texture etc.
import "../common"
import "../gfx_interface" // For gfx_api
import audio "../audio"   // Added for audio types and loading functions

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

    gfx_texture_handle, original_gfx_fmt, err := graphics.load_texture_from_file(low_level_device, full_path, true)
    if err != .None {
        return nil, err 
    }

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
        if strings.has_suffix(cm.root_directory, "/") || strings.has_suffix(cm.root_directory, "\\") {
             full_path = cm.root_directory + normalized_name
        } else {
             full_path = cm.root_directory + "/" + normalized_name
        }
        full_path = filepath.clean(full_path) 
    }

    log.debugf("ContentManager: Attempting to load Texture2D '%s' (normalized) from path '%s'", normalized_name, full_path)
    texture_asset, err := _internal_load_texture2D_from_file(cm, full_path)

    if err != .None || texture_asset == nil {
        return nil, err
    }

    cm._loaded_assets[normalized_name] = rawptr(texture_asset)
    
    log.infof("ContentManager: Texture2D '%s' loaded and cached.", normalized_name)
    return texture_asset, .None
}

// In package content
content_load_sound_effect :: proc(cm: ^Content_Manager, asset_name: string) -> (effect: audio.SoundEffect, err: common.Engine_Error) {
    if cm == nil { return audio.SoundEffect(nil), .Invalid_Parameter }
    
    normalized_name := _normalize_asset_name(asset_name)
    
    if loaded_asset_ptr, found := cm._loaded_assets[normalized_name]; found {
        // Assume it's a SoundEffect if found under this loading path.
        return audio.SoundEffect(loaded_asset_ptr), .None
    }

    full_path: string
    if cm.root_directory == "" || cm.root_directory == "." || filepath.is_abs(normalized_name) {
        full_path = normalized_name
    } else {
        if strings.has_suffix(cm.root_directory, "/") || strings.has_suffix(cm.root_directory, "\\") {
             full_path = cm.root_directory + normalized_name
        } else {
             full_path = cm.root_directory + "/" + normalized_name
        }
        full_path = filepath.clean(full_path)
    }

    log.debugf("ContentManager: Attempting to load SoundEffect '%s' from path '%s'", normalized_name, full_path)
    
    maybe_effect := audio.load_sound_effect(full_path) 

    if !maybe_effect.ok {
        log.errorf("ContentManager: Failed to load SoundEffect '%s'.", normalized_name)
        return audio.SoundEffect(nil), .Sound_Loading_Failed 
    }

    cm._loaded_assets[normalized_name] = rawptr(maybe_effect.value) 
    // Note: audio.SoundEffect is already a rawptr (distinct mix.Chunk_Handle)

    log.infof("ContentManager: SoundEffect '%s' loaded and cached.", normalized_name)
    return maybe_effect.value, .None
}

// In package content
content_load_music :: proc(cm: ^Content_Manager, asset_name: string) -> (music: audio.Music, err: common.Engine_Error) {
    if cm == nil { return audio.Music(nil), .Invalid_Parameter }
    
    normalized_name := _normalize_asset_name(asset_name)
    
    if loaded_asset_ptr, found := cm._loaded_assets[normalized_name]; found {
        return audio.Music(loaded_asset_ptr), .None
    }

    full_path: string
    if cm.root_directory == "" || cm.root_directory == "." || filepath.is_abs(normalized_name) {
        full_path = normalized_name
    } else {
        if strings.has_suffix(cm.root_directory, "/") || strings.has_suffix(cm.root_directory, "\\") {
             full_path = cm.root_directory + normalized_name
        } else {
             full_path = cm.root_directory + "/" + normalized_name
        }
        full_path = filepath.clean(full_path)
    }
    
    log.debugf("ContentManager: Attempting to load Music '%s' from path '%s'", normalized_name, full_path)

    maybe_music := audio.load_music(full_path)

    if !maybe_music.ok {
        log.errorf("ContentManager: Failed to load Music '%s'.", normalized_name)
        return audio.Music(nil), .Sound_Loading_Failed 
    }

    cm._loaded_assets[normalized_name] = rawptr(maybe_music.value)
    // Note: audio.Music is already a rawptr (distinct mix.Music_Handle)

    log.infof("ContentManager: Music '%s' loaded and cached.", normalized_name)
    return maybe_music.value, .None
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
        }
    }
    clear(&cm._disposable_assets)

    // HACK: Iterate _loaded_assets. Guess type by extension for unloading.
    // This is not robust. A proper system would store asset types or use separate maps.
    for asset_name, asset_ptr in cm._loaded_assets {
        log.debugf("ContentManager: Attempting to unload asset '%s' (%p)", asset_name, asset_ptr)
        
        unloaded := false
        if strings.has_suffix(asset_name, ".png") || strings.has_suffix(asset_name, ".jpg") || 
           strings.has_suffix(asset_name, ".bmp") || strings.has_suffix(asset_name, ".tga") {
            
            tex2d_asset := (^graphics.Texture2D)(asset_ptr) 
            if tex2d_asset != nil { 
                graphics.texture2D_dispose(tex2d_asset) 
                if tex2d_asset._gfx_texture.variant != nil {
                    can_destroy_gpu_resource := cm.game_ref != nil && cm.game_ref.graphics_device_manager != nil &&
                                           cm.game_ref.graphics_device_manager.graphics_device != nil &&
                                           cm.game_ref.graphics_device_manager.graphics_device._gfx_device.variant != nil
                    if can_destroy_gpu_resource {
                        gfx_api.destroy_texture(tex2d_asset._gfx_texture) 
                    } else {
                        log.errorf("ContentManager: Cannot destroy _gfx_texture for '%s', Graphics_Device not available.", asset_name)
                    }
                }
                free(tex2d_asset, cm.allocator) 
                unloaded = true
                log.debugf("ContentManager: Unloaded texture asset '%s'.", asset_name)
            } else {
                 log.warnf("ContentManager: Asset '%s' (assumed Texture2D) was nil after cast.", asset_name)
            }
        } else if strings.has_suffix(asset_name, ".wav") {
            log.debugf("ContentManager: Assuming '%s' is SoundEffect, attempting to unload.", asset_name)
            effect_handle := audio.SoundEffect(asset_ptr)
            audio.destroy_sound_effect(effect_handle) 
            unloaded = true
            log.debugf("ContentManager: Unloaded sound effect asset '%s'.", asset_name)
        } else if strings.has_suffix(asset_name, ".ogg") || strings.has_suffix(asset_name, ".mp3") {
             log.debugf("ContentManager: Assuming '%s' is Music, attempting to unload.", asset_name)
             music_handle := audio.Music(asset_ptr)
             audio.destroy_music(music_handle) 
             unloaded = true
             log.debugf("ContentManager: Unloaded music asset '%s'.", asset_name)
        }
        
        if !unloaded {
            log.warnf("ContentManager: Asset '%s' (%p) was not unloaded. Type unknown or unload not implemented for this type.", asset_name, asset_ptr)
        }
    }
    clear(&cm._loaded_assets) 

    log.info("ContentManager: Finished attempting to unload all assets. Some may have been skipped if type was unknown.")
}


// Generic content_load (conceptual for now)
// SKIPPED update for this subtask due to type complexities with ^T for rawptr handle types.
content_load :: proc(cm: ^Content_Manager, $T: typeid, asset_name: string) -> (asset: ^T, err: common.Engine_Error) {
    #partial switch T {
    case graphics.Texture2D:
        tex, load_err := content_load_texture2D(cm, asset_name)
        return tex, load_err 
    // case audio.Sound_Effect:
    //     // This would require returning ^audio.SoundEffect, but audio.SoundEffect is rawptr.
    //     // Would need to allocate memory for the rawptr and return a pointer to that.
    //     effect, load_err := content_load_sound_effect(cm, asset_name)
    //     if load_err == .None {
    //         // ptr_to_effect := new(audio.SoundEffect, cm.allocator)
    //         // ptr_to_effect^ = effect
    //         // return ptr_to_effect, .None
    //         // This approach complicates unloading and ownership.
    //     }
    //     // Fallthrough to unsupported for now
    // case audio.Music:
    //     // Similar issue as SoundEffect
    //     // Fallthrough to unsupported for now
    case:
        log.errorf("Content_Manager: Generic content_load: Asset type %v not supported for asset '%s'", T, asset_name)
        return nil, .Resource_Not_Found // Or a more specific "type not supported by generic load" error
    }
}
