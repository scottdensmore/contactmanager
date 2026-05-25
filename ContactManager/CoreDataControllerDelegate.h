//
//  CoreDataControllerDelegate.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreDataController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CoreDataControllerDelegate <NSObject>

- (void)coreDataController:(CoreDataController *)controller encounteredIncorrectModelWithVersionIdentifiers:(nullable NSSet *)identifiers;

@end

NS_ASSUME_NONNULL_END

