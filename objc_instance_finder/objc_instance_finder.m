#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <malloc/malloc.h>

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

NSHashTable *find_instances_of_class_helper(NSArray *classes) {
	NSHashTable *instances = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsOpaquePersonality];
	
	vm_map_t task = mach_task_self();
	mach_vm_address_t address = 0;
	mach_vm_size_t size = 0;
	vm_region_basic_info_data_64_t info;
	mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT_64;
	mach_port_t object_name;
	
	while(mach_vm_region(task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCnt, &object_name) == KERN_SUCCESS) {
		if((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE)) {
			for(Class c in classes) {
				mach_vm_address_t ptr = address;
				while((ptr = (mach_vm_address_t)memmem((void *)ptr, address + size - ptr - 1, &c, sizeof(Class)))) {
					void *obj = (void *)ptr;
					if(is_objc_object(obj)) {
						[instances addObject:obj];
					}
					ptr++;
				}
			}
		}
		
		address += size;
	}
	
	return instances;
}

NSHashTable *find_instances_of_class(Class class, BOOL include_subclasses) {
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