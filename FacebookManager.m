//
//  FacebookManager.m
//
//  Copyright (c) 2013-2014 AppsGuild. All rights reserved.
//

#import "FacebookManager.h"
#import <AdSupport/AdSupport.h>
#import <UIKit/UIKit.h>

#define PUBLISH_INSTALL_DATE_KEY @"publish_install_date"

@interface FacebookManager ()

@property (nonatomic, copy) NSString *advertiserID;
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) NSString *attributionID;
@property (nonatomic, retain) NSURLConnection *pingConnection;
@property (nonatomic, retain) NSMutableData *pingData;
@property (nonatomic, retain) NSURLConnection *publishConnection;
@property (nonatomic, retain) NSMutableData *publishData;

@end

@implementation FacebookManager

+ (FacebookManager *)sharedInstance
{
  static FacebookManager *_sharedInstance = nil;
  if (!_sharedInstance) {
    @synchronized(self) {
      if (!_sharedInstance) {
        _sharedInstance = [[self alloc] init];
      }
    }
  }
  return _sharedInstance;
}

- (void)dealloc
{
  [_pingConnection cancel];
  [_publishConnection cancel];
}

- (void)setPingConnection:(NSURLConnection *)pingConnection
{
  if (_pingConnection != pingConnection) {
    [_pingConnection cancel];
    _pingConnection = pingConnection;
  }
}

- (void)setPublishConnection:(NSURLConnection *)publishConnection
{
  if (_publishConnection != publishConnection) {
    [_publishConnection cancel];
    _publishConnection = publishConnection;
  }
}

- (void)publishInstall
{
  // make sure we have an app ID and that we don't have a PUBLISH_INSTALL_DATE_KEY
  self.appID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"];
  if ([_appID isKindOfClass:[NSString class]] && ([[NSUserDefaults standardUserDefaults] objectForKey:PUBLISH_INSTALL_DATE_KEY] == nil)) {
    // get the attribution ID that Facebook puts in the pasteboard
    self.attributionID = [[UIPasteboard pasteboardWithName:@"fb_app_attribution" create:NO] string];

    // get the advertiser ID that Apple provides (iOS 6.0+ only)
    if ([ASIdentifierManager class]) {
      self.advertiserID = [[ASIdentifierManager sharedManager] advertisingIdentifier].UUIDString;
    }

    if ((_attributionID.length != 0) || (_advertiserID.length != 0)) {
      [self _startPing];
    }
  }
}

- (void)_startPing
{
  NSString *URLString = [NSString stringWithFormat:@"https://graph.facebook.com/%@?fields=supports_attribution", _appID];
  NSURL *URL = [NSURL URLWithString:URLString];
  NSURLRequest *pingRequest = [NSURLRequest requestWithURL:URL];
  self.pingConnection = [NSURLConnection connectionWithRequest:pingRequest delegate:self];
}

- (void)_startPublish
{
  NSString *URLString = [NSString stringWithFormat:@"https://graph.facebook.com/%@/activities", _appID];
  NSURL *URL = [NSURL URLWithString:URLString];
  NSMutableURLRequest *publishRequest = [NSMutableURLRequest requestWithURL:URL];
  [publishRequest setHTTPMethod:@"POST"];
  
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSMutableArray *urlSchemes = [NSMutableArray arrayWithCapacity:1];
  for (NSDictionary *fields in [mainBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"]) {
    NSArray *schemesForType = [fields objectForKey:@"CFBundleURLSchemes"];
    if (schemesForType) {
      [urlSchemes addObjectsFromArray:schemesForType];
    }
  }
  
  NSDictionary *params = @{
                           @"event"          : @"MOBILE_APP_INSTALL",
                           @"attribution"    : (_attributionID ?: @""),
                           @"advertiser_id"  : (_advertiserID  ?: @""),
                           @"application_tracking_enabled" : @"0",
                           @"advertiser_tracking_enabled"  : @"0",
                           @"bundle_id"      : (mainBundle.bundleIdentifier ?: @""),
                           @"bundle_version" : ([mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @""),
                           @"bundle_short_version" : ([mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @""),
                           @"url_schemes"    : urlSchemes
                           };
  NSMutableString *body = NSMutableString.string;
  
  [params enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
    NSString *value = object;
    if ([object isKindOfClass:[NSArray class]]) {
      value = ((NSArray *)object).count > 0 ?
      [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object options:0 error:nil] encoding:NSUTF8StringEncoding] : nil;
    }
    if (value.length != 0) {
      [body appendFormat:(body.length ? @"&%@=%@" : @"%@=%@"), key, value];
    }
  }];

  [publishRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
  self.publishConnection = [NSURLConnection connectionWithRequest:publishRequest delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  if (connection == _pingConnection) {
    self.pingData = [NSMutableData data];
  } else if (connection == _publishConnection) {
    self.publishData = [NSMutableData data];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  if (connection == _pingConnection) {
    [_pingData appendData:data];
  } else if (connection == _publishConnection) {
    [_publishData appendData:data];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  if (connection == _pingConnection) {
    // log the error - will try again next time
    NSLog(@"Error pinging Facebook: %@", error);
    self.pingData = nil;
  } else if (connection == _publishConnection) {
    // log the error - will try again next time
    NSLog(@"Error publishing install to Facebook: %@", error);
    self.publishData = nil;
  }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  if (connection == _pingConnection) {
    NSString *text = [[NSString alloc] initWithData:_pingData encoding:NSUTF8StringEncoding];
    text = [text stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([text rangeOfString:@"\"supports_attribution\":true"].location != NSNotFound) {
      [self _startPublish];
    }
    self.pingData = nil;
    self.pingConnection = nil;
  } else if (connection == _publishConnection) {
    NSString *text = [[NSString alloc] initWithData:_publishData encoding:NSUTF8StringEncoding];
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([text isEqualToString:@"true"]) {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      [defaults setObject:[NSDate date] forKey:PUBLISH_INSTALL_DATE_KEY];
      [defaults synchronize];
    }
    self.publishData = nil;
    self.publishConnection = nil;
  }
}

@end
