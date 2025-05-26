package assets

import "src:core" // For logging
import "core:strings" // For strings.clone used by create_base_asset
import "src:sdl"    // For SDL types used in UpdateAssetManager and _ProcessUnload
import "core:reflect" // For type_info_of in GetSpecificAsset

// Asset, AssetID, etc. are available as they are in the same 'assets' package.

// AssetManager orchestrates loading, unloading, and tracking of game assets.
AssetManager :: struct {
	assets_by_id:    map[AssetID]Any, // Stores ^TextureAsset, ^SoundAsset, etc.
	
	assets_by_path:  map[string]AssetID,
	next_asset_raw_id: u64,
	unloading_pending_ids: map[AssetID]bool, 
}

// CreateAssetManager initializes a new asset manager.
CreateAssetManager :: proc() -> ^AssetManager {
	core.LogInfo("[Assets] Creating Asset Manager...")
	manager := new(AssetManager)
	
	manager.assets_by_id = make(map[AssetID]Any) 
	manager.assets_by_path = make(map[string]AssetID)
	manager.next_asset_raw_id = 1 
	manager.unloading_pending_ids = make(map[AssetID]bool) 
	
	core.LogInfo("[Assets] Asset Manager created.")
	return manager
}

// DestroyAssetManager cleans up the asset manager and all loaded assets.
DestroyAssetManager :: proc(manager: ^AssetManager) {
	if manager == nil { return }
	core.LogInfo("[Assets] Destroying Asset Manager...")

    all_ids_to_check_for_full_unload := make(map[AssetID]bool)
    defer delete(all_ids_to_check_for_full_unload) 

    for id := range manager.assets_by_id {
        all_ids_to_check_for_full_unload[id] = true
    }
    for id := range manager.unloading_pending_ids {
        all_ids_to_check_for_full_unload[id] = true
    }

    if len(all_ids_to_check_for_full_unload) > 0 {
        core.LogInfoFmt("[Assets] DestroyAssetManager: Ensuring full unload of %d unique asset IDs...", len(all_ids_to_check_for_full_unload))
        for id := range all_ids_to_check_for_full_unload {
            _ProcessUnload(manager, id) 
        }
    }

	delete(manager.assets_by_id)    
	delete(manager.assets_by_path)  
	delete(manager.unloading_pending_ids)
	
	free(manager) 
	core.LogInfo("[Assets] Asset Manager destroyed.")
}

// _GenerateNewAssetID creates a new unique AssetID.
@(private="assets.AssetManager._GenerateNewAssetID")
_GenerateNewAssetID :: proc(manager: ^AssetManager) -> AssetID {
	new_id_val := manager.next_asset_raw_id
	manager.next_asset_raw_id += 1
	return AssetID(new_id_val)
}

// create_base_asset_ptr is removed. create_base_asset (from asset.odin) is used.

