//
//  BaseTestCase.m
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import "BaseTestCase.h"


@implementation BaseTestCase

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{   
    [super tearDown];
}

/*! Tells whether the control sends the action to the target. */
- (BOOL)checkControl:(NSControl *)control sendsAction:(SEL)action toTarget:(id)target
{
    return ([control action] == action) && ([control target] == target);
}

/*! Tells whether the outlet is connected to the given destination. */
- (BOOL)checkOutlet:(id)outlet connectsTo:(id)destination
{
    return outlet == destination;
}


/*! Tells whether the object's binding is connected through the given key path. */
- (BOOL)checkObject:(id)source hasBinding:(NSString *)binding toObject:(id)destination through:(NSString *)keyPath
{
    NSDictionary *bindingInfo = [source infoForBinding:binding];
    id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
    NSString *observedKeyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
    
    return (bindingInfo != nil) && (observedObject == destination) && [keyPath isEqualToString:observedKeyPath];
}

@end
