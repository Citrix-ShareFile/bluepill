//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPReportCollector.h"
#import "BPUtils.h"

@implementation BPReportCollector

+ (void)collectReportsFromPath:(NSString *)reportsPath
             onReportCollected:(void (^)(NSURL *fileUrl))fileHandler
                  outputAtPath:(NSString *)finalReportPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSURL *directoryURL = [NSURL fileURLWithPath:reportsPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             fprintf(stderr, "Failed to process url %s", [[url absoluteString] UTF8String]);
                                             return YES;
                                         }];

    /**from here we need to go inside this node and get its child nodes
    *
    * testsuites from a simulator report (.xml) - needs to be combined
    *   |
    *   |--device (iPhone or iPad)
    *       |
    *       |--testsuite with test class name (XXXXTests) - needs to be combined
    *       |      |--testcase
    *       |      |--testcase
    *       |      |--testcase
    *       |           ...
    *       |--testsuite
    *             ...
    */
    
    NSMutableDictionary *all_tests = [NSMutableDictionary new];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            fprintf(stderr, "Failed to get resource from url %s", [[url absoluteString] UTF8String]);
        }
        else if (![isDirectory boolValue]) {
            if ([[url pathExtension] isEqualToString:@"xml"]) {
                NSError *error;
                NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:&error];
                
                if (error) {
                    [BPUtils printInfo:ERROR withString:@"Failed to parse %@: %@", url, error.localizedDescription];
                    return;
                }
                NSString *deviceName = [self deviceNameFromPath:url];
                if ([all_tests objectForKey:deviceName] == nil) {
                    all_tests[deviceName] = [NSMutableDictionary new];
                }

                NSArray *testCaseNodes = [doc.rootElement nodesForXPath:@"//testcase" error:&error];
                for (NSXMLElement *testCaseNode in testCaseNodes) {
                    NSString *className = [[testCaseNode attributeForName:@"classname"] stringValue];
                    NSString *testName = [[testCaseNode attributeForName:@"name"] stringValue];
                    if ([all_tests[deviceName] objectForKey:className] == nil) {
                        all_tests[deviceName][className] = [NSMutableDictionary new];
                    }
                    //don't re-write passed test with failed
                    if (([all_tests[deviceName][className] objectForKey:testName] == nil) || [self testPassed:testCaseNode]) {
                        all_tests[deviceName][className][testName] = testCaseNode;
                    }
                }

                if (fileHandler) {
                    fileHandler(url);
                }
            }
        }
    }
    
    NSXMLElement *rootNode = (NSXMLElement *)[NSXMLNode elementWithName:@"testsuites"];
    for (NSString *deviceName in all_tests) {
        NSXMLElement *deviceNode = (NSXMLElement *)[NSXMLNode elementWithName:@"testsuite"];
        deviceNode = [self setNodeAttributes:deviceNode withName:deviceName];
        
        for (NSString *className in all_tests[deviceName]) {
            NSMutableDictionary *tests = [all_tests[deviceName] objectForKey:className];
            NSXMLElement *testSuiteNode = (NSXMLElement *)[NSXMLNode elementWithName:@"testsuite"];
            
            for (NSString *testName in tests) {
                [testSuiteNode addChild:[tests objectForKey:testName]];
            }
            
            testSuiteNode = [self setNodeAttributes:testSuiteNode withName:className];
            [deviceNode addChild:testSuiteNode];
        }
        deviceNode = [self setNodeAttributes:deviceNode withName:deviceName];
        [rootNode addChild:deviceNode];
    }

    rootNode = [self setNodeAttributes:rootNode withName:@"Selected tests"];
    
    NSXMLDocument *resultXMLDoc = [NSXMLDocument documentWithRootElement:rootNode];
    NSData *xmlData = [resultXMLDoc XMLDataWithOptions:NSXMLDocumentIncludeContentTypeDeclaration];
    [xmlData writeToFile:finalReportPath atomically:YES];
}

+ (NSXMLElement *)setNodeAttributes:(NSXMLElement *)node withName:(NSString *)testSuiteName {
    NSError *error;
    NSMutableDictionary *nodeAttributes = [NSMutableDictionary new];
    NSArray *tests = [node nodesForXPath:@".//testcase" error:&error];
    NSArray *errors = [node nodesForXPath:@".//error" error:&error];
    NSArray *failures = [node nodesForXPath:@".//failure" error:&error];
    
    nodeAttributes[@"name"] = testSuiteName;
    nodeAttributes[@"tests"] = [@(tests.count) stringValue];
    nodeAttributes[@"errors"] = [@(errors.count) stringValue];
    nodeAttributes[@"failures"] = [@(failures.count) stringValue];
    nodeAttributes[@"time"] = [@([self getTimeFromAllTestNodes:node]) stringValue];
    [node setAttributesAsDictionary:nodeAttributes];
    
    return node;
}

+ (float)getTimeFromAllTestNodes:(NSXMLElement *)node {
    NSError *error;
    float result = 0.0;
    NSArray *testcaseNodes = [node nodesForXPath:@".//testcase" error:&error];
    for (NSXMLElement *testCaseNode in testcaseNodes) {
        NSString *time = [[testCaseNode attributeForName:@"time"] stringValue];
        result = result + [time floatValue];
    }
    
    return result;
}

+ (Boolean)testPassed:(NSXMLElement *)testCaseNode {
    NSError *error;
    NSArray *failures = [testCaseNode nodesForXPath:@"./failure" error:&error];
    NSArray *errors = [testCaseNode nodesForXPath:@"./error" error:&error];

    Boolean hasNoFailures = !failures.count;
    Boolean hasNoErrors = !errors.count;
    
    return hasNoFailures && hasNoErrors;
}

+ (NSString *)deviceNameFromPath:(NSURL *)url {
    NSArray<NSString *> *pathComponents = url.pathComponents;
    NSLog (@"Number of elements in url = %lu", [pathComponents count]);
    unsigned long index = [pathComponents count] - 3; // need last folder name but not last element
    NSString *result = [pathComponents objectAtIndex: index];
    return result;
}


@end
