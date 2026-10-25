#+feature dynamic-literals

package game

import "core:fmt"
import "core:strings"
import "core:encoding/json"
import "core:os"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

Platform :: struct {
    pos: rl.Vector2,
    width: f32,
    height: f32,
    is_solid: bool, // Useful for platforms
    color: rl.Color,
    color_idx: int,
    texture: rl.Texture2D,
}

Enemy :: struct {

}

Level :: struct {
    // Maybe all platforms should have the same size
    spawn: rl.Vector2,
    platforms: [dynamic] Platform,
    enemies: [dynamic] Enemy,
}

EditorMode :: enum {Place, Size, Color, Move}
Editor :: struct {
    level: ^Level,
    mode:  EditorMode,
    platform_idx: int,
    grid_space: f32,
}

Animation :: struct {
    texture: rl.Texture2D,
    num_frames: int,
    current_frame: int,
    frame_length: f32,
    frame_timer: f32,
}

Player :: struct {
    pos: rl.Vector2, // Can be 0,0
    size: rl.Vector2,
    vel: rl.Vector2,
    speed: f32,
    jump_speed: f32,
    on_ground: bool,
    flip: bool, // false - left, true - right
    is_moving: bool,

    // Collider
    feet_colider: rl.Rectangle,

    // Animations
    move_anim: Animation,
    idle_anim: Animation,
}

gravity :: 2000
PixelWindowHeight :: 180 // Max number of pixels to display, no matter window size
DeltaTime :: 0.01

// region === Level ===
level_init :: proc() -> Level {
    level: Level

    // Append a platform just in case something goes wrong while loading the level.
    // Temporary tho, it should not allow load anything if no level can be loaded.
    def_plat := Platform {
        pos = rl.Vector2 {0, 20},
        width = 20,
        height = 20,
        is_solid = true,
        color = rl.BLACK,
    }
    if level_data, err := os.read_entire_file("level.json", context.temp_allocator); err == nil {
        if json.unmarshal(level_data, &level) != nil {
            append(&level.platforms, def_plat)
        }
    } else {
        append(&level.platforms, def_plat)
    }
    free_all(context.temp_allocator)

    return level
}

// region === Editor ===
editor_init :: proc(level: ^Level) -> Editor {
    return {
        level = level,
        grid_space = 20,
        mode = EditorMode.Place,
        platform_idx = -1,
    }
}

editor_draw_grid :: proc(editor: ^Editor) {
    // NOTE: I'm sleepy and IDK how I made this work. It may be
    // simple math but I'm still not sure how I did it lol.
    size: i32 = 1000
    nlines := f32(size) / editor.grid_space
    range := i32((nlines / 2) * editor.grid_space)
    for line := -range; line <= range; line += i32(editor.grid_space) {
        rl.DrawRectangle(line, -size/2, 1, size, rl.GRAY) // Vertical
        rl.DrawRectangle(-size/2, line, size, 1, rl.GRAY) // Horizontal
    }
}

// region === Platform ===
platform_init :: proc(pos: rl.Vector2, editor: ^Editor) -> Platform {
    return {
        pos = pos,
        width = editor.grid_space,
        height = editor.grid_space,
        color = rl.BLACK,
        color_idx = 0,
    }
}

platform_collider :: proc(plat: Platform) -> rl.Rectangle {
    return {
        plat.pos.x, plat.pos.y, plat.width, plat.height,
    }
}

// region === Player ===
player_init :: proc() -> Player {
    player := Player {
        size = {64, 64},
        speed = 200,
        jump_speed = 450,
    }

    frame_length := f32(0.1)
    player.move_anim = Animation {
        texture = rl.LoadTexture("run_chicken_run.png"),
        num_frames = 4,
        frame_length = frame_length,
    }

    player.idle_anim = Animation {
        texture = rl.LoadTexture("idle_chicken.png"),
        num_frames = 6,
        frame_length = frame_length,
    }

    return player
}

