package game

import "core:fmt"
import rl "vendor:raylib"

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
// Max number of pixels to display, no matter window size
PixelWindowHeight :: 180

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
    player.vel.y += gravity * rl.GetFrameTime()
    // NOTE: The AND is for disallowing jumping in the air but
    // it could be remade for making double jump.
    if player.on_ground && rl.IsKeyPressed(.SPACE)  {
        player.vel.y = -player.jump_speed
        player.on_ground = false
    }

    // Vector arithmetic
    player.pos += player.vel * rl.GetFrameTime()

    player.feet_colider = rl.Rectangle {
        x = player.pos.x - 4,
        y = player.pos.y - 4,
        width = 8,
        height = 4,
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
    debug_mode, create_mode: bool

    rl.InitWindow(1280, 720, "Main window")
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTargetFPS(150)
    
    player := player_init()
    // TODO: Add nicer platforms :P (textures)
    platforms := []rl.Rectangle {
        {-20, 20, 96, 16},
        {100, -20, 96, 16},
    }
    plat_texture := rl.LoadTexture("platform.png")

    for !rl.WindowShouldClose() {

        // Base drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)

        // Update
        player_move(&player)
        camera = rl.Camera2D {
            zoom = f32(rl.GetScreenHeight()) / PixelWindowHeight,
            offset = {f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)},
            target = player.pos,
        }

        // Check platform collision if the player is falling
        player.on_ground = false
        for platform in platforms {
            if player.vel.y > 0 && rl.CheckCollisionRecs(player.feet_colider, platform) {
                player.vel.y = 0
                player.pos.y = platform.y
                player.on_ground = true
            }
        }


        // Activate / Deactivate modes
        if rl.IsKeyDown(.LEFT_CONTROL) {
            if rl.IsKeyPressed(.X) {
                debug_mode = !debug_mode
            }
            if rl.IsKeyPressed(.C) {
                create_mode = !create_mode
            }
            if rl.IsKeyPressed(.R) { // Reset position
                player.pos = {0,0}
            }
        }
        
        // Draw
        rl.BeginMode2D(camera)
        player_draw(&player)
        for platform in platforms {
            rl.DrawTextureV(plat_texture, {platform.x, platform.y}, rl.WHITE)
        }

        if debug_mode {
            rl.DrawRectangleRec(player.feet_colider, rl.ORANGE)
        }

        rl.EndMode2D()
        rl.EndDrawing()
    }

    rl.CloseWindow()
}
