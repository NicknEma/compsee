/*
Disjoint-set data structures support three operations:
- Making a new set containing a new element;
- Finding the representative of the set containing a given element;
- Merging two sets.
*/
package st;

import "base:runtime"

Set :: struct {
	parent_index,
	size: int,
}

Set_Partition :: struct($T: typeid) {
	index_map: map[T]int,
	elements: #soa[dynamic]Set,
}

make_set_partition_def :: proc($T: typeid, allocator := context.allocator, loc := #caller_location) -> (partition: Set_Partition(T), err: runtime.Allocator_Error) #optional_allocator_error {
	partition.index_map, err = make(map[T]int, allocator = allocator, loc = loc);
	if err == .None {
		// partition.elements, err = make(#soa[dynamic]Set, allocator = allocator, loc = loc)
	}
	
	return
}

make_set_partition :: proc {
	make_set_partition_def,
}

/*
Adds a new set to the partition, only containing one element. If the element is already
in a set, it does nothing.

The set is added in O(1) time complexity, not including the possible allocation.

*Allocates using the allocator passed in to `make_set_partition`*

Inputs:
- partition: The set partition where the new set should be added.
- element: The only element of the new set.
- loc: A source code location, for debugging purposes. Default is `#caller_location`.

Returns:
- err: An optional allocator error if one occurred, nil otherwise.
*/
make_set :: proc(partition: ^Set_Partition($T), element: T, loc := #caller_location) -> (err: runtime.Allocator_Error) {
	if  element not_in partition.index_map {
		index := len(partition.elements);
		
		partition.index_map[element] = index;
		set := Set{ index, 1 };
		_, err = append_soa(&partition.elements, set, loc = loc)
    }
	
	return
}

/*
Given an element, it finds the index of the "root" of the set containing it.
This root can be used to check if two elements are in the same set.

The set is fount in amortized O(1) time complexity.

Inputs:
- partition: The set partition containing the set to be found.
- element: An element of the set to be found.

Returns:
- root: The index of the root set.
- found: `true` if the element was in one of the sets of the partition, `false` otherwise.
*/
find_set :: proc(partition: ^Set_Partition($T), element: T) -> (root: int, found: bool) {
	if element in partition.index_map {
		found  = true;
		
		index := partition.index_map[element];
		root   = find_set_by_index(partition, index)
	}
	
	find_set_by_index :: proc(partition: ^Set_Partition($T), index: int) -> (root: int) {
		if partition.elements[index].parent_index != index {
			// The set has multiple elements, go grab the root. Optimize the
			// shape of the tree on the way.
			
			partition.elements[index].parent_index = find_set_by_index(partition, partition.elements[index].parent_index);
			root = partition.elements[index].parent_index
		} else {
			// The set only contains 1 element, return that (its index).
			
			root = index
		}
		
		return
	}
	
	return
}

/*
Given two elements, it merges the two sets they are contained in (set union).

*Does not allocate.*

Inputs:
- partition: The set partition containing the two sets to be merged.
- element_a, element_b: An element for each of the sets to be merged.

Returns:
- found: `true` if both elements were contained in the partition, `false` otherwise.
*/
merge_sets :: proc(partition: ^Set_Partition($T), element_a, element_b: int) -> (found: bool) {
    a, found_a := find_set(partition, element_a);
	b, found_b := find_set(partition, element_b);
	
	if found_a && found_b {
		found = true;
		
		if a != b {
			// If necessary, swap variables to ensure that 'a' has at least as many descendants as 'b'.
			if partition.elements[a].size < partition.elements[b].size {
				t := a; a = b; b = t
			}
			
			// Make 'a' the new root.
			partition.elements[b].parent_index = a;
			
			// Update the size of 'a'.
			partition.elements[a].size += partition.elements[b].size
		} else {
			// 'a' and 'b' are already in the same set: nothing to do.
		}
	}
	
    return
}