player_move :: proc(player: ^Player) {
    ground: f32

    // @(static) first_time := false
    // @(static) current_time := 0.0
    // @(static) acc := 0.0 // Accumulator

    // if !first_time {
    //     current_time = rl.GetTime()
    //     first_time = true
    // }

    // INPUT

    // Scroll
    player.is_moving = true
    if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
        player.vel.x = -player.speed
        player.flip = true
    } else if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
        player.vel.x = player.speed
        player.flip = false
    } else {
        player.vel.x = 0
        player.is_moving = false
    }

    // Jump
    // TODO: Fix cause sometimes it won't jump.
    if player.on_ground && rl.IsKeyPressed(.SPACE)  {
        player.vel.y = -player.jump_speed
        player.on_ground = false
    }

    // Physics
    // new_time := rl.GetTime()
    // frame_time := new_time - current_time
    // if (frame_time > 0.25) {
    //     frame_time = 0.25
    // }
    // fmt.println(frame_time, "---", rl.GetFrameTime())
    // current_time = new_time

    // for acc += frame_time; acc >= DeltaTime; acc -= DeltaTime {
    // Vector arithmetic
    // Semi-implicit Eurler

    // TODO: Fix freezing screen
    frame_time := rl.GetFrameTime()
    player.vel.y += gravity * frame_time
    player.pos += player.vel * frame_time

    player.feet_colider = rl.Rectangle {
        x = player.pos.x - 4,
        y = player.pos.y - 4,
        width = 8,
        height = 4,
    }
    // }

}

player_draw :: proc(player: ^Player) {
    source: rl.Rectangle
    dest: rl.Rectangle
    texture: rl.Texture2D

    if player.is_moving {
        texture, source, dest = get_animation(player^, &player.move_anim)
    } else {
        texture, source, dest = get_animation(player^, &player.idle_anim)
    }

    // Set the origin so what's actually drawn is above of the real position of the player
    rl.DrawTexturePro(texture, source, dest, {dest.width / 2, dest.height}, 0, rl.WHITE)
}

// region === Camera ===
camera_move :: proc(camera: ^rl.Camera2D) {
    ground: f32
    steps: f32 = 7 / camera.zoom

    // Scroll
    if rl.IsKeyDown(.W) {
        camera.target.y -= steps
    } else if rl.IsKeyDown(.A) {
        camera.target.x -= steps
    } else if rl.IsKeyDown(.S) {
        camera.target.y += steps
    } else if rl.IsKeyDown(.D) {
        camera.target.x += steps
    }

    // Zoom
    if rl.IsKeyDown(.LEFT_CONTROL) {
        if rl.IsKeyPressed(.MINUS) {
            camera.zoom -= 0.5
            if camera.zoom <= 1 {
                camera.zoom = 1
            }
        }
        if rl.IsKeyPressed(.EQUAL) {
            camera.zoom += 0.5
            if camera.zoom >= 10 {
                camera.zoom = 10
            }
        }
    }
}

get_animation :: proc(player: Player, anim: ^Animation) -> (texture: rl.Texture2D, source: rl.Rectangle, dest: rl.Rectangle) {
    run_width := f32(anim.texture.width)
    run_height := f32(anim.texture.height)
    frame_width := run_width / f32(anim.num_frames)

    // Check if there's been a frame since the last one
    anim.frame_timer += rl.GetFrameTime()
    if anim.frame_timer > anim.frame_length {
        anim.current_frame += 1
        anim.frame_timer = 0

        // Return back to the first frame
        if anim.current_frame == anim.num_frames {
            anim.current_frame = 0
        }
    }
    
    source = rl.Rectangle {
        x = frame_width * f32(anim.current_frame),
        y = 0,
        width = frame_width,
        height = run_height,
    }

    if player.flip {
        source.width = -source.width
    }

    dest = rl.Rectangle {
        x = player.pos.x,
        y = player.pos.y,
        width = frame_width,
        height = run_height,
    }

    texture = anim.texture

    return
}

