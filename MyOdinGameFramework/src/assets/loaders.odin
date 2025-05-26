package assets

import "src:core"
import "src:sdl" // For SDL_Texture, Mix_Chunk, and renderer/audio context
import "core:strings" // For strings.clone_to_cstring

// Asset, AssetID, AssetType etc. are available from asset.odin in the same package.

// --- Specific Asset Type Definitions ---

// TextureAsset holds data for a loaded texture.
TextureAsset :: struct {
	// Embed the base Asset struct. Must be the first member for easy casting to ^Asset.
	base:        Asset, 
	
	sdl_texture: ^sdl.SDL_Texture, // Pointer to the actual SDL texture resource
	width:       i32,
	height:      i32,
}

// SoundAsset holds data for a loaded sound effect (Mix_Chunk).
SoundAsset :: struct {
	// Embed the base Asset struct.
	base:      Asset,
	
	mix_chunk: ^sdl.Mix_Chunk, // Pointer to the actual SDL_mixer chunk
	// volume: f32, // Default volume, or managed elsewhere
}

// MusicAsset holds data for a loaded music track (Mix_Music).
MusicAsset :: struct {
    base: Asset,
    mix_music: ^sdl.Mix_Music,
}


// --- Asset Loading Procedures ---

// LoadTextureFromFile loads a texture from a file using SDL_image.
// It requires an SDL_Renderer to create the texture.
// Returns a pointer to a new TextureAsset or nil on failure.
LoadTextureFromFile :: proc(asset_id: AssetID, path: string, renderer: ^sdl.Renderer) -> (^TextureAsset, bool) {
	if path == "" || renderer == nil {
		core.LogError("[Loader] LoadTextureFromFile: Empty path or nil renderer.")
		return nil, false
	}

	core.LogInfoFmt("[Loader] Loading texture from path: %s (AssetID: %v)", path, asset_id)
	
	path_cstr := strings.clone_to_cstring(path)
	defer delete(path_cstr) // Clean cstring path

	sdl_tex := sdl.IMG_LoadTexture(renderer, path_cstr) 

	if sdl_tex == nil {
		error_msg := sdl.SDL_GetError() 
		core.LogErrorFmt("[Loader] Failed to load texture '%s': %s", path, error_msg)
		return nil, false
	}

	width, height: i32
	query_result := sdl.SDL_QueryTexture(sdl_tex, nil, nil, &width, &height)
	if query_result < 0 {
		error_msg := sdl.SDL_GetError()
		core.LogWarningFmt("[Loader] Failed to query texture dimensions for '%s': %s. Using 0,0.", path, error_msg)
		width = 0
		height = 0
	}

	tex_asset := new(TextureAsset)
	// The path string in tex_asset.base.path will be the canonical one, cloned by create_base_asset.
	tex_asset.base = create_base_asset(asset_id, path, .TEXTURE) 
	tex_asset.sdl_texture = sdl_tex
	tex_asset.width = width
	tex_asset.height = height
	
	core.LogInfoFmt("[Loader] Texture '%s' loaded successfully. Dimensions: %dx%d", path, width, height)
	return tex_asset, true
}


// LoadSoundFromFile loads a sound effect from a file using SDL_mixer.
// Returns a pointer to a new SoundAsset or nil on failure.
LoadSoundFromFile :: proc(asset_id: AssetID, path: string) -> (^SoundAsset, bool) {
	if path == "" {
		core.LogError("[Loader] LoadSoundFromFile: Empty path.")
		return nil, false
	}
	core.LogInfoFmt("[Loader] Loading sound from path: %s (AssetID: %v)", path, asset_id)

	path_cstr := strings.clone_to_cstring(path)
	defer delete(path_cstr) 

	mix_chk := sdl.Mix_LoadWAV(path_cstr) 

	if mix_chk == nil {
		error_msg := sdl.SDL_GetError() 
		core.LogErrorFmt("[Loader] Failed to load sound '%s': %s", path, error_msg)
		return nil, false
	}

	sound_asset := new(SoundAsset)
	sound_asset.base = create_base_asset(asset_id, path, .SOUND) 
	sound_asset.mix_chunk = mix_chk
	
	core.LogInfoFmt("[Loader] Sound '%s' loaded successfully.", path)
	return sound_asset, true
}

// LoadMusicFromFile loads a music track from a file using SDL_mixer.
// Returns a pointer to a new MusicAsset or nil on failure.
LoadMusicFromFile :: proc(asset_id: AssetID, path: string) -> (^MusicAsset, bool) {
    if path == "" {
        core.LogError("[Loader] LoadMusicFromFile: Empty path.")
        return nil, false
    }
    core.LogInfoFmt("[Loader] Loading music from path: %s (AssetID: %v)", path, asset_id)

    path_cstr := strings.clone_to_cstring(path)
    defer delete(path_cstr)

    mix_mus_ptr := sdl.Mix_LoadMUS(path_cstr)

    if mix_mus_ptr == nil {
        error_msg := sdl.SDL_GetError()
        core.LogErrorFmt("[Loader] Failed to load music '%s': %s", path, error_msg)
        return nil, false
    }

    music_asset := new(MusicAsset)
    music_asset.base = create_base_asset(asset_id, path, .MUSIC)
    music_asset.mix_music = mix_mus_ptr

    core.LogInfoFmt("[Loader] Music '%s' loaded successfully.", path)
    return music_asset, true
}


// Note: SDL_image and SDL_mixer initialization (IMG_Init, Mix_Init, Mix_OpenAudio)
// and foreign function definitions (IMG_LoadTexture, Mix_LoadWAV, SDL_QueryTexture)
// need to be added to sdl_context.odin and build.odin. This will be handled in Step 7.
// For now, these loader functions assume those SDL functions are callable via `sdl.` prefix.
