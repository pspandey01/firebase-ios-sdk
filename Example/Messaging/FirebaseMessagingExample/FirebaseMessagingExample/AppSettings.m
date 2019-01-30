#import "AppSettings.h"

#import "ViewController.h"

static NSString *const kSenderIDPlistKey = @"SenderID";
static NSString *const kAPIKeyPlistKey = @"APIKey";

@interface AppSettings ()

@end

@implementation AppSettings

- (instancetype)init {
  self = [super init];
  if (self) {
  }
  return self;
}

- (void)logMessageOnScreen:(NSString *)message {
  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    TestAppTabBarController *rootController = [weakSelf rootViewController];
    [rootController showMessage:message];
  });
}


- (TestAppTabBarController *)rootViewController {
  UIViewController *viewController =
      [[[[UIApplication sharedApplication] delegate] window] rootViewController];
  if ([viewController isKindOfClass:[TestAppTabBarController class]]) {
    return (TestAppTabBarController *)viewController;
  } else {
    return nil;
  }
}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message {
  TestAppTabBarController *rootController = [self rootViewController];
  [rootController showAlertWithTitle:title message:message];
}

@end
