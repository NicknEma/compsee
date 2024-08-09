package searches;

import "core:os";
import "core:fmt";
import "core:math/rand";
import slices "core:slice";

// @Speed: Add inline directives and contextless attributes to most functions.

main :: proc() {
	handle: os.Handle;
	if len(os.args) > 1 {
		errno: os.Errno;
		handle, errno = os.open(os.args[1], os.O_CREATE|os.O_WRONLY);
		if errno != 0 {
			fmt.println("Could not open file ", os.args[1], ", using stdout", sep = "");
			handle = os.stdout;
		}
	}
	
	ARRAY_SIZE :: 32;
	array: [ARRAY_SIZE]u32;
	value: u32;
	
	my_seed := u64(1);
	my_rand := rand.create(my_seed);
	
	// Unsorted, present
	populate_array(array[:], &my_rand);
	
	value = get_random_present(array[:], &my_rand);
	assert(slices.contains(array[:], value));
	
	linear_search(handle, array[:], value);
	
	// Sorted, present
	slices.sort(array[:]);
	binary_search(handle, array[:], value);
	
	// Unsorted, not present
	populate_array(array[:], &my_rand);
	
	value = get_random_non_present(array[:], &my_rand);
	assert(!slices.contains(array[:], value));
	
	linear_search(handle, array[:], value);
	
	// Sorted, not present
	slices.sort(array[:]);
	binary_search(handle, array[:], value);
}

//~ Setup helpers

populate_array :: proc(a: []u32, r: ^rand.Rand = nil) #no_bounds_check {
	for i in 0..<len(a) {
		a[i] = rand.uint32(r);
	}
}

@(require_results)
get_random_present :: proc(array: []u32, r: ^rand.Rand = nil) -> (value: u32) #no_bounds_check {
	value = array[rand.uint32(r) % u32(len(array))];
	return;
}

@(require_results)
get_random_non_present :: proc(array: []u32, r: ^rand.Rand = nil) -> (value: u32, found: bool) #optional_ok {
	MAX_ITERATIONS :: 30;
	iterations := 0;
	
	for {
		value = rand.uint32();
		iterations += 1;
		
		if !slices.contains(array, value) || iterations == MAX_ITERATIONS {
			found = (iterations != MAX_ITERATIONS);
			break;
		}
	}
	
	return;
}

//~ Searches

linear_search :: proc(handle: os.Handle, array: []u32, value: u32, do_updates: bool = true) -> (at: int, iterations: int) {
	if do_updates {
		ppm_update(ppm_image[:], array);
		ppm_write_n_times(handle, ppm_image[:], 10);
	}
	
	at = -1;
	
	for _, index in array {
		if do_updates {
			ppm_update(ppm_image[:], array, index, value);
			ppm_write_n_times(handle, ppm_image[:], FRAMES_PER_ITERATION);
		}
		
		iterations += 1;
		
		if value == array[index] {
			at = index;
			break;
		}
	}
	
	if do_updates do ppm_write_n_times(handle, ppm_image[:], 8);
	return;
}
binary_search :: proc(handle: os.Handle, array: []u32, value: u32, do_updates: bool = true) -> (at: int, iterations: int) {
	if do_updates {
		ppm_update(ppm_image[:], array);
		ppm_write_n_times(handle, ppm_image[:], 10);
	}
	
	at = -1;
	
	lo := 0;
	hi := len(array) - 1;
	
	index: int;
	for lo <= hi {
		index = ((hi + lo) / 2);
		assert(index >= lo && index <= hi);
		
		if do_updates {
			ppm_update(ppm_image[:], array, index, value);
			ppm_write_n_times(handle, ppm_image[:], FRAMES_PER_ITERATION);
		}
		
		iterations += 1;
		
		if value == array[index] {
			at = index;
			break;
		} else if value < array[index] {
			hi = index - 1;
		} else {
			lo = index + 1;
		}
	}
	
	if do_updates do ppm_write_n_times(handle, ppm_image[:], 8);
	return;
}

