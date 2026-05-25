#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSManagedObjectModel (Extensions)

- (nullable NSArray<__kindof NSManagedObject *> *)objectsInEntityWithContext:(NSManagedObjectContext *)context
                                                                      name:(NSString *)name
                                                                 predicate:(nullable NSPredicate *)predicate
                                                     sortedWithDescriptors:(nullable NSArray<NSSortDescriptor *> *)descriptors;

- (nullable __kindof NSManagedObject *)insertNewObjectInEntityWithContext:(NSManagedObjectContext *)context
                                                                    name:(NSString *)name
                                                                  values:(nullable NSDictionary<NSString *, id> *)values;

@end

NS_ASSUME_NONNULL_END
