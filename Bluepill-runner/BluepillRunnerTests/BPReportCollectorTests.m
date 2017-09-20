//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPReportCollector.h"

@interface BPReportCollectorTests : XCTestCase

@end

@implementation BPReportCollectorTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCollectReportsFromPath {
    /*
        Setup (to test it):
        There are 3 feaures: Feature1, Feature2 and Feature3
        Feature1 has 1 test which is passing (from first run)
        Feature2 has 1 test which is failing. There are 2 runs and both are failing with same error.
        Feature3 has 3 tests.
            Feature3-Test1 pass from first attempt.
            Feature3-Test2 fails from first attempt and then re-runs and fails again
            Feature3-Test3 fails from first attempt and then re-runs and pass
     */
    NSString *path = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *outputPath = [path stringByAppendingPathComponent:@"result.xml"];
    [BPReportCollector collectReportsFromPath:path onReportCollected:^(NSURL *fileUrl) {
        NSError *error;
        NSFileManager *fm = [NSFileManager new];
        [fm removeItemAtURL:fileUrl error:&error];
        XCTAssertNil(error);
    }  outputAtPath:outputPath];
    NSData *data = [NSData dataWithContentsOfFile:outputPath];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
    XCTAssertNil(error);
    //All tests results
    NSArray *testsuitesNodes =  [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuites"] error:&error];
    NSXMLElement *root = testsuitesNodes[0];
    XCTAssertTrue([[[root attributeForName:@"tests"] stringValue] isEqualToString:@"5"], @"test count is wrong");
    XCTAssertTrue([[[root attributeForName:@"errors"] stringValue] isEqualToString:@"2"], @"errors count is wrong");
    XCTAssertTrue([[[root attributeForName:@"failures"] stringValue] isEqualToString:@"2"], @"failures count is wrong");
    NSLog(@"%@, %@, %@", [[root attributeForName:@"tests"] stringValue], [[root attributeForName:@"errors"] stringValue], [[root attributeForName:@"failures"] stringValue]);
    
    //Feature1 results
    NSXMLElement *feature1 = [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuite[@name='Feature1']"] error:&error][0];
    XCTAssertTrue([[[feature1 attributeForName:@"tests"] stringValue] isEqualToString:@"1"], @"test count is wrong");
    XCTAssertTrue([[[feature1 attributeForName:@"errors"] stringValue] isEqualToString:@"0"], @"errors count is wrong");
    XCTAssertTrue([[[feature1 attributeForName:@"failures"] stringValue] isEqualToString:@"0"], @"failures count is wrong");

    //Feature2 results
    NSXMLElement *feature2 = [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuite[@name='Feature2']"] error:&error][0];
    XCTAssertTrue([[[feature2 attributeForName:@"tests"] stringValue] isEqualToString:@"1"], @"test count is wrong");
    XCTAssertTrue([[[feature2 attributeForName:@"errors"] stringValue] isEqualToString:@"1"], @"errors count is wrong");
    XCTAssertTrue([[[feature2 attributeForName:@"failures"] stringValue] isEqualToString:@"1"], @"failures count is wrong");

    //Feature3 results
    NSXMLElement *feature3 = [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuite[@name='Feature3']"] error:&error][0];
    XCTAssertTrue([[[feature3 attributeForName:@"tests"] stringValue] isEqualToString:@"3"], @"test count is wrong");
    XCTAssertTrue([[[feature3 attributeForName:@"errors"] stringValue] isEqualToString:@"1"], @"errors count is wrong");
    XCTAssertTrue([[[feature3 attributeForName:@"failures"] stringValue] isEqualToString:@"1"], @"failures count is wrong");

    NSFileManager *fm = [NSFileManager new];
    [fm removeItemAtPath:outputPath error:&error];
    XCTAssertNil(error);
}

@end
