//
//  ViewController.m
//  NSObject-JSONModel
//
//  Created by unakayou on 3/1/19.
//  Copyright © 2019 unakayou. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    Teacher * teacher = [self findTeacher];
    NSDictionary * dict = [teacher dictionaryFromObject];
    NSLog(@"%@",dict);
    
    Teacher * doubleTeacher = [Teacher modelFromJSONDictionary:dict];
    NSLog(@"%@",doubleTeacher);
}

- (Teacher *)findTeacher
{
    Office * office = [Office new];
    office.name = @"302";
    
    NSMutableArray * studentsArray = [[NSMutableArray alloc] initWithCapacity:5];
    for (int i = 0; i < 5; i++)
    {
        Student * tmpStudent = [Student new];
        tmpStudent.name = [NSString stringWithFormat:@"NO.%d_student",i + 1];
        tmpStudent.age  = @(arc4random() % 20 + 1);
        [studentsArray addObject:tmpStudent];
    }
    
    Teacher * teacher = [Teacher new];
    teacher.name = @"teacher";
    teacher.age  = @40;
    teacher.office = office;
    teacher.student = (NSArray <Student*><Student>*)studentsArray;
    return teacher;
}

@end
