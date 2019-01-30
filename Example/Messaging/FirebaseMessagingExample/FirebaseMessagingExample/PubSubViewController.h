#import <UIKit/UIKit.h>

#import "TestAppTabBarController.h"

@interface PubSubViewController : UIViewController <TestAppDisplayNotification>

@property(weak, nonatomic) IBOutlet UITextField *topicField;
@property(weak, nonatomic) IBOutlet UITextView *textView;

@end
