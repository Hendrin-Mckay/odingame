package assets

import "core:strings" // For string operations if needed for paths, etc.
// No other imports needed for these basic type definitions.

// AssetID is a distinct type for unique asset identifiers.
// Using u64 for a large address space and to potentially embed type/generation info.
AssetID :: distinct u64

// ASSET_ID_NIL represents an invalid or unloaded asset.
ASSET_ID_NIL :: AssetID(0) // Assuming 0 is not a valid ID.

// AssetType categorizes the kind of asset.
AssetType :: enum {
	UNKNOWN, // Should not ideally be used once type is known
	TEXTURE,
	SOUND,    // For short sound effects (e.g. Mix_Chunk)
	MUSIC,    // For longer background music (e.g. Mix_Music)
	DATA,     // For generic binary or text data (e.g., JSON, config files)
	FONT,     // For font data (e.g., TTF files)
	// Add more types as needed (e.g., SHADER, MATERIAL, SCENE)
}

// AssetState tracks the current loading state of an asset.
AssetState :: enum {
	UNLOADED,   // Not loaded or has been unloaded.
	LOADING,    // Currently in the process of being loaded (e.g., async operation).
	LOADED,     // Successfully loaded and ready for use.
	FAILED,     // An error occurred during loading.
	// UNLOADING, // Optional: if unloading is also an async process.
}

// Asset is a base struct embedded or referenced by specific asset types.
// It contains common metadata for all assets.
Asset :: struct {
	id:        AssetID,
	path:      string, // Filesystem path or unique identifier for this asset.
	type:      AssetType,
	state:     AssetState,
	ref_count: i32,    // Reference count to manage auto-unloading.
	// user_data: rawptr, // Optional: for custom data associated with the asset.
}

// Helper function to create a base Asset.
// Name is cloned for ownership.
@(private) // This is internal to the assets package usually
create_base_asset :: proc(id: AssetID, path: string, type: AssetType) -> Asset {
    return Asset{
        id        = id,
        path      = strings.clone(path), // Clone the path string for ownership
        type      = type,
        state     = .UNLOADED,
        ref_count = 0, // Initial ref count is 0, LoadAsset will increment it.
    }
}

// Specific asset types will embed this Asset struct or hold a pointer to it.
// For example:
// TextureAsset :: struct {
//     base: Asset,
//     sdl_texture: ^sdl.SDL_Texture, // Actual texture data
//     width: i32,
//     height: i32,
// }
//
// SoundAsset :: struct {
//     base: Asset,
//     mix_chunk: ^sdl.Mix_Chunk, // Actual sound data
// }

// Note: The actual TextureAsset, SoundAsset, etc., will be defined
// when we implement their specific loaders.
