//
//  FacebookManager.h
//
//  Copyright 2013-2014 AppsGuild. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FacebookManager : NSObject

+ (FacebookManager *)sharedInstance;

- (void)publishInstall;

@end
