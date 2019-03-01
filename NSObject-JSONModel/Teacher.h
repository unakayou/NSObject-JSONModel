//
//  Teacher.h
//  NSObject-JSONModel
//
//  Created by unakayou on 3/2/19.
//  Copyright © 2019 unakayou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol Student;

@interface Teacher : NSObject
@property (nonatomic, copy) NSString * name;    //老师的名字
@property (nonatomic, strong) NSNumber * age;   //老师的年龄
@property (nonatomic, strong) Office  * office; //老师的办公室
@property (nonatomic, strong) NSArray <Student*><Student>* student;   //老师的学生们
@end

NS_ASSUME_NONNULL_END
