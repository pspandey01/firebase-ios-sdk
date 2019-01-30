#import <Foundation/Foundation.h>

typedef void(^TestAppSendHandler)(NSString *result);

@interface TestAppSender : NSObject

@property(atomic, readwrite, assign) BOOL isFetching;

/**
 *  Send message with handler.
 *
 *  @param message The message to send.
 *  @param handler The handler to invoke once the server responds with the status.
 *
 *  @return YES if the message was sent successfully else NO.
 */
- (BOOL)sendMessage:(NSDictionary *)message withHandler:(TestAppSendHandler)handler;

- (NSString *)currentDate;

@end
