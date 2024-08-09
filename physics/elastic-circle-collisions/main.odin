package main

import "core:log"
import "core:math"
import "core:math/rand"

import "vendor:raylib"

NUM_RENDER_PIXELS_X :: 800
NUM_RENDER_PIXELS_Y :: 600

main :: proc() {
	raylib.InitWindow(NUM_RENDER_PIXELS_X, NUM_RENDER_PIXELS_Y, "Hello");
	if raylib.IsWindowReady() {
		raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
		raylib.SetTargetFPS(60);
		
		all_particles     := make([]Particle, 200);
		all_particle_hues := make([]f32, len(all_particles));
		
		#no_bounds_check {
			for i := 0; i < len(all_particles); i += 1 {
				overlaps_any := true;
				max_iterations := 50;
				
				MAX_RADIUS :: 10;
				
				for overlaps_any && max_iterations >= 0 {
					all_particles[i].radius   = rand.float32_range(0.6, 1) * MAX_RADIUS;
					all_particles[i].mass     = square(all_particles[i].radius * 0.1);
					
					available_range := Vector2{ NUM_RENDER_PIXELS_X, NUM_RENDER_PIXELS_Y } * 0.5 - all_particles[i].radius;
					all_particles[i].center.x = rand.float32_range(-available_range.x, available_range.x);
					all_particles[i].center.y = rand.float32_range(-available_range.y, available_range.y);
					
					overlaps_any = false;
					for j := 0; j < i; j += 1 {
						if circles_overlap(all_particles[i].center, all_particles[i].radius, all_particles[j].center, all_particles[j].radius) {
							overlaps_any = true;
							break;
						}
					}
					
					max_iterations -= 1;
				}
				all_particles[i].velocity = {rand.float32_range(-1, 1), rand.float32_range(-1, 1)} * rand.float32_range(1, 3);
				all_particle_hues[i] = rand.float32_range(0, 366);
				
				if overlaps_any {
					log.warn("Could not place particle %i in a non-overlapping position.\n", i);
				}
			}
		}
		
		camera: raylib.Camera2D;
		camera.offset   = {NUM_RENDER_PIXELS_X, NUM_RENDER_PIXELS_Y} * 0.5;
		camera.target   = {};
		camera.rotation = 0.0;
		camera.zoom     = 1.0;
		
		for !raylib.WindowShouldClose() {
			// Simulate
			#no_bounds_check {
				// Resolve collisions between particles
				for i := 0; i < len(all_particles); i += 1 {
					for j := i + 1; j < len(all_particles); j += 1 {
						resolve_collision(&all_particles[i], &all_particles[j]);
					}
				}
				
				// Move particles and resolve collisions against walls
				for &p in all_particles {
					acceleration := Vector2{};
					p.velocity += acceleration;
					p.center   += p.velocity;
					
					if p.center.x > 0.5 * NUM_RENDER_PIXELS_X - p.radius {
						p.center.x = 0.5 * NUM_RENDER_PIXELS_X - p.radius;
						p.velocity.x *= -1;
					} else if p.center.x < -0.5 * NUM_RENDER_PIXELS_X + p.radius {
						p.center.x = -0.5 * NUM_RENDER_PIXELS_X + p.radius;
						p.velocity.x *= -1;
					}
					if p.center.y > 0.5 * NUM_RENDER_PIXELS_Y - p.radius {
						p.center.y = 0.5 * NUM_RENDER_PIXELS_Y - p.radius;
						p.velocity.y *= -1;
					} else if p.center.y < -0.5 * NUM_RENDER_PIXELS_Y + p.radius {
						p.center.y = -0.5 * NUM_RENDER_PIXELS_Y + p.radius;
						p.velocity.y *= -1;
					}
				}
			}
			
			// Render
			raylib.BeginDrawing();
			raylib.ClearBackground(raylib.RAYWHITE);
			
			raylib.BeginMode2D(camera);
			#no_bounds_check {
				for p, i in all_particles {
					saturation := clamp(p.radius * 0.04, 0, 1);
					brightness := clamp(length_of(p.velocity * 0.5), 0, 1);
					full_color := raylib.ColorFromHSV(all_particle_hues[i], saturation, brightness);
					line_color := raylib.ColorBrightness(full_color, -0.5);
					
					raylib.DrawCircleV(p.center, p.radius, full_color);
					raylib.DrawCircleLinesV(p.center, p.radius, line_color);
				}
			}
			raylib.EndMode2D();
			
			raylib.EndDrawing();
		}
	}
}

