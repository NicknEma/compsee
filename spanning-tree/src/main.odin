package st

import "base:runtime"

import "core:fmt"
import "core:container/intrusive/list"
import "core:strings"
import slices "core:slice"
import "core:math/rand"

import "vendor:raylib"

main :: proc() {
	graph: Graph;
	graph.vertices = make([dynamic]Vertex);
	
	spanning_tree: []Edge;
	
	raylib.InitWindow(800, 600, "Spanning Tree");
	if raylib.IsWindowReady() {
		raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
		raylib.SetTargetFPS(60);
		
		edge_entropy := rand.create(36169649);
		dragged_vertex_index := -1;
		
		for !raylib.WindowShouldClose() {
			if raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {
				pos := raylib.GetMousePosition();
				
				min_dis := f32(math.F32_MAX);
				the_vertex: int;
				for vertex, vertex_index in graph.vertices {
					dis := distance_between(vertex.pos, pos);
					if min_dis > dis {
						min_dis = dis;
						the_vertex = vertex_index;
					}
				}
				
				if min_dis > 2*VERTEX_RADIUS {
					// Clicked on an empty space, create a new vertex.
					
					append(&graph.vertices, Vertex{pos});
					
					num_vertices := len(graph.vertices);
					for i in 0..<num_vertices - 1 {
						j := num_vertices - 1;
						dis := distance_between(graph.vertices[i].pos, graph.vertices[j].pos);
						
						GetRenderDiagonal :: proc() -> f32 {
							w := f32(raylib.GetRenderWidth());
							h := f32(raylib.GetRenderHeight());
							
							return length_of(raylib.Vector2{ w, h });
						}
						
						diagonal := GetRenderDiagonal();
						if rand.float32_range(0, diagonal, &edge_entropy) < (diagonal - 2*dis) {
							// Add edge.
							
							if graph.edge_weights[i][j] == 0 {
								assert(graph.edge_weights[j][i] == 0);
								
								weight := rand.float32_range(1, 5, &edge_entropy);
								
								graph.edge_weights[i][j] = weight;
								graph.edge_weights[j][i] = weight;
							} else {
								fmt.printf("Edge between %i and %i already exists.\n", i, j);
							}
						}
					}
				} else if min_dis <= 1.1*VERTEX_RADIUS {
					// Clicked on a vertex, mark it as being dragged.
					
					dragged_vertex_index = the_vertex;
				}
			}
			
			if raylib.IsMouseButtonReleased(raylib.MouseButton.LEFT) {
				// Stop dragging the vertex.
				
				dragged_vertex_index = -1;
			}
			
			if raylib.IsMouseButtonDown(raylib.MouseButton.LEFT) {
				// Continue dragging the vertex.
				
				if dragged_vertex_index > -1 {
					assert(dragged_vertex_index < len(graph.vertices));
					
					GetRenderRectangle :: proc() -> raylib.Rectangle {
						result: raylib.Rectangle;
						
						result.x      = 0;
						result.y      = 0;
						result.width  = f32(raylib.GetRenderWidth());
						result.height = f32(raylib.GetRenderHeight());
						
						return result
					}
					
					render_rect := GetRenderRectangle();
					
					pos := raylib.GetMousePosition();
					if rectangle_contains(shrink_sub(render_rect, VERTEX_RADIUS), pos) {
						graph.vertices[dragged_vertex_index].pos = pos;
					}
				}
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
				if len(graph.vertices) > 0 {
					spanning_tree = kruskal(graph);
				}
			}
			
			raylib.BeginDrawing();
            raylib.ClearBackground(raylib.RAYWHITE);
			
			for row in 0..<len(graph.vertices) {
				for col in 0..<row {
					if graph.edge_weights[row][col] != 0 {
						start  := graph.vertices[row].pos;
						end    := graph.vertices[col].pos;
						weight := graph.edge_weights[row][col];
						thick  := 0.8 * weight;
						raylib.DrawLineEx(start, end, thick, raylib.GRAY);
						
						cstring_from_f32 :: proc(x: f32, allocator := context.allocator, loc := #caller_location) -> (s: cstring) {
							b := strings.builder_make(allocator, loc);
							strings.write_f32(&b, x, 'f');
							strings.write_byte(&b, 0);
							s = strings.unsafe_string_to_cstring(strings.to_string(b));
							return
						}
						
						weight_font_size := i32(10);
						weight_text := cstring_from_f32(weight, context.temp_allocator);
						text_w := raylib.MeasureText(weight_text, weight_font_size);
						text_h := weight_font_size;
						text_p := lerp(start, end, 0.5);
						
						raylib.DrawRectangle(i32(text_p.x - 3), i32(text_p.y - 3), text_w + 3, text_h + 3, raylib.WHITE);
						raylib.DrawText(weight_text, i32(text_p.x), i32(text_p.y), weight_font_size, raylib.DARKGRAY);
					}
				}
			}
			
			if spanning_tree != nil {
				for e in spanning_tree {
					row := e[0];
					col := e[1];
					assert(graph.edge_weights[row][col] != 0);
					
					start := graph.vertices[row].pos;
					end   := graph.vertices[col].pos;
					thick := 1.2 * graph.edge_weights[row][col];
					raylib.DrawLineEx(start, end, thick, raylib.RED);
				}
			}
			
            for vertex in graph.vertices {
				color_1, color_2 : raylib.Color;
				raylib.DrawCircleGradient(i32(vertex.pos.x), i32(vertex.pos.y), VERTEX_RADIUS, raylib.GREEN, raylib.DARKGREEN);
			}
			
			raylib.EndDrawing();
		}
	}
	
	allow_break();
}

