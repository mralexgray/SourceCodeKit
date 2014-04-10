
@interface SCKCodeCompletionResult : NSObject

@property (nonatomic) NSString *fixitText;
@property (nonatomic) NSRange fixitRange;
@property (nonatomic) NSArray *completions;

@end
