package main

import "core:log"
import "core:math/rand"

import "vendor:raylib"

NUM_RENDER_PIXELS_X :: 800
NUM_RENDER_PIXELS_Y :: 600

main :: proc() {
	raylib.InitWindow(NUM_RENDER_PIXELS_X, NUM_RENDER_PIXELS_Y, "Fisher-Yates shuffle");
	if raylib.IsWindowReady() {
		raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
		raylib.SetTargetFPS(60);
		
		camera: raylib.Camera2D;
		camera.offset   = {NUM_RENDER_PIXELS_X, NUM_RENDER_PIXELS_Y} * 0.5;
		camera.target   = {};
		camera.rotation = 0.0;
		camera.zoom     = 1.0;
		
		FONT_SIZE      :: 20;
		TEXT_SPACING   :: 10;
		
		PADDING_PIXELS :: 10;
		
		MAX_BAR_HEIGHT :: NUM_RENDER_PIXELS_Y - 2*PADDING_PIXELS - (FONT_SIZE + PADDING_PIXELS);
		
		PADDED_WIDTH   :: NUM_RENDER_PIXELS_X - 2*PADDING_PIXELS; // 780
		BAR_COUNT      :: 100;
		BAR_SPACING    :: 2.0;
		TOTAL_SPACING  :: BAR_SPACING * (BAR_COUNT - 1); // 198
		BAR_WIDTH      :: (PADDED_WIDTH - TOTAL_SPACING) / BAR_COUNT; // 5.82
		#assert(TOTAL_SPACING < PADDED_WIDTH);
		#assert(BAR_WIDTH * BAR_COUNT + BAR_SPACING * (BAR_COUNT - 1) - PADDED_WIDTH <  0.1 ||
				BAR_WIDTH * BAR_COUNT + BAR_SPACING * (BAR_COUNT - 1) - PADDED_WIDTH > -0.1);
		
		array, make_error := make([]f32, BAR_COUNT);
		if make_error != .None {
			log.errorf("Could not allocate %i floats.\n", int(BAR_COUNT));
			return;
		}
		
		shuffle_context: Shuffle_Array_Context;
		
		START_DELAY :: 1.0;
		TOTAL_SHUFFLE_SECONDS   :: 7.0; // @FixMe: The actual measured time is different, I don't know why.
		SECONDS_BETWEEN_UPDATES :: TOTAL_SHUFFLE_SECONDS / BAR_COUNT;
		
		time_since_last_array_update: f32;
		time_to_wait_for_next_update: f32;
		
		reset_all :: proc(array: []f32, shuffle_context: ^Shuffle_Array_Context, time_since_last_array_update, time_to_wait_for_next_update: ^f32) {
			for i := 0; i < len(array); i += 1 {
				normalized_i := f32(i + 1) / f32(len(array));
				assert(normalized_i <= 1);
				
				array[i] = (normalized_i) * MAX_BAR_HEIGHT;
			}
			
			shuffle_context.random_index  = len(array);
			shuffle_context.next_index    = len(array);
			shuffle_context.done          = false;
			
			time_to_wait_for_next_update^ = START_DELAY;
			time_since_last_array_update^ = 0;
		}
		
		reset_all(array, &shuffle_context, &time_since_last_array_update, &time_to_wait_for_next_update);
		
		for !raylib.WindowShouldClose() {
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.R) {
				reset_all(array, &shuffle_context, &time_since_last_array_update, &time_to_wait_for_next_update);
			}
			
			if !shuffle_context.done {
				delta_time := raylib.GetFrameTime();
				
				if time_since_last_array_update > time_to_wait_for_next_update {
					shuffle_array_iterate(array, &shuffle_context);
					
					time_to_wait_for_next_update = SECONDS_BETWEEN_UPDATES;
					time_since_last_array_update = 0;
				}
				
				time_since_last_array_update += delta_time;
			}
			
			// Render
			BACKGROUND_COLOR :: raylib.Color{ 0x22, 0x22, 0x22, 0xFF };
			
			raylib.BeginDrawing();
			raylib.ClearBackground(BACKGROUND_COLOR);
			
			raylib.DrawTextEx(raylib.GetFontDefault(), "Press R to reset", Vector2{ PADDING_PIXELS, PADDING_PIXELS }, FONT_SIZE, TEXT_SPACING, raylib.LIGHTGRAY);
			
			raylib.BeginMode2D(camera);
			
			for i := 0; i < len(array); i += 1 {
				rect: raylib.Rectangle;
				rect.x      = PADDING_PIXELS + (f32(i) * (BAR_WIDTH + BAR_SPACING)) - 0.5*NUM_RENDER_PIXELS_X;
				rect.y      = NUM_RENDER_PIXELS_Y - array[i] - (0.5*NUM_RENDER_PIXELS_Y + PADDING_PIXELS);
				rect.width  = BAR_WIDTH;
				rect.height = array[i];
				
				bar_color := raylib.WHITE;
				if !shuffle_context.done {
					if i == shuffle_context.random_index || i == shuffle_context.next_index {
						bar_color = raylib.RED;
					}
				}
				
				raylib.DrawRectangleRec(rect, bar_color);
			}
			
			raylib.EndMode2D();
			
			raylib.EndDrawing();
		}
	}
}

Shuffle_Array_Context :: struct {
	next_index, random_index: int,
	done: bool,
}

shuffle_array_iterate :: proc(a: []f32, c: ^Shuffle_Array_Context) {
	if c.next_index == 0 {
		c.done = true;
		
		c.next_index   = len(a);
		c.random_index = len(a);
		return;
	}
	
	c.random_index = rand.int_max(c.next_index);
	c.next_index  -= 1;
	
	a[c.random_index], a[c.next_index] = a[c.next_index], a[c.random_index];
}

Vector2 :: [2]f32
