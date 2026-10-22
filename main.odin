#+feature dynamic-literals

package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Level :: struct {
    // Maybe all platforms should have the same size
    platforms: [dynamic] rl.Vector2,
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

platform_collider :: proc(pos: rl.Vector2) -> rl.Rectangle {
    return {
        pos.x, pos.y, 96, 16,
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

main :: proc() {
    camera: rl.Camera2D
    
    debug_mode := false
    editor_mode := false
    snap_grid: i32 = 20

    rl.InitWindow(1280, 720, "Main window")
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTargetFPS(150)
    
    player := player_init()
    level := Level {
        // TODO: Add nicer platforms :P (textures)
        platforms = {
            {-20, 20},
            {100, -20},
        }
    }
    plat_texture := rl.LoadTexture("platform.png")

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
                    player.pos.y = platform.y
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
            rl.DrawTextureV(plat_texture, platform, rl.WHITE)
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

            mspos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

            // Snap grid
            px := f32((i32(mspos.x) / snap_grid) * snap_grid)
            py := f32((i32(mspos.y) / snap_grid) * snap_grid)
            rl.DrawTextureV(plat_texture, {px, py}, rl.WHITE)

            cx := i32(camera.target.x)
            cy := i32(camera.target.y)

            rl.DrawRectangle(cx, cy - 5, 1, 10, rl.YELLOW) // Vertical
            rl.DrawRectangle(cx - 5, cy, 10, 1, rl.YELLOW) // Horizontal
        }

        if debug_mode {
            rl.DrawRectangleRec(player.feet_colider, rl.ORANGE)

            base_x := i32(camera.target.x - 155)
            base_y := i32(camera.target.y - 80)
            lines := []string {
                fmt.tprintf("x: %2.f, y: %2.f", player.pos.x, player.pos.y),
                fmt.tprintf("xvel: %2.f, yvel: %2.f", player.vel.x, player.vel.y),
                fmt.tprintf("dt: %g", rl.GetFrameTime()),
            }

            for msg in lines {
                rl.DrawText(strings.clone_to_cstring(msg), base_x, base_y, 1, rl.BLACK)
                base_y += 10
            }
        }

        rl.EndMode2D()
        rl.EndDrawing()
    }

    rl.CloseWindow()
}
