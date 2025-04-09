/**
* @File Name : CaseMergeHandlerTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 13, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 13, 2024 |   | Initial Version
**/

@isTest
public class CaseMergeHandlerTest {

    @isTest
    static void testGetSelectedRecordsValid() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Case case1 = new Case(Subject = 'Test Case 1', AccountId = acc.Id, Status = 'New', Group__c = 'NPD Contacts');
        Case case2 = new Case(Subject = 'Test Case 2', AccountId = acc.Id, Status = 'In Progress');
        insert new List<Case>{ case1, case2 };
        List<String> recordIds = new List<String>{ case1.Id, case2.Id };
        String recordIdsJson = JSON.serialize(recordIds);

        Test.startTest();
        Map<String, Object> response = CaseMergeHandler.getSelectedRecords(recordIdsJson);
        Test.stopTest();

        System.assert(!response.containsKey('error'), 'Unexpected error in response');
        System.assert(response.containsKey('records'), 'Records not returned in response');
        System.assertEquals(2, ((List<Object>)response.get('records')).size(), 'Expected two records');
    }

    @isTest
    static void testGetSelectedRecordsError() {
        Account acc1 = new Account(Name = 'Account 1');
        Account acc2 = new Account(Name = 'Account 2');
        insert new List<Account>{ acc1, acc2 };

        Case case1 = new Case(Subject = 'Case 1', AccountId = acc1.Id, Status = 'New');
        Case case2 = new Case(Subject = 'Case 2', AccountId = acc2.Id, Status = 'New');
        insert new List<Case>{ case1, case2 };

        List<String> recordIds = new List<String>{ case1.Id, case2.Id };
        String recordIdsJson = JSON.serialize(recordIds);
        Test.startTest();
        Map<String, Object> response = CaseMergeHandler.getSelectedRecords(recordIdsJson);
        Test.stopTest();

        System.assert(response.containsKey('error'), 'Expected error in response');
        System.assertEquals('Cases must belong to the same account to be merged.', response.get('error'));
    }

    @isTest
    static void testMergeCases() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Case case1 = new Case(Subject = 'Primary Case', AccountId = acc.Id, Status = 'New');
        Case case2 = new Case(Subject = 'Secondary Case', AccountId = acc.Id, Status = 'In Progress');
        insert new List<Case>{ case1, case2 };

        Map<String, Object> selectedFields = new Map<String, Object>();
        selectedFields.put('Subject', '1');

        String caseIdsJson = JSON.serialize(new List<String>{ case1.Id, case2.Id });

        Test.startTest();
        String result;
        try{ result = CaseMergeHandler.mergeCases(caseIdsJson, selectedFields, case1.Id, '0');}catch(Exception e){}
        Test.stopTest();

        Case updatedPrimaryCase = [SELECT Subject, Status FROM Case WHERE Id = :case1.Id];
        Case updatedSecondaryCase = [SELECT Status FROM Case WHERE Id = :case2.Id];
    }

    @isTest
    static void testMergeCasesError() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Case case1 = new Case(Subject = 'Primary Case', AccountId = acc.Id, Status = 'Closed');
        Case case2 = new Case(Subject = 'Secondary Case', AccountId = acc.Id, Status = 'In Progress');
        insert new List<Case>{ case1, case2 };
        Map<String, Object> selectedFields = new Map<String, Object>();
        selectedFields.put('Subject', '1');

        String caseIdsJson = JSON.serialize(new List<String>{ case1.Id, case2.Id });
        Test.startTest();
        try {
            CaseMergeHandler.mergeCases(caseIdsJson, selectedFields, case1.Id, '0');
            System.assert(false, 'Expected exception not thrown');
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}