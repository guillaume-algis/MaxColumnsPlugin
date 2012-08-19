//
//  MaxColumnsPlugin.m
//  MaxColumnsPlugin
//
//  Created by Guillaume Algis on 16/08/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <objc/runtime.h>

#import "MCMaxColumnsPlugin.h"
#import "MCExtendedMailDocumentEditor.h"

#define DEFAULT_MAX_COLUMNS 80

@implementation MCMaxColumnsPlugin

#pragma mark - Properties

@synthesize maxColumns = _maxColumns;

#pragma mark - MVMailBundle methods overriding

+ (void) initialize 
{
	[super initialize];
    
    NSDate *initStart = [NSDate date];
    
	//We attempt to get a reference to the MVMailBundle class so we can swap superclasses, failing that 
	//we disable ourselves and are done since this is an undefined state
	Class mvMailBundleClass = NSClassFromString(@"MVMailBundle");
	if(!mvMailBundleClass)
    {
		NSLog(@"[ERR]  Mail.app does not have a MVMailBundle class available");
        exit(1);
    }
    
    class_setSuperclass([self class], mvMailBundleClass);
        
    [MCMaxColumnsPlugin registerBundle];
        
    // Fetch the sharedInstance to call the init method
    [MCMaxColumnsPlugin sharedInstance];

    NSLog(@"[INFO] Finished loading MaxColumnsPlugin %@ (took %fs)",
            [[MCMaxColumnsPlugin getOwnBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
            [initStart timeIntervalSinceNow] * -1);
}

+ (void)registerBundle 
{
    if(class_getClassMethod(NSClassFromString(@"MVMailBundle"), @selector(registerBundle)))
        [NSClassFromString(@"MVMailBundle") performSelector:@selector(registerBundle)];
}

#pragma mark - MaxColumns bundle implementation

+ (NSBundle *)getOwnBundle {
	return [NSBundle bundleForClass:[MCMaxColumnsPlugin class]];
}

- (id) init {
    NSLog(@"MCMAxCOlumnsPlungin instance init");
    if (self = [super init])
    {
        // Initialize maxColumns from Info.plist
        self.maxColumns = [(NSNumber *)[[[self class] getOwnBundle]
                                        objectForInfoDictionaryKey:@"MCMaxColumnsWrap"] intValue];
        self.maxColumns = self.maxColumns > 1 ? self.maxColumns : DEFAULT_MAX_COLUMNS;
        
        if ([self extendMailDocumentEditor]) {
            NSLog(@"[INFO] MaxColumnsPlugin successfully extended MailDocumentEditor");
        }
        else {
            NSLog(@"[ERR]  MaxColumnsPlugin could not extend MailDocumentEditor");
            exit(1);
        }
    }
    return self;
}

- (BOOL)extendMailDocumentEditor {
    BOOL success = YES;
    
    // Injecting removeTrailingWhitespaces method
    success &= [self injectMailDocumentEditorMethodFromClass:[MCExtendedMailDocumentEditor class]
                                                withSelector:@selector(removeTrailingWhitespaces)];
    
    // Injecting wrapMessageToMaxColumns method
    success &= [self injectMailDocumentEditorMethodFromClass:[MCExtendedMailDocumentEditor class]
                                                withSelector:@selector(wrapMessageToMaxColumns)];
    
    // Injecting sendWithCleanup: method
    success &= [self injectMailDocumentEditorMethodFromClass:[MCExtendedMailDocumentEditor class]
                                                withSelector:@selector(sendWithCleanup:)];
    
    success &= [self swizzleMailDocumentEditorMethods:@selector(send:)
                                                  and:@selector(sendWithCleanup:)];
    
    return success;
}

- (BOOL) injectMailDocumentEditorMethodFromClass:(Class)aClass withSelector:(SEL)aSelector {
    Class mailDocumentEditorClass = NSClassFromString(@"MailDocumentEditor");
    Method injectedMethod = class_getInstanceMethod(aClass, aSelector);
    IMP injectedMethodImpl = class_getMethodImplementation(aClass, aSelector);
    BOOL methodInjected = NO;
    
    // Fail if the MailDocumentEditor class is not found
    if(!mailDocumentEditorClass)
    {
		NSLog(@"[ERR]  Could not find the MailDocumentEditor class");
        return NO;
    }
    
    // Proper method injection
    methodInjected = class_addMethod(mailDocumentEditorClass,
                                     aSelector,
                                     injectedMethodImpl,
                                     method_getTypeEncoding(injectedMethod));
    
    if(!methodInjected) {
		NSLog(@"[ERR]  Could not add the sendWithWrap method to the MailDocumentEditor class");
    }
    
    return methodInjected;
}

- (BOOL) swizzleMailDocumentEditorMethods:(SEL)orig and:(SEL)new {
    Class mailDocumentEditorClass = NSClassFromString(@"MailDocumentEditor");
    Method origMethod = class_getInstanceMethod(mailDocumentEditorClass, orig);
    Method newMethod = class_getInstanceMethod(mailDocumentEditorClass, new);
    
    if (!origMethod || !newMethod) {
      	NSLog(@"[ERR]  Could not find method of MailDocumentEditor with selector %@", orig ? new : orig);
        return NO;
    }
    
    method_exchangeImplementations(origMethod, newMethod);
    
    return YES;
}

//+ (BOOL)overrideSendMethod
//{
//    IMP sendWithWrapImp = nil;
//    Method sendWithWrapMethod = nil;
//    
//    Method originalSendMethod = nil;
//    Method newSendMethod = nil;
//    Class mailDocumentEditorClass = NSClassFromString(@"MailDocumentEditor");
//    
//    // Check if we found the class
//    if(!mailDocumentEditorClass)
//    {
//		NSLog(@"[ERR]  Could not find the MailDocumentEditor class");
//        return NO;
//    }
//    
//    // First we add a new sendWithWrap method to the Mail.app MailDocumentEditor class
//    sendWithWrapMethod = class_getInstanceMethod([self class], @selector(sendWithWrap:));
//    sendWithWrapImp = class_getMethodImplementation([self class], @selector(sendWithWrap:));
//    BOOL methodAdded = class_addMethod(mailDocumentEditorClass,
//                                       @selector(sendWithWrap:),
//                                       sendWithWrapImp,
//                                       method_getTypeEncoding(sendWithWrapMethod));
//
//    if(!methodAdded)
//    {
//		NSLog(@"[ERR]  Could not add the sendWithWrap method to the MailDocumentEditor class");
//        return NO;
//    }
//    
//    // We take the two methods (the original send: and the freshly added sendWithWrap:)
//    originalSendMethod = class_getInstanceMethod(mailDocumentEditorClass, @selector(send:));
//    if (originalSendMethod == nil)
//    {
//      	NSLog(@"[ERR]  Could not find the send: method of MailDocumentEditor");
//        return NO;
//    }
//    
//    newSendMethod = class_getInstanceMethod(mailDocumentEditorClass, @selector(sendWithWrap:));
//    if (newSendMethod == nil)
//    {
//      	NSLog(@"[ERR]  Could not find the sendWithWrap: method of MailDocumentEditor");
//        return NO;
//    }
//    
//    // And swap their implementation
//    method_exchangeImplementations(originalSendMethod, newSendMethod);
//    
//    return YES;
//}

//- (void)sendWithWrap:(id)sender
//{
//    // We go through the objects members to find our message
//    id document = objc_msgSend(self, @selector(document));
//    DOMHTMLDocument *domHtmlDocument = objc_msgSend(document, @selector(htmlDocument));
//    
//    MCDOMWalker *domWalker = [[MCDOMWalker alloc] initWithDOMHTMLDocument:domHtmlDocument];
//    [domWalker wrapDomContentAtMaxColumns:maxColumns withLineTrimming:YES];
//    
//    domWalker = nil;
//    
//    
//    NSString *innerHTML = (NSString *)objc_msgSend(domHtmlBodyElement, @selector(innerHTML));
//    
//    NSLog(@"%@", innerHTML);
//    
//    // Detecting if the message is plain text
//    // Note: This rely on the class="ApplePlainTextBody" attribute of the <body> element
//    // it may not be the safest way to do this
//    NSString *bodyClassName = objc_msgSend(domHtmlBodyElement, @selector(className));
//    NSRange range = [bodyClassName rangeOfString:@"ApplePlainTextBody" options:NSCaseInsensitiveSearch];
//    if(range.location == NSNotFound) {
//        // Not plain text, we just send the message
//        [self sendWithWrap:sender];
//        return;
//    }
//
//    // We wrap all lines to maxColumns
//    NSArray *chunks = [innerHTML componentsSeparatedByString: @"\n"];
//    NSMutableArray *mutableChunks = [NSMutableArray arrayWithCapacity:[chunks count]];
//    [mutableChunks setArray:chunks];
//    
//    for (int i = 0; i < [mutableChunks count]; ++i) {
//        NSString *line = [mutableChunks objectAtIndex:i];
//        line = [[line stringByTrimmingTrailingWhitespaceAndNewlineCharacters]
//                stringByWrappingToMaxColumns:maxColumns];
//        [mutableChunks replaceObjectAtIndex:i withObject:line];
//    }
//    
//    innerHTML = [mutableChunks componentsJoinedByString:@"\n"];
//    
//    // And replace the message body with our wrapped one
//    objc_msgSend(domHtmlBodyElement, @selector(setInnerHTML:), innerHTML);
//    
//    // Finally, we call the default send: method (which is now sendWithWrap:)
//    [self sendWithWrap:sender];
//}



// Used for debug

//#define logVar(x) (NSLog( @"DUMP :: Value of %s = %@",#x, x))
//
//+ (void) dumpObj:(id)obj
//{
//    NSLog(@"==================================");
//    logVar(obj);
//    
//    id inst = obj;
//    int unsigned numMethods;
//    Method *methods = class_copyMethodList(object_getClass(inst), &numMethods);
//    NSLog(@"%u Methods", numMethods);
//    for (int i = 0; i < numMethods; i++) {
//        NSLog(@"%d : %@", i, NSStringFromSelector(method_getName(methods[i])));
//    }
//    
//    NSLog(@"            ###              ");
//    
//    int unsigned numProp;
//    objc_property_t *props = class_copyPropertyList(object_getClass(inst), &numProp);
//    NSLog(@"%u Properties", numProp);
//    for (int i = 0; i < numProp; i++) {
//        NSLog(@"%d : %s = %s", i, property_getName(props[i]), property_getAttributes(props[i]));
//    }
//    NSLog(@"++++++++++++++++++++++++++++++++++");
//}

@end
