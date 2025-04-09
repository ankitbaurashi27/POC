@isTest
public class InscipherTaxFillingImportBatchTest {
    private static Map<String, Schema.RecordTypeInfo> accountRecordTypeInfo = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    private static Id agencyRT = accountRecordTypeInfo.get('Producer').getRecordTypeId();
    
    @testSetup
    static void setupTestData() {
        Quote quote = (Quote) new RecordBuilder()
            .build(Quote.SObjectType)
            .setField(Quote.Name, 'Test Quote Coverage Conversion')
            .doDML().getRecord();
       
        new RecordBuilder()
            .build(QuoteLineItem.SObjectType)
            .setLookup(QuoteLineItem.QuoteId, quote)
            .doDML().getRecord();
 
        Account insuredAccount = (Account) new RecordBuilder()
            .build(Account.SObjectType)
            .doDML()
            .getRecord();

		List<InsurancePolicy> insurancePolicies = new List<InsurancePolicy>();

        for (Integer i = 0; i < 5; i++) {
            insurancePolicies.add(new InsurancePolicy(
                Name = 'Policy ' + i,
                FilingParty__c = 'Inscipher',
                EffectiveDate__c = Date.today().addDays(10),
                Tax_State__c = 'OR - Oregon',
                NameInsuredId = insuredAccount.id,
                BillType__c = 'Agency Bill',
                Quote__c = quote.Id,
                IsRenewedPolicy = true,
				Filing_Status__c = 'processing',
				Submitted_to_Inscipher__c = true,
				Inscipher_Batch_Id__c = '4bbda7940995943cb12c071d67ad3470'
            ));
        }
        insert insurancePolicies;
        
        quote.ExpiringPolicy__c =  insurancePolicies[0].Id;
        update quote;
        
        List<Endorsement__c> endorsements = new List<Endorsement__c>();
        for (Integer i = 0; i < 3; i++) {
            endorsements.add(new Endorsement__c(
                InsurancePolicy__c = insurancePolicies[0].Id,
                EndorsementNameDetails__c = 'Forms & Endorsements',
				Filing_Status__c = 'processing',
				Submitted_to_Inscipher__c = true,
				Inscipher_Batch_Id__c = '4bbda7940995943cb12c071d67ad3470'
            ));
        }
        insert endorsements;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        InscipherTaxFillingImportBatch batchJob = new InscipherTaxFillingImportBatch('4bbda7940995943cb12c071d67ad3470');
        Database.executeBatch(batchJob, 10);
        Test.stopTest();
    }

    @isTest
    static void testSchedulableExecution() {
        Test.startTest();
        InscipherTaxFillingImportBatch batchJob = new InscipherTaxFillingImportBatch('4bbda7940995943cb12c071d67ad3470');
        String jobId = System.schedule('Test Schedule Job', '0 0 12 * * ?', batchJob);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduled job should have a valid job ID');
    }

    @isTest
    static void testGetImportStatusAPI() {
        Endorsement__c endorsement = [SELECT Id FROM Endorsement__c LIMIT 1];
        InsurancePolicy policy = [SELECT Id FROM InsurancePolicy LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endorsement.Id, policy.Id));
        String cronExpression = '0 0 0 * * ?'; 
        Test.startTest();
        String jobId = System.schedule('Test InscipherTaxFilling', cronExpression, new InscipherTaxFillingImportBatch('4bbda7940995943cb12c071d67ad3470'));
        Test.stopTest();

    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private String endorsementId;
        private String policyId;
    
        public MockHttpResponseGenerator(String endorsementId, String policyId) {
            this.endorsementId = endorsementId;
            this.policyId = policyId;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
			response.setBody('{"batch_id":"4bbda7940995943cb12c071d67ad3470","status":"processed","transactions":[{"id": "' + endorsementId + '","policy_number":"DEMO-442023-134PM","status":1002,"status_message":"Error: transaction type not found."}]}');
            response.setStatusCode(200);
            return response;
        }
    }
}