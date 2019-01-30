#import <UIKit/UIKit.h>

@protocol TestAppDisplayNotification <NSObject>

/**
 *  Displays text on screen in a text area.
 *
 *  @param text The text to display.
 */
- (void)showText:(NSString *)text;

@end

@interface TestAppTabBarController : UITabBarController

/**
 *  Show alert with title and message. This alert view has no default action associated with it.
 *
 *  @param title   The title of the alert view.
 *  @param message The message to display in the alert view.
 */
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

/**
 *  Displays a message on the selected screen.
 *
 *  @param message The message to be displayed.
 */
- (void)showMessage:(NSString *)message;

@end
