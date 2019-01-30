#import <Foundation/Foundation.h>

@interface AppSettings : NSObject

- (void)logMessageOnScreen:(NSString *)message;
- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message;

@end
