package audio

// SoundEffect represents a handle to a loaded sound chunk.
// In SDL_mixer, this would typically correspond to `^mix.Chunk`.
// Using distinct rawptr for type safety at the Odin level.
SoundEffect :: distinct rawptr

// Music represents a handle to a loaded music track.
// In SDL_mixer, this would typically correspond to `^mix.Music`.
Music :: distinct rawptr

// MaybeSoundEffect and MaybeMusic for functions that can fail to load audio.
MaybeSoundEffect :: Maybe(SoundEffect)
MaybeMusic :: Maybe(Music)
