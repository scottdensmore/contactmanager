//
//  CoreDataControllerDelegate.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreDataController.h"

@protocol CoreDataControllerDelegate <NSObject>

- (void)coreDataController:(CoreDataController *)controller encounteredIncorrectModelWithVersionIdentifiers:(NSSet *)identifiers;

@end
