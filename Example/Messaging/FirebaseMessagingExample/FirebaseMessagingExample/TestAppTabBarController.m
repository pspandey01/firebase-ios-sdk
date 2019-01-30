#import "TestAppTabBarController.h"

#import "AppDelegate.h"

@implementation TestAppTabBarController

- (void)showMessage:(NSString *)message {
  [self didReceiveMessage:message];
}

- (void)didReceiveMessage:(NSString *)dictString {
  UIViewController *controller = self.viewControllers[self.selectedIndex];
  if ([controller conformsToProtocol:@protocol(TestAppDisplayNotification)]) {
    [(id<TestAppDisplayNotification>)controller showText:dictString];
  } else {
    NSLog(@"Invalid view controller %@ to display text.", NSStringFromClass(controller.class));
  }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
  if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
  } else {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * __nonnull action) { }];

    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
  }

  NSString *log = [NSString stringWithFormat:@"%@: %@", title, message];
  [self didReceiveMessage:log];
}

@end