adjust_mspos :: proc(mspos: f32, grid_space: f32) -> f32 {
    pos: f32 = math.trunc(mspos / grid_space) * grid_space

    if mspos < 0 {
        pos -= grid_space
    }

    return pos
}

// Notes: Regarding memory leaks, the following is a tracker of those leaks.
// It's not important to free it at the end of the program because the OS is going
// to take that used memory anyways but it's important to take it into account
// while the program is running to avoid taking a lot of space of memory.
// Things to free: dynamic arrays, temp_allocatory, rl.UnloadTexture()
main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        for _, entry in track.allocation_map {
            fmt.eprintfln("%v leaked %v bytes", entry.location, entry.size)
        }
        for entry in track.bad_free_array {
            fmt.eprintfln("%v bad free", entry.location)
        }
        mem.tracking_allocator_destroy(&track)
    }

    camera: rl.Camera2D
    
    debug_mode := false
    editor_mode := false
    snap_grid: i32 = 20
    Colors := [25]rl.Color {rl.BLACK, rl.LIGHTGRAY, rl.GRAY, rl.DARKGRAY, rl.YELLOW, rl.GOLD, rl.ORANGE, rl.PINK, rl.RED, rl.MAROON, rl.GREEN, rl.LIME, rl.DARKGREEN, rl.SKYBLUE, rl.BLUE, rl.DARKBLUE, rl.PURPLE, rl.VIOLET, rl.DARKPURPLE, rl.BEIGE, rl.BROWN, rl.DARKBROWN, rl.WHITE, rl.BLANK, rl.MAGENTA}

    rl.InitWindow(1280, 720, "Main window")
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTargetFPS(150)
    
    player: Player = player_init()
    level: Level = level_init()
    editor: Editor = editor_init(&level)
    mspos: rl.Vector2
    //plat_texture := rl.LoadTexture("platform.png")

    for !rl.WindowShouldClose() {

        if rl.IsKeyPressed(.F2) {
            editor_mode = !editor_mode
        }
        if rl.IsKeyPressed(.F3) {
            debug_mode = !debug_mode
        }


        if editor_mode {
            camera_move(&camera)

            pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
            mspos = {
                adjust_mspos(pos.x, editor.grid_space),
                adjust_mspos(pos.y, editor.grid_space),
            }

            if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsMouseButtonPressed(.LEFT) {
                for plat, idx in level.platforms {
                    if idx == editor.platform_idx {
                        // Deselect
                        editor.platform_idx = -1
                        break
                    } else if rl.CheckCollisionPointRec(mspos, platform_collider(plat)) {
                        // Select the platform
                        editor.platform_idx = idx
                        break
                    }
                }
            }

            if rl.IsKeyPressed(.P) {
                editor.mode = EditorMode.Place
                fmt.println("Place editor mode activated")
            } else if rl.IsKeyPressed(.S) {
                editor.mode = EditorMode.Size
                fmt.println("Size editor mode activated")
            } else if rl.IsKeyPressed(.C) {
                editor.mode = EditorMode.Color
                fmt.println("Color editor mode activated")
            } else if rl.IsKeyPressed(.M) {
                editor.mode = EditorMode.Move
                fmt.println("Move editor mode activated")
            }

            if editor.mode == EditorMode.Place {
                // Place or remove platform
                if rl.IsMouseButtonPressed(.LEFT) {
                    append(&level.platforms, platform_init(mspos, &editor))
                }
                if rl.IsMouseButtonPressed(.RIGHT) {
                    for plat, idx in level.platforms {
                        if rl.CheckCollisionPointRec(mspos, platform_collider(plat)) {
                            unordered_remove(&level.platforms, idx)
                            break
                        }
                    }
                }
            } else if editor.platform_idx >= 0 {
                // Sizing, coloring and moving depend on a selected platform.
                if editor.mode == EditorMode.Size {
                    if rl.IsKeyPressed(.UP) {
                        level.platforms[editor.platform_idx].pos.y -= editor.grid_space
                        level.platforms[editor.platform_idx].height += editor.grid_space
                    } else if rl.IsKeyPressed(.LEFT) {
                        level.platforms[editor.platform_idx].pos.x -= editor.grid_space
                        level.platforms[editor.platform_idx].width += editor.grid_space
                    } else if rl.IsKeyPressed(.DOWN) {
                        level.platforms[editor.platform_idx].height += editor.grid_space
                    } else if rl.IsKeyPressed(.RIGHT) {
                        level.platforms[editor.platform_idx].width += editor.grid_space
                    }
                } else if editor.mode == EditorMode.Color {
                    idx := level.platforms[editor.platform_idx].color_idx
                    if rl.IsKeyPressed(.LEFT) {
                        idx -= 1
                    } else if rl.IsKeyPressed(.RIGHT) {
                        idx += 1
                    }

                    if idx < 0 {
                        idx = 24
                    } else if idx >= 25 {
                        idx = 0
                    }

                    level.platforms[editor.platform_idx].color_idx = idx
                    level.platforms[editor.platform_idx].color = Colors[idx]
                } else if editor.mode == Editor.Move {
                    level.platforms[editor.platform_idx].pos = mspos
                }
            }

            if rl.IsKeyPressed(.F5) {
                if data, err := json.marshal(level, allocator = context.temp_allocator); err == nil {
                    if ret := os.write_entire_file("level.json", data); err != nil {
                        fmt.eprintln("Error writtin level to a file")
                    } else {
                        fmt.println("Level writen to a file successfuly")
                    }
                } else {
                    fmt.println("Error marshaling level")
                }
                free_all(context.temp_allocator)
            }
        } else {
            // Update
            player_move(&player)
            camera = rl.Camera2D {
                zoom = f32(rl.GetScreenHeight()) / PixelWindowHeight,
                offset = {f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)},
                target = player.pos,
            }

            // Check platform collision if the player is falling
            player.on_ground = false
            for platform in level.platforms {
                if player.vel.y > 0 && rl.CheckCollisionRecs(player.feet_colider, platform_collider(platform)) {
                    player.vel.y = 0
                    player.pos.y = platform.pos.y
                    player.on_ground = true
                }
            }


            // Activate / Deactivate modes
            if rl.IsKeyDown(.LEFT_CONTROL) {
                if rl.IsKeyPressed(.R) { // Reset position
                    player.pos = {0,0}
                    player.vel = {0,0}
                }
            }
        }

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)
        rl.BeginMode2D(camera)

        player_draw(&player)
        for plat in level.platforms {
            //rl.DrawTextureV(plat_texture, platform.pos, platform.color)
            rl.DrawRectangle(i32(plat.pos.x), i32(plat.pos.y), i32(plat.width), i32(plat.height), plat.color)
        }

        if editor_mode {
            editor_draw_grid(&editor)

            // Editor crosshair
            cx := i32(camera.target.x)
            cy := i32(camera.target.y)
            rl.DrawRectangle(cx, cy - 5, 1, 10, rl.YELLOW) // Vertical
            rl.DrawRectangle(cx - 5, cy, 10, 1, rl.YELLOW) // Horizontal

        }

        if debug_mode {
            rl.DrawRectangleRec(player.feet_colider, rl.ORANGE)

            base_x := i32(camera.target.x - 155)
            base_y := i32(camera.target.y - 80)
            lines := []cstring {
                fmt.ctprintf("x: %2.f, y: %2.f", player.pos.x, player.pos.y),
                fmt.ctprintf("xvel: %2.f, yvel: %2.f", player.vel.x, player.vel.y),
                fmt.ctprintf("dt: %g", rl.GetFrameTime()),
            }

            for msg in lines {
                // FIX: This is a massive memory leak
                rl.DrawText(msg, base_x, base_y, 1, rl.BLACK)
                base_y += 10
            }
        }

        rl.EndMode2D()
        rl.EndDrawing()
    }

    rl.CloseWindow()
}
