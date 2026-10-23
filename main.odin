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
    texture: rl.Texture2D,
}

Level :: struct {
    // Maybe all platforms should have the same size
    platforms: [dynamic] Platform,
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

platform_collider :: proc(plat: Platform) -> rl.Rectangle {
    return {
        plat.pos.x, plat.pos.y, plat.width, plat.height,
    }
}

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

camera_move :: proc(camera: ^rl.Camera2D) {
    ground: f32
    steps :f32 = 3

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

    rl.InitWindow(1280, 720, "Main window")
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTargetFPS(150)
    
    player := player_init()
    level: Level
    plat_texture := rl.LoadTexture("platform.png")

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

    for !rl.WindowShouldClose() {

        if rl.IsKeyPressed(.F2) {
            editor_mode = !editor_mode
        }
        if rl.IsKeyPressed(.F3) {
            debug_mode = !debug_mode
        }

        // Base drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)

        if editor_mode {
            camera_move(&camera)

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
        rl.BeginMode2D(camera)
        player_draw(&player)
        for platform in level.platforms {
            //rl.DrawTextureV(plat_texture, platform.pos, platform.color)
            rl.DrawRectangle(i32(platform.pos.x), i32(platform.pos.y), i32(platform.width), i32(platform.height), platform.color)
        }

        if editor_mode {
            // Snap grid
            // NOTE: I'm sleepy and IDK how I made this work. It may be
            // simple math but I'm still not sure how I did it lol.
            size :i32 = 1000
            nlines := size / snap_grid
            range := (nlines / 2) * snap_grid
            for line :i32 = -range; line <= range; line += snap_grid {
                rl.DrawRectangle(line, -size/2, 1, size, rl.GRAY) // Vertical
                rl.DrawRectangle(-size/2, line, size, 1, rl.GRAY) // Horizontal
            }

            // Snap platform to the grid
            mspos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
            px := adjust_mspos(mspos.x, f32(snap_grid))
            py := adjust_mspos(mspos.y, f32(snap_grid))
            rl.DrawTextureV(plat_texture, {px, py}, rl.WHITE)

            // Place or remove platform
            vec: rl.Vector2 = {
                px, py
            }
            /*
            if rl.IsMouseButtonPressed(.LEFT) {
                append(&level.platforms, vec)
            }
            if rl.IsMouseButtonPressed(.RIGHT) {
                for plat, idx in level.platforms {
                    if rl.CheckCollisionPointRec(vec, platform_collider(plat)) {
                        unordered_remove(&level.platforms, idx)
                        break
                    }
                }
            }
            */

            // Editor crosshair
            cx := i32(camera.target.x)
            cy := i32(camera.target.y)
            rl.DrawRectangle(cx, cy - 5, 1, 10, rl.YELLOW) // Vertical
            rl.DrawRectangle(cx - 5, cy, 10, 1, rl.YELLOW) // Horizontal


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
