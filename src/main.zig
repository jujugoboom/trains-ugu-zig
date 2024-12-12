const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

const screen_width = 680;
const screen_height = 420;

const grid_size = 32;
const inv_grid_size = 1.0 / @as(f32, @floatFromInt(grid_size));
const world_size = 1000;

const blank_space: u8 = 0;
const rail: u8 = 1;
const building: u8 = 2;
const station: u8 = 3;

const toggles = "Empty;Rail;Building;Station";

const zero_vector = rl.Vector2.init(0, 0);
const world_size_vec = rl.Vector2.init(world_size, world_size);
const total_size_vec = rl.Vector2.init(world_size * grid_size, world_size * grid_size);

var world: [world_size][world_size]u8 = [1][world_size]u8{[1]u8{building} ** world_size} ** world_size;

var gui_dropdown_bounds = rl.Rectangle.init(0, 0, 0, 0);
var gui_debug_toggle_bounds = rl.Rectangle.init(0, 0, 0, 0);
var gui_bounds = [2]*rl.Rectangle{ &gui_dropdown_bounds, &gui_debug_toggle_bounds };

var selected_mode: i32 = 0;
var dropdown_active = false;
var debug_active = false;

const texture_rects = [4]rl.Rectangle{
    undefined,
    rl.Rectangle{ .x = 0, .y = 0, .width = 32, .height = 32 },
    rl.Rectangle{ .x = 32, .y = 0, .width = 32, .height = 32 },
    rl.Rectangle{ .x = 64, .y = 0, .width = 32, .height = 32 },
};

fn checkGuiCollision(point: rl.Vector2, bounds: []const *rl.Rectangle) bool {
    for (bounds) |bound| {
        if (rl.checkCollisionPointRec(point, bound.*)) {
            return true;
        }
    }
    return false;
}

fn update(camera: *rl.Camera2D, curr_screen_width: f32, curr_screen_height: f32) !void {
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        const mouse_pos = rl.getMousePosition();
        const mouse_world_pos = rl.getScreenToWorld2D(mouse_pos, camera.*);

        var scale_factor = 1.0 + (0.25 * @abs(wheel));
        if (wheel < 0) {
            scale_factor = 1.0 / scale_factor;
        }

        camera.zoom = rl.math.clamp(camera.zoom * scale_factor, 0.125, 64.0);

        const camera_target = mouse_world_pos.subtract(
            mouse_pos.scale(
                1.0 / camera.zoom,
            ),
        );
        const max_target = total_size_vec.subtract(
            rl.Vector2.init(
                curr_screen_width / camera.zoom,
                curr_screen_height / camera.zoom,
            ),
        );
        camera.target = camera_target.clamp(zero_vector, max_target);
    }

    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_right)) {
        const delta = rl.getMouseDelta().scale(-1.0 / camera.zoom);
        const max_target = total_size_vec.subtract(
            rl.Vector2.init(
                curr_screen_width / camera.zoom,
                curr_screen_height / camera.zoom,
            ),
        );
        camera.target = camera.target.add(delta).clamp(zero_vector, max_target);
    }

    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left) and !checkGuiCollision(
        rl.getMousePosition(),
        &gui_bounds,
    ) and !dropdown_active) {
        const mouse_pos = rl.getScreenToWorld2D(
            rl.getMousePosition(),
            camera.*,
        );
        const clicked = mouse_pos.scale(inv_grid_size).clamp(
            zero_vector,
            world_size_vec,
        );
        world[@intFromFloat(clicked.x)][@intFromFloat(clicked.y)] = @intCast(selected_mode);
    }
}

