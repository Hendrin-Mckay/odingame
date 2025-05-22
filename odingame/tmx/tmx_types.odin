package tmx

import "core:mem" // For allocator, if needed by these structs directly (e.g. for default make)
                   // Generally, dynamic arrays will use allocator passed at make time.

// TmxImage represents the image source for a tileset or image layer.
TmxImage :: struct {
	source: string, // Path to the image file
	width:  int,    // Width of the image in pixels
	height: int,    // Height of the image in pixels
	// transparent_color: Maybe(string), // Optional: e.g., "#FF00FF"
}

// TmxTileProperty represents a single custom property.
// Using string for value, type conversion would be done by user.
// TmxProperty :: struct {
//  name:  string,
//  type:  string, // e.g., "string", "int", "float", "bool", "color", "file"
//  value: string,
// }
// PropertiesMap :: map[string]TmxProperty // Or more simply:
PropertiesMap :: map[string]string // As per subtask simplification for now

// TmxTile represents a single tile within a tileset, which might have custom properties.
TmxTile :: struct {
	id:         int, // Local ID within the tileset
	properties: Maybe(PropertiesMap),
	// Add other fields like 'type' (string), 'objectgroup' (for collision), 'animation' if needed later.
}

// TmxTileset represents a tileset, which can be embedded or external (via source .tsx file).
TmxTileset :: struct {
	firstgid:    int,    // First global tile ID of this tileset
	name:        string, // Name of the tileset
	tile_width:  int,    // Width of a single tile in pixels
	tile_height: int,    // Height of a single tile in pixels
	tile_count:  int,    // Total number of tiles in this tileset
	columns:     int,    // Number of tile columns in the tileset image
	
	image:       Maybe(TmxImage), // Image associated with this tileset (for embedded single-image tilesets)
	
	// If 'source' is present, this tileset is external, and 'image', 'tile_count', etc.
	// might be loaded from the .tsx file.
	source:      Maybe(string), // Path to the external .tsx tileset file, relative to the TMX file
	
	// Individual tile data, often for properties, collision, or animations.
	// Not all tiles in a tileset will necessarily have a TmxTile entry.
	tiles:       Maybe([dynamic]TmxTile), 
	
	// Could also store:
	// spacing: int
	// margin: int
	// properties: Maybe(PropertiesMap)
}

// TmxLayer represents a tile layer in the map.
TmxLayer :: struct {
	name:    string,
	id:      int, // Layer ID
	width:   int,    // Width of the layer in tiles
	height:  int,    // Height of the layer in tiles
	data:    []u32,  // Array of Global Tile IDs (GIDs). 0 means empty tile.
	                 // This slice will be owned by the TmxLayer struct after parsing.
	opacity: f32,    // Opacity of the layer (0.0 to 1.0)
	visible: bool,   // Whether the layer is visible
	// properties: Maybe(PropertiesMap)
	// Could also store: offsetx, offsety, parallaxx, parallaxy
}

// TmxObject represents a single object in an object group.
TmxObject :: struct {
	id:         int,
	name:       string,
	type:       string, // User-defined type string
	x:          f32,    // X coordinate in pixels
	y:          f32,    // Y coordinate in pixels
	width:      f32,    // Width in pixels (0 if not a rectangle, e.g. point or polyline)
	height:     f32,    // Height in pixels (0 if not a rectangle)
	rotation:   f32,    // Rotation in degrees clockwise
	gid:        Maybe(u32), // GID if it's a Tile Object, representing the tile's appearance
	visible:    bool,
	properties: Maybe(PropertiesMap),
	// Could also store:
	// ellipse: bool (if object is an ellipse)
	// point: bool (if object is a point)
	// polygon: Maybe([dynamic]math.Vector2f) // For polygon objects
	// polyline: Maybe([dynamic]math.Vector2f) // For polyline objects
	// text: Maybe(TmxText) // For text objects
}

// TmxObjectGroup represents a layer containing objects.
TmxObjectGroup :: struct {
	name:        string,
	id:          int, // Layer ID
	objects:     [dynamic]TmxObject, // List of objects in this group
	draw_order:  string, // "topdown" (default) or "index"
	opacity:     f32,
	visible:     bool,
	// properties: Maybe(PropertiesMap)
	// Could also store: color (tint for objects), offsetx, offsety, parallaxx, parallaxy
}