// LoadAsset:
LoadAsset :: proc(manager: ^AssetManager, path: string, type: AssetType) -> AssetID {
	if manager == nil || path == "" {
		core.LogError("[Assets] LoadAsset: Nil manager or empty path provided.")
		return ASSET_ID_NIL
	}

	if existing_id, ok := manager.assets_by_path[path]; ok {
		if asset_any, asset_exists := manager.assets_by_id[existing_id]; asset_exists {
			base_asset_ptr := cast(^Asset)asset_any 
			if base_asset_ptr != nil {
				base_asset_ptr.ref_count += 1
				core.LogInfoFmt("[Assets] LoadAsset: Path '%s' (ID: %v) already known. Incremented ref_count to %d.", path, existing_id, base_asset_ptr.ref_count)
                delete_key(&manager.unloading_pending_ids, existing_id)
				return existing_id
			} else {
				core.LogErrorFmt("[Assets] LoadAsset: Path '%s' (ID: %v) found, but asset data in assets_by_id is invalid.", path, existing_id)
				return existing_id 
			}
		} else {
			core.LogErrorFmt("[Assets] LoadAsset: Inconsistency for path '%s'. ID %v in path map but not ID map. Removing stale path entry.", path, existing_id)
			delete_key(&manager.assets_by_path, path)
		}
	}

	new_id := _GenerateNewAssetID(manager)
	if new_id == ASSET_ID_NIL {
		core.LogErrorFmt("[Assets] LoadAsset: Failed to generate new AssetID for path '%s'.", path)
		return ASSET_ID_NIL
	}
	
	manager.assets_by_path[path] = new_id
	
	var new_specific_asset_any: Any
	switch type {
	case .TEXTURE:
        temp_tex_asset := new(TextureAsset)
        temp_tex_asset.base = create_base_asset(new_id, path, type) 
        temp_tex_asset.base.ref_count = 1
        temp_tex_asset.base.state = .UNLOADED
        new_specific_asset_any = temp_tex_asset
	case .SOUND:
        temp_sound_asset := new(SoundAsset)
        temp_sound_asset.base = create_base_asset(new_id, path, type)
        temp_sound_asset.base.ref_count = 1
        temp_sound_asset.base.state = .UNLOADED
        new_specific_asset_any = temp_sound_asset
    case .MUSIC:
        temp_music_asset := new(MusicAsset)
        temp_music_asset.base = create_base_asset(new_id, path, type)
        temp_music_asset.base.ref_count = 1
        temp_music_asset.base.state = .UNLOADED
        new_specific_asset_any = temp_music_asset
	default:
		core.LogErrorFmt("[Assets] LoadAsset: Unknown or unsupported asset type %v for path '%s'.", type, path)
		delete_key(&manager.assets_by_path, path) 
		return ASSET_ID_NIL
	}

	if new_specific_asset_any != nil {
		manager.assets_by_id[new_id] = new_specific_asset_any
		core.LogInfoFmt("[Assets] LoadAsset: New asset '%s' (Type: %v) registered. ID: %v. State: UNLOADED. Ref_count: 1.", path, type, new_id)
		return new_id
	} else {
		core.LogErrorFmt("[Assets] LoadAsset: Failed to create specific asset shell for path '%s'.", path)
		delete_key(&manager.assets_by_path, path)
		return ASSET_ID_NIL
	}
}

// GetAsset:
GetAsset :: proc(manager: ^AssetManager, id: AssetID) -> (^Asset, bool) {
	if manager == nil { return nil, false }
	if id == ASSET_ID_NIL { return nil, false }

	asset_any, ok := manager.assets_by_id[id]
	if !ok { return nil, false }
	
	base_asset_ptr := cast(^Asset)asset_any 
	if base_asset_ptr == nil { 
		core.LogErrorFmt("[Assets] GetAsset: AssetID %v found but data is not castable to ^Asset.", id)
		return nil, false
	}
	return base_asset_ptr, true
}

// GetSpecificAsset:
GetSpecificAsset :: proc(manager: ^AssetManager, id: AssetID, T: typeid) -> (rawptr, bool) {
	asset_base_ptr, base_ok := GetAsset(manager, id) 
	if !base_ok { return nil, false }

	if asset_base_ptr.state != .LOADED {
		return nil, false
	}
	
	specific_asset_any := manager.assets_by_id[id] 
    
    expected_asset_type : AssetType = .UNKNOWN
    #partial switch ti_id in type_info_of(T).id { 
        case type_info_of(TextureAsset).id: expected_asset_type = .TEXTURE
        case type_info_of(SoundAsset).id: expected_asset_type = .SOUND
        case type_info_of(MusicAsset).id: expected_asset_type = .MUSIC
    }

    if expected_asset_type == .UNKNOWN || asset_base_ptr.type != expected_asset_type {
        core.LogWarningFmt("[Assets] GetSpecificAsset: AssetID %v (Path: %s). Requested type %v does not match asset's actual type %v.", id, asset_base_ptr.path, T, asset_base_ptr.type)
        return nil, false
    }
    
	return specific_asset_any, true 
}

