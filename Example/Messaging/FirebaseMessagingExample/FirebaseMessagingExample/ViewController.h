#import <UIKit/UIKit.h>

#import "TestAppTabBarController.h"

@interface ViewController : UIViewController <TestAppDisplayNotification>

- (IBAction)didTapRegisterButton:(id)sender;

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

@end

