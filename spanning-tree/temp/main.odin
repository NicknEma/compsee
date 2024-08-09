package temp

main :: proc() {
	Baz :: struct { a, b: int }
	
	Bar :: [dynamic]Baz;
	bar: Bar;
	
	append(&bar, Baz{0, 0});
	append(&bar, Baz{1, 1});
	append(&bar, Baz{2, 2});
	
	bar[1].a += 1;
	
	foo :: proc(b: Bar) {
		b[1].a += 1;
	}
	
	foo(bar);
	
	x := 0;
}
