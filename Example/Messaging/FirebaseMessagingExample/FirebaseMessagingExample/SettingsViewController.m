#import "SettingsViewController.h"

#import "AppDelegate.h"
#import "FIRMessaging.h"

@implementation SettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.logTextView.text = [[FIRMessaging messaging] FCMToken];
}

- (IBAction)actionButtonPressed:(id)sender {
  UIActivityViewController *activityVC =
      [[UIActivityViewController alloc] initWithActivityItems:@[ self.logTextView.text ]
                                        applicationActivities:nil];
  [self presentViewController:activityVC animated:YES completion:nil];
}

@end
