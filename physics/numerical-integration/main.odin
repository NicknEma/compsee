package main

import        "core:fmt"
import slices "core:slice"
import        "core:strings"

import        "vendor:raylib"

WINDOW_WIDTH  :: 800
WINDOW_HEIGHT :: 600

Integration_Mode :: enum {
	Explicit_Euler,
	Semi_Implicit_Euler,
	Verlet,
}

main :: proc() {
	raylib.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello");
	if raylib.IsWindowReady() {
		raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
		raylib.SetTargetFPS(60);
		
		mode: Integration_Mode;
		
		should_quit := false;
		for !raylib.WindowShouldClose() && !should_quit {
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.RIGHT) {
				mode = Integration_Mode((int(mode) + 1) % len(Integration_Mode))
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.LEFT) {
				mode = Integration_Mode(int(mode) - 1);
				for int(mode) < 0 do mode = Integration_Mode(int(mode) + len(Integration_Mode))
			}
			
			n: int;
			all_positions, all_velocities: []f64;
			
			{
				t := 0.0;
				dt := 1.0;
				
				duration := 10.0;
				
				force := 10.0;
				mass := 1.0;
				
				start_position := 0.0;
				position := start_position;
				start_velocity := 0.0;
				velocity := start_velocity;
				
				prev_position := position;
				
				n = int(duration / dt) + 1; // Include the t = 0 timestamp
				
				all_positions  = make([]f64, n, allocator = context.temp_allocator);
				all_velocities = make([]f64, n, allocator = context.temp_allocator);
				
				i := 0;
				for t <= duration {
					switch mode {
						case .Explicit_Euler: {
							position = position + velocity * dt;
							velocity = velocity + (force / mass) * dt;
							
							all_positions[i]  = position;
							all_velocities[i] = velocity;
							
						}
						
						case .Semi_Implicit_Euler: {
							velocity = velocity + (force / mass) * dt;
							position = position + velocity * dt;
							
							all_positions[i]  = position;
							all_velocities[i] = velocity;
						}
						
						case .Verlet: {
							dt_squared := dt * dt;
							next_position := 2*position - prev_position + (force / mass) * dt_squared;
							prev_position = position;
							position = next_position;
							
							all_positions[i] = position;
						}
					}
					
					t += dt;
					i += 1;
				}
			}
			
			raylib.BeginDrawing();
			raylib.ClearBackground(raylib.RAYWHITE);
			
			click := button("Hi", {10, 50}, {80, 60}, raylib.WHITE, raylib.MAROON);
			
			{
				padding := f64(30);
				w := f64(WINDOW_WIDTH  - 2*padding);
				h := f64(WINDOW_HEIGHT - 2*padding);
				max_position := slices.max(all_positions)
				for i := 0; i < n; i += 1 {
					// i : n = x : w
					// nx = iw
					// x = iw/n
					x := f64(i)*w / f64(n);
					// p[i] : max(p) = y : h
					// max(p)y = p[i]h
					// y = p[i]h / max(p)
					y := all_positions[i]*h / max_position;
					p := Vector2{f32(x), f32(y)} + f32(padding);
					v := all_velocities[i];
					r := f32(10);
					
					raylib.DrawCircleV(p, r, raylib.RED);
				}
			}
			
			{
				text := strings.clone_to_cstring(fmt.tprintf("Integration mode: %s", mode), context.temp_allocator);
				raylib.DrawText(text, 10, 10, 30, raylib.BLACK)
			}
			
			raylib.EndDrawing();
			free_all(context.temp_allocator);
		}
	}
}

button :: proc(text: string, pos: Vector2, dim: Vector2, text_color: raylib.Color, back_color: raylib.Color) -> bool {
	hover := false;
	clicked := false;
	
	mouse_pos := raylib.GetMousePosition();
	button_rect := raylib.Rectangle{pos.x, pos.y, dim.x, dim.y};
	if raylib.CheckCollisionPointRec(mouse_pos, button_rect) {
		hover = true;
	}
	
	back_color := back_color;
	if hover {
		back_color = raylib.ColorBrightness(back_color, 0.2);
	}
	
	raylib.DrawRectangleV(pos, dim, back_color);
	
	return false;
}

Vector2 :: raylib.Vector2

explicit_euler :: proc(curr_pos, curr_vel, acc: f32, dt: f32) -> (next_pos, next_vel: f32) {
	next_vel = curr_vel +      acc*dt;
	next_pos = curr_pos + curr_vel*dt;
	return next_pos, next_vel;
}

semi_implicit_euler :: proc(curr_pos, curr_vel, acc: f32, dt: f32) -> (next_pos, next_vel: f32) {
	next_vel = curr_vel +      acc*dt;
	next_pos = curr_pos + next_vel*dt;
	return next_pos, next_vel;
}

implicit_euler :: proc(curr_pos, curr_vel, acc: f32, dt: f32) -> (next_pos, next_vel: f32) {
	next_acc := acc; // @Incomplete: predict the next acceleration
	
	next_vel = curr_vel + next_acc*dt;
	next_pos = curr_pos + next_vel*dt;
	return next_pos, next_vel;
}

verlet :: proc(curr_pos, prev_pos, acc: f32, dt_squared: f32) -> (next_pos: f32) {
	next_pos = 2*curr_pos - prev_pos + acc * dt_squared;
	return next_pos;
}
