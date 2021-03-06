//
//  MigrationsTests.m
//  ObjCMiniORM
//
//  Created by Kirmanie Ravariere on 10/5/12.
//  Copyright (c) 2012 Kirmanie Ravariere. All rights reserved.
//

#import "MigrationsTests.h"
#import "MODbMigrator.h"
#import "MORepository.h"
#import "MOScriptFile.h"
#import "MODbModelMeta.h"
#import "TestModel.h"

@implementation MigrationsTests

- (void)setUp{
    //delete test database
    NSFileManager *fileManager = [NSFileManager defaultManager];
     MORepository *repository=[[MORepository alloc]init];
    [fileManager removeItemAtPath:[repository getFilePathName] error:NULL];
}

-(void)testCreateScriptTableIfNotExists{
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:nil];

     BOOL check =[[repository
        executeSQLScalar:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?;"
        withParameters:[NSArray arrayWithObject:[MODbMigrator migrationTableName]]] intValue] > 0;
    
     STAssertTrue(check,@"createScriptTableIfNotExists");
    //get rid of warning
    STAssertTrue([migrator registeredScriptFiles]!=nil,@"createScriptTableIfNotExists");
}

-(void)testWillRegisterScriptsAndOrderThem{
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:nil];
    
    id<IScriptFile>script=[[MOScriptFile alloc]initWithTimestamp:88 andSql:@"sql"];
    [migrator registerScriptFile:script];
    script=[[MOScriptFile alloc]initWithTimestamp:99 andSql:@"sql"];
    [migrator registerScriptFile:script];
    script=[[MOScriptFile alloc]initWithTimestamp:100 andSql:@"sql"];
    [migrator registerScriptFile:script];
    
    [migrator performSelector:@selector(orderScriptFiles)];
    
     STAssertTrue([[migrator registeredScriptFiles] count] > 0,
        @"willRegisterScriptsAndOrderThem  -  will register");
    STAssertTrue([[[migrator registeredScriptFiles] objectAtIndex:0] timestamp] == 100,
        @"willRegisterScriptsAndOrderThem  -  will order");
}

-(void)testGetAllScriptsThatHaventRun{
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:nil];
    
    [migrator performSelector:@selector(checkCreateScriptTable)];
    
    [repository executeSQL:[NSString stringWithFormat:@"insert into %@(timestamp, runOn) values(88, 88)",
        [MODbMigrator migrationTableName]] withParameters:nil];
    
    [repository executeSQL:[NSString stringWithFormat:@"insert into %@(timestamp, runOn) values(99, 99)",
        [MODbMigrator migrationTableName]] withParameters:nil];
    
    id<IScriptFile>script=[[MOScriptFile alloc]initWithTimestamp:88 andSql:@"sql"];
    [migrator registerScriptFile:script];
    script=[[MOScriptFile alloc]initWithTimestamp:99 andSql:@"sql"];
    [migrator registerScriptFile:script];
    script=[[MOScriptFile alloc]initWithTimestamp:100 andSql:@"sql"];
    [migrator registerScriptFile:script];
    
    NSArray* haventRun = [migrator performSelector:@selector(getScriptFilesThatHaventBeenRun)];
    STAssertTrue([haventRun count] == 1,@"getAllScriptsThatHaventBeenRun - verify count");
    STAssertTrue([[haventRun objectAtIndex:0] timestamp] == 100, 
        @"getAllScriptsThatHaventBeenRun - verify file");
}

-(void)testWillGetTableNames{
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:nil];
    NSArray* tablesSchema = [migrator performSelector:@selector(getTableDbMeta)];
    
    STAssertTrue([tablesSchema count] > 0,@"testWillGetTableNames - has tables");

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@",[MODbMigrator migrationTableName]];
    NSArray *results = [tablesSchema filteredArrayUsingPredicate:predicate];

    STAssertTrue([results count] > 0,@"testWillGetTableNames - has script table");
}

-(void)testWillGetColumnDataForTable{
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:nil];
    NSArray* columnSchema = [migrator performSelector:@selector(getColumnDbMetaForTable:)
        withObject:[MODbMigrator migrationTableName]];
    
    STAssertTrue([columnSchema count] > 0,@"testWillGetColumnDataForTable - has columns");

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == 'timestamp'"];
    NSArray *results = [columnSchema filteredArrayUsingPredicate:predicate];

    STAssertTrue([results count] > 0,@"testWillGetColumnDataForTable - has timestamp column");
}