fn draw(camera: rl.Camera2D, curr_screen_width: f32, curr_screen_height: f32, texture: rl.Texture2D) void {
    rl.beginDrawing();
    rl.clearBackground(rl.Color.white);

    rl.beginMode2D(camera);

    const start = rl.getScreenToWorld2D(
        zero_vector,
        camera,
    );
    const end = rl.getScreenToWorld2D(
        rl.Vector2{ .x = curr_screen_width, .y = curr_screen_height },
        camera,
    );
    const world_start = start.scale(inv_grid_size).clamp(
        zero_vector,
        world_size_vec,
    );
    const world_end = end.scale(inv_grid_size).clamp(
        zero_vector,
        world_size_vec,
    );

    for (@intFromFloat(world_start.x)..@intFromFloat(world_end.x + 1)) |i| {
        const fi = @as(f32, @floatFromInt(i));
        rl.drawLineV(
            rl.Vector2{ .x = grid_size * fi, .y = 0 },
            rl.Vector2{ .x = grid_size * fi, .y = world_size * grid_size },
            rl.Color.light_gray,
        );
        for (@intFromFloat(world_start.y)..@intFromFloat(world_end.y + 1)) |j| {
            const fj = @as(f32, @floatFromInt(j));
            if (i == @as(usize, @intFromFloat(world_start.x))) {
                rl.drawLineV(
                    rl.Vector2{ .x = 0, .y = grid_size * fj },
                    rl.Vector2{ .x = world_size * grid_size, .y = fj * grid_size },
                    rl.Color.light_gray,
                );
            }
            if (world[i][j] != 0) {
                const curr_pos = world[i][j];
                rl.drawTextureRec(
                    texture,
                    texture_rects[curr_pos],
                    rl.Vector2{ .x = fi * grid_size, .y = fj * grid_size },
                    rl.Color.white,
                );
            }
        }
    }

    rl.endMode2D();

    if (rg.guiDropdownBox(gui_dropdown_bounds, toggles, &selected_mode, dropdown_active) != 0) dropdown_active = !dropdown_active;

    _ = rg.guiToggle(gui_debug_toggle_bounds, "#191#", &debug_active);
    if (debug_active) {
        const curr_screen_h_i = @as(i32, @intFromFloat(curr_screen_height));
        const curr_screen_w_i = @as(i32, @intFromFloat(curr_screen_width));
        const fps_text = rl.textFormat("CURRENT FPS: %i", .{rl.getFPS()});
        rl.drawText(
            fps_text,
            curr_screen_w_i - (rl.measureText(fps_text, 20) + 20),
            curr_screen_h_i - 30,
            20,
            rl.Color.black,
        );
        const render_info = rl.textFormat("Rendering from x %d to %d; y %d to %d", .{
            @as(i32, @intFromFloat(world_start.x)),
            @as(i32, @intFromFloat(world_end.x)),
            @as(i32, @intFromFloat(world_start.y)),
            @as(i32, @intFromFloat(world_end.y)),
        });
        rl.drawText(
            render_info,
            curr_screen_w_i - (rl.measureText(render_info, 20) + 20),
            curr_screen_h_i - 60,
            20,
            rl.Color.black,
        );

        const position_info = rl.textFormat("Currently targeting %d, %d", .{
            @as(i32, @intFromFloat(camera.target.x)),
            @as(i32, @intFromFloat(camera.target.y)),
        });
        rl.drawText(
            position_info,
            curr_screen_w_i - (rl.measureText(position_info, 20) + 20),
            curr_screen_h_i - 90,
            20,
            rl.Color.black,
        );
        const mouse_pos = rl.getMousePosition().scale(
            1.0 / camera.zoom,
        );
        const mouse_info = rl.textFormat("Mouse targeting %d, %d", .{
            @as(i32, @intFromFloat(mouse_pos.x)),
            @as(i32, @intFromFloat(mouse_pos.y)),
        });
        rl.drawText(
            mouse_info,
            curr_screen_w_i - (rl.measureText(mouse_info, 20) + 20),
            curr_screen_h_i - 120,
            20,
            rl.Color.black,
        );
    }

    rl.endDrawing();
}

pub fn main() !void {

    // Initialization
    rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });
    rl.initWindow(screen_width, screen_height, "trains");
    defer rl.closeWindow();

    // Camera init
    var camera = rl.Camera2D{
        .target = rl.Vector2.init(0, 0),
        .offset = rl.Vector2.init(0, 0),
        .rotation = 0,
        .zoom = 1,
    };

    var texture = rl.loadTexture("resources/atlas.png");
    defer texture.unload();
    rl.genTextureMipmaps(&texture);

    rl.setTargetFPS(1000);

    while (!rl.windowShouldClose()) {
        const curr_screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const curr_screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));

        // Update gui position
        gui_dropdown_bounds = rl.Rectangle{
            .x = @floor(curr_screen_width * 0.5) - 40,
            .y = 10,
            .width = 80,
            .height = 24,
        };
        gui_debug_toggle_bounds = rl.Rectangle{
            .x = 10,
            .y = curr_screen_height - 30,
            .width = 20,
            .height = 20,
        };

        try update(&camera, curr_screen_width, curr_screen_height);
        draw(camera, curr_screen_width, curr_screen_height, texture);
    }
}
