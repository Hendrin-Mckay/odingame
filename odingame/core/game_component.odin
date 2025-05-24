package core

// Placeholder for Game_Component
// This will be the base for all game components, allowing them to be updated and drawn.
Game_Component :: struct {
    // game: ^Game, // Reference to the game
    // enabled: bool,
    // update_order: int,
}

// Placeholder for Drawable_Game_Component (if needed as a distinct type later)
// Drawable_Game_Component :: struct {
//     using component: Game_Component,
//     visible: bool,
//     draw_order: int,
// }

// Placeholder for future methods
// initialize :: proc(gc: ^Game_Component) {}
// update :: proc(gc: ^Game_Component, game_time: Game_Time) {}
// draw :: proc(dgc: ^Drawable_Game_Component, game_time: Game_Time) {} // If Drawable_Game_Component is used
// destroy_component :: proc(gc: ^Game_Component) { free(gc) }