test_binary_search :: proc() {
	array: [32]u32;
	
	for seed in 0..<10 {
		r := rand.create(u64(seed));
		populate_array(array[:], &r);
		slices.sort(array[:]);
		
		value := get_random_present(array[:], &r);
		at, iterations := binary_search(0, array[:], value, false);
		
		assert(at != -1);
		assert(iterations < len(array));
		
		value = get_random_non_present(array[:], &r);
		at, iterations = binary_search(0, array[:], value, false);
		
		assert(at == -1);
		assert(iterations < len(array));
	}
	
	fmt.println("Finished testing binary_search.");
}

FRAMES_PER_ITERATION :: 2;

//~ Output
ppm_write :: proc(handle: os.Handle, image: []u8) {
	fmt.fprintf(handle, "P6\n%d %d\n255\n", PPM_IMAGE_SIZE_X, PPM_IMAGE_SIZE_Y);
    fmt.fprintf(handle, "%s", image, flush = true);
}
ppm_write_n_times :: proc(handle: os.Handle, image: []u8, times: int) {
	for _ in 0..<times {
		ppm_write(handle, image);
	}
}

ppm_update :: proc(image: []u8, array: []u32, index: int = -1, value: u32 = 0) {
	BACKGROUND_COLOR :: Color(0xAABBCC);
	MARGIN_PIXELS    :: 10.0;
	
	ppm_image_fill(image, BACKGROUND_COLOR);
	
	// @Speed: All these values computed here outside the loop never change for a given array. Some never change at all.
	max_value := slices.max(array);
	
	usable_width := f32(PPM_IMAGE_SIZE_X - 2 * MARGIN_PIXELS);
	single_width_unpadded := usable_width / f32(len(array));
	
	padding_pixels := single_width_unpadded / 10.0;
	dim_x := single_width_unpadded - 2 * padding_pixels;
	
	remap_start := MARGIN_PIXELS + single_width_unpadded / 2;
	remap_end   := PPM_IMAGE_SIZE_X - remap_start;
	
	usable_height := f32(PPM_IMAGE_SIZE_Y - 2 * MARGIN_PIXELS);
	min_y := f32(MARGIN_PIXELS);
	
	for v, i in array {
		mid_x := remap_f32(0.0, f32(len(array) - 1), f32(i), remap_start, remap_end);
		min_x := mid_x - dim_x / 2;
		
		dim_y := remap_f32(0.0, f32(max_value), f32(v), MARGIN_PIXELS, usable_height);
		ppm_image_fill_rectangle_min_dim(image, min_x, min_y, dim_x, dim_y, BLUE);
		
		if index > -1 && index == i {
			mid_x = remap_f32(0.0, f32(len(array) - 1), f32(index), remap_start, remap_end);
			min_x = mid_x - dim_x / 2;
			
			dim_y = remap_f32(0.0, f32(max_value), f32(value), MARGIN_PIXELS, usable_height);
			
			color: Color;
			if value == array[index] {
				color = GREEN;
			} else {
				color = RED;
			}
			
			ppm_image_draw_rectangle_min_dim(image, min_x, min_y, dim_x, dim_y, 4, color);
		}
	}
}

//~ Math helpers

@(require_results)
lerp_f32 :: proc(min, max, t: f32) -> (res: f32) {
	res = min * (1 - t) + max * t;
	return;
}

@(require_results)
unlerp_f32 :: proc(min, max, t: f32) -> (res: f32) {
	res = (t - min) / (max - min);
	return;
}

@(require_results)
remap_f32 :: proc(min_start, max_start, t, min_end, max_end: f32) -> (res: f32) {
	rel := unlerp_f32(min_start, max_start, t);
	res  = lerp_f32(min_end, max_end, rel);
	return;
}

//~ Colors

Color :: distinct u32;
RED   :: Color(0xFF0000);
GREEN :: Color(0x00FF00);
BLUE  :: Color(0x0000FF);

pack_color :: proc(r, g, b: f32) -> (color: Color) {
	color = Color(i32(r * 255.0 + 0.5) << 16 |
				  i32(g * 255.0 + 0.5) <<  8 |
				  i32(b * 255.0 + 0.5) <<  0);
	
    return;
}
unpack_color :: proc(color: Color) -> (r, g, b: f32) {
	INV_255 :: 1.0 / 255.0;
	r = (f32((color >> 16) & 0xff) * INV_255);
    g = (f32((color >>  8) & 0xff) * INV_255);
    b = (f32((color >>  0) & 0xff) * INV_255);
	
	return;
}