-(void)testCreateTableForModelIfNotInDb{
    MODbModelMeta *meta=[[MODbModelMeta alloc]init];
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:meta];
    
    [meta modelAddByName:@"TestTable"];
    [meta propertyAdd:@"TestTableId"];
    [meta propertySetIsKey:true];
    [meta propertyAdd:@"TableName"];
    [meta propertySetType:@"NSString"];
    [meta modelAddByType:TestModel.class];
    
    BOOL allOkay = [migrator updateDatabaseAndRunScripts:true];
     STAssertTrue(allOkay,@"CreateTableForModelIfNotInDb - sql did run");
    
    [repository executeSQL:@"insert into TestTable(TableName) values('MyTable')" withParameters:nil];
    NSArray* records =[repository query:@"select * from TestTable" withParameters:nil];
    STAssertTrue([records count] == 1,@"testWillGetColumnDataForTable - has timestamp column");
    
}

-(void)testAddColumnsToExistingTable{
    MODbModelMeta *meta=[[MODbModelMeta alloc]init];
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:meta];
    
    [repository executeSQL:@"create table MyTable(TestTableId INTEGER PRIMARY KEY)" withParameters:nil];
    
    [meta modelAddByName:@"TestTable"];
    [meta modelSetTableName:@"MyTable"];
    [meta propertyAdd:@"Id"];
    [meta propertySetIsKey:true];
    [meta propertyAdd:@"TableName"];
    [meta propertySetType:@"NSString"];
    
    BOOL allOkay = [migrator updateDatabaseAndRunScripts:true];
     STAssertTrue(allOkay,@"AddColumnsToExistingTable - sql did run");
    
     BOOL check =[[repository
            executeSQLScalar:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name='TestTable';"
            withParameters:nil] intValue] == 0;
    STAssertTrue(check,@"AddColumnsToExistingTable");
    
    [repository executeSQL:@"insert into MyTable(TableName) values('MyTable')" withParameters:nil];
    NSArray* records =[repository query:@"select * from MyTable" withParameters:nil];
    STAssertTrue([records count] == 1,@"AddColumnsToExistingTable");
}

-(void)testSetupManualBindings{
    MODbModelMeta *meta=[[MODbModelMeta alloc]init];
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:meta];
    
    [meta modelAddByName:@"TestTable"];
    [meta modelSetTableName:@"MyTable"];
    [meta propertyAdd:@"keyProperty"];
    [meta propertySetColumnName:@"Id"];
    [meta propertySetIsKey:true];
    [meta propertyAdd:@"secondProperty"];
    [meta propertySetColumnName:@"TableName"];
    [meta propertySetType:@"NSString"];
    
    BOOL allOkay = [migrator updateDatabaseAndRunScripts:true];
     STAssertTrue(allOkay,@"AddColumnsToExistingTable - sql did run");
    
     BOOL check =[[repository
            executeSQLScalar:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name='TestTable';"
            withParameters:nil] intValue] == 0;
    STAssertTrue(check,@"AddColumnsToExistingTable");
    
    [repository executeSQL:@"insert into MyTable(TableName) values('MyTable')" withParameters:nil];
    NSArray* records =[repository query:@"select Id,TableName from MyTable" withParameters:nil];
    STAssertTrue([records count] == 1,@"AddColumnsToExistingTable");
}

-(void)testWillIgnoreProperties{
    MODbModelMeta *meta=[[MODbModelMeta alloc]init];
    MORepository *repository=[[MORepository alloc]init];
    [repository open];
    MODbMigrator *migrator = [[MODbMigrator alloc]initWithRepo:repository andMeta:meta];
    
    [meta modelAddByType:TestModel.class];
    [meta propertySetCurrentByName:@"ignoreProperty"];
    [meta propertySetIgnore:true];
    [meta propertySetCurrentByName:@"modelDate"];
    [meta propertySetIgnore:true];
    [meta propertySetCurrentByName:@"readonlyProperty"];
    [meta propertySetIsReadOnly:true];

    BOOL allOkay = [migrator updateDatabaseAndRunScripts:true];
     STAssertTrue(allOkay,@"WillIgnoreProperties - sql did run");
    
    NSArray* records =[repository query:@"pragma table_info(TestModel)" withParameters:nil];
    
    NSArray* filter = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
    ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[evaluatedObject objectForKey:@"name"] isEqualToString:@"ignoreProperty"];
    }]];
    STAssertTrue([filter count] == 0,@"WillIgnoreProperties - didn't add ignoreProperty");

    filter = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
    ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[evaluatedObject objectForKey:@"name"] isEqualToString:@"readonlyProperty"];
    }]];
    STAssertTrue([filter count] == 0,@"WillIgnoreProperties - didn't add readonlyProperty");
    
    filter = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
    ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[evaluatedObject objectForKey:@"name"] isEqualToString:@"modelDate"];
    }]];
    STAssertTrue([filter count] == 0,@"WillIgnoreProperties - didn't add modelDate");
    
    filter = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
    ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[evaluatedObject objectForKey:@"name"] isEqualToString:@"fullName"];
    }]];
    STAssertTrue([filter count] == 1,@"WillIgnoreProperties - add fullName");
}

@end