// UnloadAsset decrements the reference count of an asset.
UnloadAsset :: proc(manager: ^AssetManager, id: AssetID) {
	if manager == nil {
		core.LogError("[Assets] UnloadAsset: Nil manager provided.")
		return
	}
	if id == ASSET_ID_NIL {
		core.LogWarning("[Assets] UnloadAsset: Attempted to unload ASSET_ID_NIL.")
		return
	}

	asset_base_ptr, ok := GetAsset(manager, id) 
	if !ok {
		core.LogWarningFmt("[Assets] UnloadAsset: AssetID %v not found in manager (or data invalid). Cannot decrement ref_count.", id)
		return
	}

	if asset_base_ptr.ref_count == 0 {
		core.LogWarningFmt("[Assets] UnloadAsset: AssetID %v (Path: %s) already has ref_count == 0.", id, asset_base_ptr.path)
		if !manager.unloading_pending_ids[id] {
			manager.unloading_pending_ids[id] = true
		}
		return
	}

	asset_base_ptr.ref_count -= 1
	core.LogInfoFmt("[Assets] UnloadAsset: Decremented ref_count for AssetID %v (Path: %s) to %d.", id, asset_base_ptr.path, asset_base_ptr.ref_count)

	if asset_base_ptr.ref_count == 0 {
		manager.unloading_pending_ids[id] = true
		core.LogInfoFmt("[Assets] UnloadAsset: AssetID %v (Path: %s) ref_count reached 0. Marked as pending unload.", id, asset_base_ptr.path)
	}
}

// _ProcessUnload:
@(private="assets.AssetManager._ProcessUnload")
_ProcessUnload :: proc(manager: ^AssetManager, id: AssetID) {
	asset_any, found_in_active := manager.assets_by_id[id]
	
	if !found_in_active {
        delete_key(&manager.unloading_pending_ids, id)
		return
	}

    base_asset_ptr := cast(^Asset)asset_any
    if base_asset_ptr == nil { 
        core.LogErrorFmt("[Assets] _ProcessUnload: AssetID %v data is invalid/nil.", id)
        delete_key(&manager.assets_by_id, id) 
        delete_key(&manager.unloading_pending_ids, id)
        return
    }

	core.LogInfoFmt("[Assets] _ProcessUnload: Fully unloading AssetID %v (Path: %s, Type: %v, State: %v)", id, base_asset_ptr.path, base_asset_ptr.type, base_asset_ptr.state)

	switch base_asset_ptr.type {
	case .TEXTURE:
		tex_asset := cast(^TextureAsset)asset_any 
		if tex_asset != nil && tex_asset.sdl_texture != nil {
			sdl.SDL_DestroyTexture(tex_asset.sdl_texture)
			core.LogInfoFmt("[Assets] _ProcessUnload: Freed SDL_Texture for %s", base_asset_ptr.path)
		}
	case .SOUND:
		sound_asset := cast(^SoundAsset)asset_any
		if sound_asset != nil && sound_asset.mix_chunk != nil {
			sdl.Mix_FreeChunk(sound_asset.mix_chunk) 
			core.LogInfoFmt("[Assets] _ProcessUnload: Freed Mix_Chunk for %s", base_asset_ptr.path)
		}
    case .MUSIC:
        music_asset := cast(^MusicAsset)asset_any
        if music_asset != nil && music_asset.mix_music != nil {
            sdl.Mix_FreeMusic(music_asset.mix_music) 
            core.LogInfoFmt("[Assets] _ProcessUnload: Freed Mix_Music for %s", base_asset_ptr.path)
        }
	default:
		core.LogWarningFmt("[Assets] _ProcessUnload: No specific unload logic for asset type %v (Path: %s)", base_asset_ptr.type, base_asset_ptr.path)
	}

	delete(base_asset_ptr.path) 

	delete_key(&manager.assets_by_path, base_asset_ptr.path) 
	delete_key(&manager.assets_by_id, id)
	delete_key(&manager.unloading_pending_ids, id)

	free(asset_any) 

	core.LogInfoFmt("[Assets] _ProcessUnload: AssetID %v fully deallocated.", id)
}

