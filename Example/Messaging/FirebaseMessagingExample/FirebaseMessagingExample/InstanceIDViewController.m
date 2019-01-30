#import "InstanceIDViewController.h"

#import "AppDelegate.h"

#import "googlemac/iPhone/InstanceID/Firebase/Lib/Source/FIRInstanceID.h"
#import "third_party/firebase/ios/Source/FirebaseMessaging/Library/FIRMessagingClient.h"
#import "third_party/firebase/ios/Source/FirebaseMessaging/Library/Public/FIRMessaging.h"
#import "third_party/firebase/ios/Source/FirebaseMessaging/Library/FIRMessagingConnection.h"
#import "third_party/firebase/ios/Source/FirebaseMessaging/Library/FIRMessaging_Private.h"

@interface InstanceIDViewController ()

// Outlets
@property (weak, nonatomic) IBOutlet UIButton *getIdentityButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteIdentityButton;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *MCSConnectButton;
@property (weak, nonatomic) IBOutlet UIButton *MCSDisconnectButton;
@property(weak, nonatomic) IBOutlet UISwitch *shouldConnectSwitch;
@property(weak, nonatomic) IBOutlet UILabel *connectionStatusLabel;

@property(nonatomic, readwrite, strong) NSString *appID;
@property(nonatomic, readwrite, strong) NSMutableString *logTextString;
@property(nonatomic, readwrite, assign) BOOL connectingToMCS;
@property(nonatomic, readwrite, assign) BOOL didUserConnectToMCS;
@property(nonatomic, readwrite, strong) NSTimer *updateMCSTimestampTimer;

@end

@implementation InstanceIDViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self
             selector:@selector(didResignActiveState:)
                 name:UIApplicationWillResignActiveNotification
               object:nil];

  [center addObserver:self
             selector:@selector(didEnterForeground:)
                 name:UIApplicationWillEnterForegroundNotification
               object:nil];

  [center addObserver:self
             selector:@selector(onMCSConnectionChanged)
                 name:FIRMessagingConnectionStateChangedNotification
               object:nil];

}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.didUserConnectToMCS = [FIRMessaging messaging].isDirectChannelEstablished;
  [self updateMCSStatusLabel];
  self.shouldConnectSwitch.on = [FIRMessaging messaging].shouldEstablishDirectChannel;
}

- (void)updateMCSStatusLabel {
  if ([FIRMessaging messaging].isDirectChannelEstablished) {
    self.connectionStatusLabel.text = @"MCS Channel is established\n";
  } else {
    self.connectionStatusLabel.text = @"MCS Channel is down\n";
  }
}

- (IBAction)shouldConnectSwitched:(id)sender {
  if (self.shouldConnectSwitch.on) {
    [FIRMessaging messaging].shouldEstablishDirectChannel = YES;
  } else {
    [FIRMessaging messaging].shouldEstablishDirectChannel = NO;
  }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
  [super willRotateToInterfaceOrientation:toInterfaceOrientation
                                 duration:duration];
  [self.view setNeedsUpdateConstraints];
}

- (IBAction)didTapGetIdentityButton:(id)sender {
  FIRInstanceID *iid = [FIRInstanceID instanceID];
  [iid getIDWithHandler:^(NSString *identity, NSError *error) {
    NSString *logText;
    if (error) {
      logText = [NSString stringWithFormat:@"Failed to get Identity %@", error];
    } else {
      self.appID = identity;
      logText = [NSString stringWithFormat:@"Successfully got Identity %@", identity];
    }
    [self addTextToLogView:logText];
  }];
}

- (IBAction)didTapDeleteIdentityButton:(id)sender {
  FIRInstanceID *iid = [FIRInstanceID instanceID];
  [iid deleteIDWithHandler:^(NSError *error) {
    NSString *logText;
    if (error) {
      logText = [NSString stringWithFormat:@"Failed to delete app identity %@", error];
    } else {
      logText = [NSString stringWithFormat:@"Successfully deleted app identity"];
    }
    [self addTextToLogView:logText];
  }];
}

- (IBAction)didTapConnectToMCS:(id)sender {
  [self addTextToLogView:@"Trying to connect to MCS ..."];
  FIRMessaging *service = [FIRMessaging messaging];
  self.didUserConnectToMCS = YES;
  if (!self.connectingToMCS) {
    self.connectingToMCS = YES;
    __weak __typeof(self) weakSelf = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [service connectWithCompletion:^(NSError *error) {
#pragma clang diagnostic pop
      weakSelf.connectingToMCS = NO;
      if (error) {
        [weakSelf addTextToLogView:[NSString stringWithFormat:@"MCS Connect failed: %@", error]];
        return;
      }

      [weakSelf addTextToLogView:[NSString stringWithFormat:@"MCS Connect success"]];
      NSLog(@"MCS connection successful");
      [self updateMCSStatusLabel];
    }];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveProbeMessage:)
                                               name:NOTIFICATION_RECEIVE_PROBE_MESSAGE
                                             object:nil];

}

- (IBAction)didTapDisconnectFromMCS:(id)sender {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[FIRMessaging messaging] disconnect];
#pragma clang diagnostic pop
  [self addTextToLogView:@"Disconnect from MCS"];
  self.didUserConnectToMCS = NO;
  [self updateMCSStatusLabel];
}

- (IBAction)didTapClearButton:(id)sender {
  NSRange range = NSMakeRange(0, [self.logTextString length]);
  [self.logTextString deleteCharactersInRange:range];
  self.textView.text = self.logTextString;
}

#pragma mark - Notification Callbacks

- (void)onMCSConnectionChanged {
  BOOL isConnected = [FIRMessaging messaging].isDirectChannelEstablished;
  if (isConnected) {
    [self addTextToLogView:@"MCS Connection Established"];
  } else {
    [self addTextToLogView:@"MCS Connection Torn Down"];
  }
  [self updateMCSStatusLabel];
}

- (void)didReceiveProbeMessage:(NSNotification *)notification {
}

- (void)didResignActiveState:(NSNotification *)notification {
  // Perform any other cleanup that should be performed before entering background.
  if ([self.updateMCSTimestampTimer isValid]) {
    [self.updateMCSTimestampTimer invalidate];
    self.updateMCSTimestampTimer = nil;
  }
}

- (void)didEnterForeground:(NSNotification *)notification {
}



- (void)addTextToLogView:(NSString *)text {
  if ([text length]) {
    if (!self.logTextString) {
      self.logTextString = [NSMutableString string];
    }
    [self.logTextString appendString:text];
    [self.logTextString appendString:@"\n"];
    self.textView.text = self.logTextString;

    // additionally log the info to the console.
    NSLog(@"%@", text);

    [self scrollToBottomText:text inTextView:self.textView];
  }
}

- (void)scrollToBottomText:(NSString *)text inTextView:(UITextView *)textView {
  NSRange bottom = NSMakeRange(textView.text.length - text.length, text.length);
  [textView scrollRangeToVisible:bottom];
}

#pragma mark - TestAppDisplayNotification

- (void)showText:(NSString *)text {
  [self addTextToLogView:text];
}

@end