resolve_collision :: proc(a, b: ^Particle) {
	line_of_impact := b.center - a.center;
	center_distance_squared := dot(line_of_impact, line_of_impact);
	
	if center_distance_squared < square(a.radius + b.radius) {
		center_distance := math.sqrt(center_distance_squared);
		
		{
			// Push the particles out so they are not overlapping
			overlap := center_distance - (a.radius + b.radius);
			push_direction := vector2_from_direction_and_length(line_of_impact, overlap * 0.5);
			a.center += push_direction;
			b.center -= push_direction;
			
			// Correct the distance
			center_distance = a.radius + b.radius;
			center_distance_squared = square(center_distance);
			line_of_impact  = b.center - a.center;
		}
		
		mass_sum    := a.mass + b.mass;
		denominator := mass_sum * center_distance_squared;
		
		velocity_difference := b.velocity - a.velocity;
		numerator_a := 2*b.mass * dot( velocity_difference,  line_of_impact);
		numerator_b := 2*a.mass * dot(-velocity_difference, -line_of_impact);
		
		delta_velocity_a :=  line_of_impact * (numerator_a / denominator);
		delta_velocity_b := -line_of_impact * (numerator_b / denominator);
		
		a.velocity += delta_velocity_a;
		b.velocity += delta_velocity_b;
	}
}

circles_overlap :: proc(center_a: Vector2, radius_a: f32, center_b: Vector2, radius_b: f32) -> (res: bool) {
	center_distance_squared := distance_squared_between(center_a, center_b);
	radii_sum_squared       := square(radius_a + radius_b);
	
	res = center_distance_squared < radii_sum_squared;
	return;
}

vector2_from_direction_and_length :: proc(direction: Vector2, length: f32) -> (v: Vector2) {
	direction_length := length_of(direction);
	
	v = direction / direction_length * length;
	return v;
}

length_squared_of :: proc(v: Vector2) -> (d: f32) {
	d = dot(v, v);
	return d;
}

length_of :: proc(v: Vector2) -> (d: f32) {
	d = math.sqrt(length_squared_of(v));
	return d;
}

distance_squared_between :: proc(u, w: Vector2) -> (d: f32) {
	d = length_squared_of(w - u);
	return d;
}

dot :: proc(u, w: Vector2) -> (d: f32) {
	d = u.x * w.x + u.y * w.y;
	return d;
}

square :: proc(x: f32) -> (x_squared: f32) {
	x_squared = x * x;
	return x_squared;
}

Particle :: struct {
	center,
	velocity: Vector2,
	mass,
	radius: f32,
}

Vector2 :: [2]f32

/* References:

- The Coding Train's video:
https://www.youtube.com/watch?v=dJNFPv9Mj-Y

- Elastic Collision's wikipedia page:
https://en.wikipedia.org/wiki/Elastic_collision

- 2-Dimensional Elastic Collisions without Trigonometry:
https://www.vobarian.com/collisions/2dcollisions2.pdf

- Elastic Collisions Formula Derivation:
https://dipamsen.github.io/notebook/collisions.pdf

For your "overlap correction", I think the proper way to go is to get the particles' relative velocities along the impact vector. Based on this relative velocity and the magnitude of the overlap, you can then compute the time dt by which your simulation overshot the actual collision due to finite framerates, backpropagate the particles by this time step, then update the velocities, and move them forward in time by dt again. - killermonkey1392
*/
