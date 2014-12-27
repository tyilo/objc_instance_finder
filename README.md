objc_instance_finder
====================

Find instances of objc classes at runtime

Provides one function with the following declaration:
```
NSHashTable *find_instances_of_class(Class class, BOOL include_subclasses);
```

First parameter should be an Objective-C class for which you would like to find all instances of.

The second parameter specifies wether you want to include recursively subclasses of the class.

Returns an NSHashTable instance with weak references to all the found instances.

Example usage
-------------

```
@implemenation TestClass : NSObject @end
@interface TestClass @end
```

```
TestClass *obj1 = [TestClass new];
NSHashTable *instances = find_instances_of_class([TestClass class], NO);
TestClass *obj2 = [TestClass new];

NSLog(@"%d, %d", [instances containsObject:obj1], [instances containsObject:obj2]); // 1, 0
```

Making
------

Requires a [modified version of theos](https://github.com/Tyilo/theos) to build a static library.
The environment variable `THEOS` must be set to the path of theos.
