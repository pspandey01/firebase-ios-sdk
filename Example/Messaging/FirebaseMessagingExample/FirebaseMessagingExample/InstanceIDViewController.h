#import <UIKit/UIKit.h>

#import "TestAppTabBarController.h"

@interface InstanceIDViewController : UIViewController <TestAppDisplayNotification>

@property(weak, nonatomic) IBOutlet UITextView *textView;
@end
