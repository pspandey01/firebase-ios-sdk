#import <UIKit/UIKit.h>

#import "AppSettings.h"

static NSString *const NOTIFICATION_RECEIVE_PROBE_MESSAGE = @"notification_recieve_probe_message";

extern AppSettings *appInfo;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;

/**
 *  Current date in a human readable format of yyyy-mm-dd hh:mm:ss.
 *
 *  @param timestamp The timestamp since 1970 for which the date is required.
 *
 *  @return A human readable date.
 */
- (NSString *)humanReadableDateForTimestamp:(int64_t)timestamp;
- (NSString *)APNSTokenAsString:(NSData *)APNSToken;

@end
