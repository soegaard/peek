#import <Foundation/Foundation.h>

@interface Greeter : NSObject
@property(nonatomic, copy) NSString *name;
- (void)sayHello;
@end

@implementation Greeter
- (void)sayHello {
  NSLog(@"hello, %@", self.name);
}
@end
