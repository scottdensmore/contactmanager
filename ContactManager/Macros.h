//
//  Macros.h
//  ContactManager
//
//  Created by Scott Densmore on 6/21/11.
//  Copyright 2011 Scott Densmore. All rights reserved.
//

#import <Foundation/Foundation.h>


/*
 LOG -- calls NSLog only if DEBUG is defined
 */
#ifdef DEBUG
#define LOG(...) NSLog(__VA_ARGS__)
#else
#define LOG(...) /* */
#endif

/*
 LOGLINE -- calls NSLog only if DEBUG is defined, also adds in file, line numbers
 */
#ifdef DEBUG
#define LOGLINE(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define FTLOGCALL LOG(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd))
#else
#define LOGLINE(...) /* */
#define FTLOGCALL /* */
#endif

/*
 RELEASE -- releases a variable and sets it to nil.
 */
//#define RELEASE(_obj) if(_obj) { [_obj release]; } _obj = nil

#if DEBUG
#define RELEASE(_obj) [_obj release]
#else
#define RELEASE(_obj) [_obj release], _obj = nil
#endif


#define NSNullIfNil(_obj) _obj == nil ? (id)[NSNull null] : _obj

/*
 Radians to Degrees Conversions
 */
#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

/*
 Localized Strings
 */
#define FCLocalizedString(key) NSLocalizedStringFromTable(key, @"Localizable", @"") 
#define FCLocalizedFormattedString(key, ...) [NSString stringWithFormat:NSLocalizedStringFromTable(key, @"Localizable", @""), __VA_ARGS__]  
