//
//  ContactDataControllerTests.h
//  ContactManager
//
//  Created by Scott Densmore on 6/26/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class ContactDataController;
@class CoreDataController;

@interface ContactDataControllerTests : SenTestCase {
@private
    CoreDataController *coreDataController;
    ContactDataController *contactDataController;
}

@end