//~ Image

PPM_IMAGE_SIZE_X :: 800;
PPM_IMAGE_SIZE_Y :: 800;
ppm_image: [PPM_IMAGE_SIZE_X * PPM_IMAGE_SIZE_Y * 3]u8;

// @Speed: Skip calls to set_pixel and inline it manually

ppm_image_set_pixel :: proc(image: []u8, x, y: int, r, g, b: u8) #no_bounds_check {
	image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 0] = r;
    image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 1] = g;
    image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 2] = b;
}

@(require_results)
ppm_image_get_pixel :: proc(image: []u8, x, y: int) -> (color: Color) #no_bounds_check {
	r := image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 0];
    g := image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 1];
    b := image[y * PPM_IMAGE_SIZE_X * 3 + x * 3 + 2];
	color = Color((r << 16) |
				  (g <<  8) |
				  (b <<  0));
    return;
}

//~ Draw helpers

ppm_image_fill :: proc(image: []u8, color: Color) {
	r := u8((color >> 16) & 0xFF);
	g := u8((color >>  8) & 0xFF);
	b := u8((color >>  0) & 0xFF);
	
	for y in 0..<PPM_IMAGE_SIZE_Y {
		for x in 0..<PPM_IMAGE_SIZE_X {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
	}
}

ppm_image_fill_rectangle_min_max :: proc(image: []u8, min_x, min_y, max_x, max_y: f32, color: Color) {
	r := u8((color >> 16) & 0xFF);
	g := u8((color >>  8) & 0xFF);
	b := u8((color >>  0) & 0xFF);
	
	min_xi := int(min_x);
	min_yi := int(min_y);
	max_xi := int(max_x);
	max_yi := int(max_y);
	
	assert(min_xi >= 0);
	assert(min_yi >= 0);
	assert(max_xi <= PPM_IMAGE_SIZE_X);
	assert(max_yi <= PPM_IMAGE_SIZE_Y);
	
	for y in min_yi..<max_yi {
		for x in min_xi..<max_xi {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
	}
}

ppm_image_fill_rectangle_min_dim :: proc(image: []u8, min_x, min_y, dim_x, dim_y: f32, color: Color) {
	max_x := min_x + dim_x;
	max_y := min_y + dim_y;
	
	ppm_image_fill_rectangle_min_max(image, min_x, min_y, max_x, max_y, color);
}

ppm_image_draw_rectangle_min_max :: proc(image: []u8, min_x, min_y, max_x, max_y: f32, thickness: int, color: Color) {
	r := u8((color >> 16) & 0xFF);
	g := u8((color >>  8) & 0xFF);
	b := u8((color >>  0) & 0xFF);
	
	min_xi := int(min_x);
	min_yi := int(min_y);
	max_xi := int(max_x);
	max_yi := int(max_y);
	
	pause_x  := min_xi + thickness;
	resume_x := max_xi - thickness;
	
	pause_y  := min_yi + thickness;
	resume_y := max_yi - thickness;
	
	assert(min_xi >= 0);
	assert(min_yi >= 0);
	assert(max_xi <= PPM_IMAGE_SIZE_X);
	assert(max_yi <= PPM_IMAGE_SIZE_Y);
	
	// Top edge
	for y in min_yi..<pause_y {
		for x in min_xi..<max_xi {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
	}
	
	// Left and right edges
	for y in pause_y..<resume_y {
		for x in min_xi..<pause_x {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
		for x in resume_x..<max_xi {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
	}
	
	// Bottom edge
	for y in resume_y..<max_yi {
		for x in min_xi..<max_xi {
			ppm_image_set_pixel(image, x, y, r, g, b);
		}
	}
}

ppm_image_draw_rectangle_min_dim :: proc(image: []u8, min_x, min_y, dim_x, dim_y: f32, thickness: int, color: Color) {
	max_x := min_x + dim_x;
	max_y := min_y + dim_y;
	
	ppm_image_draw_rectangle_min_max(image, min_x, min_y, max_x, max_y, thickness, color);
}