// _ProcessUnloadingQueue:
_ProcessUnloadingQueue :: proc(manager: ^AssetManager) {
	if manager == nil { return }
	if len(manager.unloading_pending_ids) == 0 { return }

	core.LogInfoFmt("[Assets] Processing %d assets in unloading queue...", len(manager.unloading_pending_ids))
	
	ids_to_process := make([dynamic]AssetID, 0, len(manager.unloading_pending_ids))
	defer delete(ids_to_process) 
	for id := range manager.unloading_pending_ids {
		append(&ids_to_process, id)
	}

	for id in ids_to_process {
        if manager.unloading_pending_ids[id] { 
		    _ProcessUnload(manager, id)
        }
	}
}

// UpdateAssetManager:
UpdateAssetManager :: proc(manager: ^AssetManager, renderer_for_textures: ^sdl.Renderer) {
	if manager == nil { return }

	ids_to_check_loading := make([dynamic]AssetID, 0, len(manager.assets_by_id))
	defer delete(ids_to_check_loading)
	for id, asset_any in manager.assets_by_id {
		base_asset_ptr := cast(^Asset)asset_any 
		if base_asset_ptr != nil && base_asset_ptr.state == .UNLOADED {
			append(&ids_to_check_loading, id)
		}
	}

	if len(ids_to_check_loading) > 0 {
		core.LogInfoFmt("[Assets] UpdateAssetManager: Checking %d UNLOADED assets for loading...", len(ids_to_check_loading))
		for asset_id_to_load in ids_to_check_loading {
			asset_any_shell := manager.assets_by_id[asset_id_to_load] 
			base_asset_shell_ptr := cast(^Asset)asset_any_shell
			
			base_asset_shell_ptr.state = .LOADING
			core.LogInfoFmt("[Assets] Update: Attempting to load ID %v, Path: %s, Type: %v", asset_id_to_load, base_asset_shell_ptr.path, base_asset_shell_ptr.type)

			var loaded_asset_any: Any
			var success_flag: bool

			switch base_asset_shell_ptr.type {
			case .TEXTURE:
				loaded_tex_asset, tex_ok := LoadTextureFromFile(asset_id_to_load, base_asset_shell_ptr.path, renderer_for_textures)
				if tex_ok { 
                    // Ensure ref_count from shell is preserved or correctly set by loader
                    loaded_tex_asset.base.ref_count = base_asset_shell_ptr.ref_count
                    loaded_asset_any = loaded_tex_asset
                    success_flag = true 
                }
			case .SOUND:
				loaded_sound_asset, sound_ok := LoadSoundFromFile(asset_id_to_load, base_asset_shell_ptr.path)
				if sound_ok { 
                    loaded_sound_asset.base.ref_count = base_asset_shell_ptr.ref_count
                    loaded_asset_any = loaded_sound_asset
                    success_flag = true 
                }
            case .MUSIC:
                loaded_music_asset, music_ok := LoadMusicFromFile(asset_id_to_load, base_asset_shell_ptr.path)
                if music_ok { 
                    loaded_music_asset.base.ref_count = base_asset_shell_ptr.ref_count
                    loaded_asset_any = loaded_music_asset
                    success_flag = true
                }
			default:
				core.LogErrorFmt("[Assets] Update: Unknown type %v for asset ID %v, path %s", base_asset_shell_ptr.type, asset_id_to_load, base_asset_shell_ptr.path)
				base_asset_shell_ptr.state = .FAILED
				continue 
			}

			if success_flag {
				delete(base_asset_shell_ptr.path) 
				free(asset_any_shell)             
				
				manager.assets_by_id[asset_id_to_load] = loaded_asset_any
				
				new_base_ptr := cast(^Asset)loaded_asset_any
				new_base_ptr.state = .LOADED
                // new_base_ptr.ref_count is already set from shell's ref_count

				core.LogInfoFmt("[Assets] Update: Successfully loaded ID %v, Path: %s", asset_id_to_load, new_base_ptr.path)
			} else {
				base_asset_shell_ptr.state = .FAILED
				core.LogErrorFmt("[Assets] Update: Failed to load ID %v, Path: %s", asset_id_to_load, base_asset_shell_ptr.path)
			}
		}
	}

	_ProcessUnloadingQueue(manager)
}
