#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <malloc/malloc.h>
#include <mach/mach_vm.h>

Class *get_objc_class_list(int *count) {
	static Class *cache = NULL;
	static int cache_size = 0;

	*count = objc_getClassList(NULL, 0);
	if(cache) {
		if(cache_size == *count) {
			return cache;
		} else {
			free(cache);
		}
	}

	cache = (Class *)malloc(sizeof(Class) * *count);
	objc_getClassList(cache, *count);
	return cache;
}

bool is_objc_class(const void *address) {
	if(!address) {
		return false;
	}

	int class_count;
	Class *classes = get_objc_class_list(&class_count);
	for(int i = 0; i < class_count; i++) {
		void *class = classes[i];
		if(address == class) {
			return true;
		}
		void *meta_class = *(void **)class;
		if(address == meta_class) {
			return true;
		}
	}

	return false;
}

bool is_objc_object(const void *address) {
	if(!address) {
		return false;
	}

	if(is_objc_class(address)) {
		return true;
	}

	// We already know that the input is a pointer to a class
	// so we can safely de-reference it
	void *class = *(void **)address;
	if(!is_objc_class(class)) {
		return false;
	}

	size_t msize = malloc_size(address);
	size_t isize = class_getInstanceSize(class);

	return msize >= isize;
}

BOOL is_class_recursive_subclass(Class class, Class superclass) {
	do {
		if(class == superclass) {
			return YES;
		}
	} while((class = class_getSuperclass(class)));

	return NO;
}

void malloc_enumerator(task_t task, void *data, unsigned type, vm_range_t *ranges, unsigned count) {
	NSArray *array = (NSArray *)data;
	NSArray *classes = array[0];
	NSHashTable *instances = array[1];

	for(unsigned i = 0; i < count; i++) {
		vm_range_t range = ranges[i];
		void *obj = (void *)range.address;
		void *class = *(void **)obj;
		if([classes indexOfObjectIdenticalTo:class] != NSNotFound && is_objc_object(obj)) {
			[instances addObject:obj];
		}
	}
}

kern_return_t memory_reader(task_t remote_task, vm_address_t remote_address, vm_size_t size, void **local_memory) {
	*local_memory = (void *)remote_address;
	return KERN_SUCCESS;
}

NSHashTable *find_instances_of_class_helper(NSArray *classes) {
	NSHashTable *instances = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality];

	task_t task = mach_task_self();

	vm_address_t *malloc_zone_addresses;
	unsigned malloc_zone_count;
	kern_return_t ret = malloc_get_all_zones(task, memory_reader, &malloc_zone_addresses, &malloc_zone_count);
	if(ret != KERN_SUCCESS) {
		return instances;
	}

	NSArray *array = @[classes, instances];

	for(int i = 0; i < malloc_zone_count; i++) {
		malloc_zone_t *zone = (malloc_zone_t *)malloc_zone_addresses[i];
		if(zone && zone->introspect && zone->introspect->enumerator) {
			zone->introspect->enumerator(task, array, MALLOC_PTR_IN_USE_RANGE_TYPE, (vm_address_t)zone, memory_reader, malloc_enumerator);
		}
	}

	return instances;
}

NSHashTable *find_instances_of_class(Class class, BOOL include_subclasses) {
	if(!is_objc_class(class)) {
		return [NSHashTable new];
	}

	NSHashTable *instances;
	NSMutableArray *possible_classes = [NSMutableArray new];

	@autoreleasepool {
		[possible_classes addObject:class];

		if(include_subclasses) {
			int class_count;
			Class *classes = get_objc_class_list(&class_count);
			for(int i = 0; i < class_count; i++) {
				Class c = classes[i];
				if(is_class_recursive_subclass(c, class)) {
					[possible_classes addObject:c];
				}
			}
		}

		instances = [find_instances_of_class_helper(possible_classes) retain];
	}

	return instances;
}