int_max_except :: proc(n, x: int, r: ^rand.Rand = nil) -> (val: int) {
	MAX_ATTEMPTS :: 30;
	num_attempts :=  0;
	
	val = x;
	for val == x && num_attempts < MAX_ATTEMPTS {
		val = rand.int_max(n, r);
	}
	
	return
}

distance_between :: proc(u, w: raylib.Vector2) -> (result: f32) {
	result = length_of(u - w);
	return
}

import "core:math"
length_of :: proc(v: raylib.Vector2) -> (result: f32) {
	result = math.sqrt(dot_product_between(v, v));
	return
}

dot_product_between :: proc(u, w: raylib.Vector2) -> (result: f32) {
	result = u.x*w.x + u.y*w.y;
	return
}

rectangle_contains :: proc(rectangle: raylib.Rectangle, point: raylib.Vector2) -> (result: bool) {
	result_x := rectangle.x <= point.x && point.x <= rectangle.width;
	result_y := rectangle.y <= point.y && point.y <= rectangle.height;
	
	result = result_x && result_y;
	return
}

lerp :: proc{ lerp_vector2f }
lerp_vector2f :: proc(a, b: raylib.Vector2, t: f32) -> (result: raylib.Vector2) {
	result = a*(1 - t) + b*t;
	return
}

shrink_sub :: proc(rectangle: raylib.Rectangle, term: f32) -> (result: raylib.Rectangle) {
	result = rectangle;
	
	result.x += term;
	result.width -= term;
	
	result.y += term;
	result.height -= term;
	
	return
}

VERTEX_RADIUS :: 20
Vertex :: struct {
	pos: raylib.Vector2,
}

N :: 100;
Graph :: struct {
	vertices: [dynamic]Vertex,
	edge_weights: [N][N]f32,
}

Sorted_Edge :: struct {
	weight: f32,
	row, col: int,
}

sort_edges :: proc(graph: Graph, allocator := context.allocator, loc := #caller_location) -> (sorted_edges: []Sorted_Edge) {
	capacity :: (N*N - N) / 2;
	
	edges := make([]Sorted_Edge, capacity, allocator, loc);
	count := 0;
	
	for row in 0..<N {
		for col in 0..<row {
			exists := graph.edge_weights[row][col] != 0;
			if exists {
				edges[count] = Sorted_Edge{graph.edge_weights[row][col], row, col};
				count += 1;
			}
		}
	}
	
	weighs_less :: proc(i, j: Sorted_Edge) -> bool {
		return i.weight < j.weight;
	}
	
	slices.sort_by(edges[:count], weighs_less);
	return edges[:count];
}

Edge :: [2]int
kruskal :: proc(graph: Graph) -> []Edge {
	// This is the predecessors vector. It's a forest
	// at first, but it becomes a tree at the end.
	forest := make_set_partition(int);
	
	for vertex in 0..<N {
		make_set(&forest, vertex);
	}
	
	sorted_edges := sort_edges(graph, context.temp_allocator);
	edges := make([dynamic]Edge);
	
	// Visualization starts here.
	
	for e in sorted_edges {
		i := e.row;
		j := e.col;
		
		cycle_with_i, found_i := find_set(&forest, i);
		cycle_with_j, found_j := find_set(&forest, j);
		
		// We can assume that we found the sets since at the beginning
		// we added all the vertices.
		assert(found_j && found_j);
		
		if cycle_with_i != cycle_with_j {
			// The vertices belong to separate trees in the forest:
			// Adding this edge will not create a cycle.
			
			merge_sets(&forest, cycle_with_i, cycle_with_j);
			append(&edges, Edge{i,j});
		}
	}
	
	return edges[:len(edges)];
}

allow_break :: proc "contextless" () { }