// TmxMap represents the entire Tiled map.
TmxMap :: struct {
	width:         int,    // Map width in tiles
	height:        int,    // Map height in tiles
	tile_width:    int,    // Width of a single tile in pixels
	tile_height:   int,    // Height of a single tile in pixels
	orientation:   string, // e.g., "orthogonal", "isometric", "staggered", "hexagonal"
	render_order:  string, // e.g., "right-down", "right-up", "left-down", "left-up"
	
	tilesets:      [dynamic]TmxTileset,     // List of tilesets used by the map
	
	// Layers can be of different types (tile layers, object groups, image layers, group layers).
	// For this subtask, focusing on TmxLayer (tile layers) and TmxObjectGroup.
	// A more complete parser might use a sum type (variant) for layers.
	tile_layers:   [dynamic]TmxLayer,       // Specifically tile layers
	object_groups: [dynamic]TmxObjectGroup, // Specifically object groups
	// image_layers: [dynamic]TmxImageLayer, // For TMX Image Layers
	// group_layers: [dynamic]TmxGroupLayer, // For TMX Group Layers

	properties:    Maybe(PropertiesMap), // Custom properties for the map
	
	// Other map attributes:
	// version: string (e.g., "1.4")
	// tiledversion: string (e.g., "1.4.3")
	// infinite: bool
	// nextlayerid: int
	// nextobjectid: int
	// backgroundcolor: Maybe(string) // Hex color #AARRGGBB or #RRGGBB
	// hexsidelength: Maybe(int)
	// staggeraxis: Maybe(string) // "x" or "y"
	// staggerindex: Maybe(string) // "even" or "odd"
	
	// Allocator used for the dynamic arrays within this map and its children.
	// This should be passed in during loading.
	allocator: mem.Allocator, 
}

// --- Helper for GID Manipulation ---
// Tiled GIDs can have flip flags embedded in the most significant bits.
// Constants for these flags (from TMX specification):
FLIPPED_HORIZONTALLY_FLAG :: 0x80000000 // bit 31
FLIPPED_VERTICALLY_FLAG   :: 0x40000000 // bit 30
FLIPPED_DIAGONALLY_FLAG   :: 0x20000000 // bit 29
// ROTATED_HEXAGONAL_120_FLAG :: 0x10000000 // bit 28 (for hexagonal maps)

// All flags combined for masking
ALL_FLIP_FLAGS :: FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG // | ROTATED_HEXAGONAL_120_FLAG;

// get_actual_gid extracts the actual tile ID by clearing the flip flags.
get_actual_gid :: proc(gid_with_flags: u32) -> u32 {
	return gid_with_flags & ~ALL_FLIP_FLAGS
}

// get_tile_flip_flags extracts the flip flags from a GID.
// Returns a struct or distinct flags for horizontal, vertical, diagonal flips.
TileFlipFlags :: struct {
	horizontally: bool,
	vertically:   bool,
	diagonally:   bool,
	// rotated_hex_120: bool, // For hexagonal
}

get_tile_flip_flags :: proc(gid_with_flags: u32) -> TileFlipFlags {
	return TileFlipFlags{
		horizontally = (gid_with_flags & FLIPPED_HORIZONTALLY_FLAG) != 0,
		vertically   = (gid_with_flags & FLIPPED_VERTICALLY_FLAG)   != 0,
		diagonally   = (gid_with_flags & FLIPPED_DIAGONALLY_FLAG)   != 0,
		// rotated_hex_120 = (gid_with_flags & ROTATED_HEXAGONAL_120_FLAG) != 0,
	}
}

// Helper to check if a GID represents an empty tile (GID 0).
is_empty_tile :: proc(gid_with_flags: u32) -> bool {
    // The actual GID is stored in the lower bits. An empty tile has an actual GID of 0.
    // Flags might still be present if a tile was placed and then removed, but GID 0 is key.
    // However, Tiled usually represents empty tiles with a raw GID of 0 (no flags).
	return get_actual_gid(gid_with_flags) == 0
}
