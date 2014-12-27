#include <Foundation/Foundation.h>

#include "objc_instance_finder.h"

@interface TestClass : NSObject
@end
@implementation TestClass
@end

@interface TestSubClass : TestClass
@end
@implementation TestSubClass
@end

#define NSLog(args...) puts([[NSString stringWithFormat:args] UTF8String])

extern bool is_objc_object(const void *address);

void test(Class class, BOOL include_subclasses, NSArray *knownInstances) {
	NSHashTable *instances = find_instances_of_class(class, include_subclasses);

	for(id obj in instances) {
		if(include_subclasses) {
			assert([obj isKindOfClass:class]);
		} else {
			assert([obj class] == class);
		}
	}

	NSHashTable *knownInstancesTable = [[NSHashTable alloc] initWithOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality capacity:knownInstances.count];
	for(id obj in knownInstances) {
		[knownInstancesTable addObject:obj];
	}
	assert([knownInstancesTable isSubsetOfHashTable:instances]);

	[instances minusHashTable:knownInstancesTable];

	if(instances.count != 0) {
		NSLog(@"Found %lu unknown instances of %@%@ at runtime:", instances.count, class, include_subclasses? @"": @" or subclasses");
		for(id obj in instances) {
			NSLog(@"\t%@", obj);
		}
	}

	[knownInstancesTable release];
}

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		NSMutableArray *instances1 = [NSMutableArray new];
		for(int i = 0; i < 3; i++) {
			TestClass *obj = [TestClass new];
			[instances1 addObject:obj];
			assert(is_objc_object(obj));
			[obj release];
		}

		NSMutableArray *instances2 = [NSMutableArray new];
		for(int i = 0; i < 3; i++) {
			TestSubClass *obj = [TestSubClass new];
			[instances2 addObject:obj];
			assert(is_objc_object(obj));
			[obj release];
		}

		test([TestClass class], NO, instances1);
		test([TestSubClass class], NO, instances2);
		test([TestClass class], YES, [instances1 arrayByAddingObjectsFromArray:instances2]);

		NSHashTable *strings = find_instances_of_class([NSString class], YES);
		NSLog(@"Found %lu strings:", strings.count);
		for(NSString *s in strings) {
			@try {
				NSLog(@"\t%@", s);
			} @catch(NSException *e) {
				NSLog(@"\t<Failed to print string>");
			}
		}

		[instances1 release];
		[instances2 release];
	}

	return 0;
}
