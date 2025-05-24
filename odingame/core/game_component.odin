package core

import time "./time" // For Game_Time
import "core:mem"   // For new()

// Game_Component is the base class for all updatable game components.
Game_Component :: struct {
    game_ptr:     rawptr, // Placeholder for ^core.Game to avoid import cycles
    enabled:      bool,
    update_order: int,

    // Virtual methods (procedure fields)
    initialize: proc(self: ^Game_Component),
    update:     proc(self: ^Game_Component, game_time: time.Game_Time), // Use time.Game_Time
    destroy:    proc(self: ^Game_Component),
    // on_enabled_changed: proc(self: ^Game_Component),        // Future consideration
    // on_update_order_changed: proc(self: ^Game_Component),   // Future consideration
}

// Default implementations for Game_Component methods
_default_component_initialize :: proc(self: ^Game_Component) {
    // Default: Do nothing
}
_default_component_update :: proc(self: ^Game_Component, game_time: time.Game_Time) {
    // Default: Do nothing
}
_default_component_destroy :: proc(self: ^Game_Component) {
    // Default: Do nothing. Actual memory freeing depends on allocation strategy.
    // If `new(Game_Component)` was used and component owns itself, `free(self)` might be here.
    // But typically components are managed by the Game or a scene.
}

// new_game_component is a constructor for Game_Component.
// Takes a rawptr placeholder for ^core.Game.
new_game_component :: proc(game: rawptr) -> ^Game_Component {
    comp := new(Game_Component) // Uses context.allocator by default
    comp.game_ptr = game
    comp.enabled = true
    comp.update_order = 0
    comp.initialize = _default_component_initialize
    comp.update = _default_component_update
    comp.destroy = _default_component_destroy
    return comp
}


// Drawable_Game_Component is the base class for game components that also need to be drawn.
Drawable_Game_Component :: struct {
    using component: Game_Component, // Embeds Game_Component fields and methods
    
    visible:         bool,
    draw_order:      int,

    // Virtual methods
    draw: proc(self: ^Drawable_Game_Component, game_time: time.Game_Time), // Use time.Game_Time
    // on_visible_changed: proc(self: ^Drawable_Game_Component),    // Future consideration
    // on_draw_order_changed: proc(self: ^Drawable_Game_Component), // Future consideration
}

// Default implementation for Drawable_Game_Component's draw method
_default_drawable_component_draw :: proc(self: ^Drawable_Game_Component, game_time: time.Game_Time) {
    // Default: Do nothing
}

// new_drawable_game_component is a constructor for Drawable_Game_Component.
// Takes a rawptr placeholder for ^core.Game.
new_drawable_game_component :: proc(game: rawptr) -> ^Drawable_Game_Component {
    dcomp := new(Drawable_Game_Component) // Uses context.allocator
    
    // Initialize embedded Game_Component part
    // Note: `using` means fields of `component` are directly accessible on `dcomp`.
    dcomp.game_ptr = game
    dcomp.enabled = true
    dcomp.update_order = 0
    dcomp.initialize = _default_component_initialize       // Inherits default initialize
    dcomp.update = _default_component_update             // Inherits default update
    dcomp.destroy = _default_component_destroy            // Inherits default destroy
    
    // Initialize Drawable_Game_Component specific fields
    dcomp.visible = true
    dcomp.draw_order = 0
    dcomp.draw = _default_drawable_component_draw
    
    return dcomp
}
