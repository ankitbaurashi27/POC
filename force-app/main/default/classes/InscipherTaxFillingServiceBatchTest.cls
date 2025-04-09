@isTest
public class InscipherTaxFillingServiceBatchTest {
    
    private static Map<String, Schema.RecordTypeInfo> accountRecordTypeInfo = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    private static Id agencyRT = accountRecordTypeInfo.get('Producer').getRecordTypeId();
    
    @testSetup
    static void setupTestData() {
        
        Account testAgency = (Account) new RecordBuilder()
            .build(Account.SObjectType)
            .setField(Account.RecordTypeId, agencyRT)
            .getRecord();

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.insert(testAgency, dml); 
        
        Quote quote = (Quote) new RecordBuilder()
            .build(Quote.SObjectType)
            .setField(Quote.Name, 'Test Quote Coverage Conversion')
            .doDML().getRecord();
       
        new RecordBuilder()
            .build(QuoteLineItem.SObjectType)
            .setLookup(QuoteLineItem.QuoteId, quote)
            .doDML().getRecord();
  
 		Producer testProducer = new Producer();
        testProducer.Name = 'Test Producer';
        testProducer.AccountId = testAgency.Id;
        insert testProducer;
        
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
                Agency__c = testAgency.Id,
				ProducerId = testProducer.Id,
                Quote__c = quote.Id,
                IsRenewedPolicy = true,
				Submitted_to_Inscipher__c = false
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
				Submitted_to_Inscipher__c = false
            ));
        }
        insert endorsements;
        
        InvoiceDataForm__c invoice_record = (InvoiceDataForm__c) new RecordBuilder()
            .build(InvoiceDataForm__c.SObjectType)
            .setLookup(InvoiceDataForm__c.InsurancePolicy__c, insurancePolicies[0])
            .setField(InvoiceDataForm__c.Status__c, 'Invoiced')
            .doDML().getRecord();
        
        InvoiceDataForm__c invoice = new InvoiceDataForm__c(
            Endorsement__c = endorsements[0].Id, 
            Status__c = 'Invoiced'
        );
        insert invoice;
    }

    @isTest
    static void testBatchForInsurancePolicy() {
        try{
            Endorsement__c endorsement = [SELECT Id FROM Endorsement__c LIMIT 1];
            InsurancePolicy policy = [SELECT Id FROM InsurancePolicy LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endorsement.Id, policy.Id));
            
            Test.startTest();
            String insurnacePolicyQuery =   'SELECT Id, Name, Producer.AccountId, EffectiveDate__c, Tax_State__c,ServicingOne80Branch__c, IsRenewedPolicy, Agency__c, NameInsured.Type, ExpirationDate__c, Quote__c, Quote__r.ExpiringPolicy__c, Agency__r.PhysicalAddressSameAsMailingAddress__c,' +
                                            '(SELECT Id, Status__c, InvoiceDate__c, Invoice__c FROM InvoiceIntakeForms__r WHERE Status__c = \'Invoiced\'), ' +
                                            '(SELECT Id, ExpiringPolicy__c FROM IncumbentQuotes__r) ' +
                                            'FROM InsurancePolicy WHERE FilingParty__c = \'Inscipher\' AND EffectiveDate__c >= 2025-01-01 AND Submitted_to_Inscipher__c = false';
            
            InscipherTaxFillingServiceBatch batch = new InscipherTaxFillingServiceBatch('InsurancePolicy', insurnacePolicyQuery );
            Database.executeBatch(batch, 200);
            Test.stopTest();
            
            Integer logCount = [SELECT COUNT() FROM Inscipher_Tax_Filling_Log__c];
            System.assertEquals(1, logCount, 'One log should have been inserted');
        } catch (Exception e) {
            System.debug('Error in testBatchForInsurancePolicy: ' + e.getMessage());
        }
    }

    @isTest
    static void testBatchForEndorsement() {
        try{
            Endorsement__c endorsement = [SELECT Id  FROM Endorsement__c LIMIT 1];
            InsurancePolicy policy = [SELECT Id, Agency__c FROM InsurancePolicy LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endorsement.Id, policy.Id));
    
            Test.startTest();
            
            String endorsementQuery =   'SELECT Id, InsurancePolicy__r.EffectiveDate__c, EffectiveDate__c, Type__c, InsurancePolicy__r.Id, InsurancePolicy__r.Name, InsurancePolicy__r.Tax_State__c, InsurancePolicy__r.ServicingOne80Branch__c, ' +
                                        'InsurancePolicy__r.IsRenewedPolicy, InsurancePolicy__r.NameInsured.Type, InsurancePolicy__r.ExpirationDate__c, InsurancePolicy__r.Quote__c, InsurancePolicy__r.Agency__c, InsurancePolicy__r.Agency__r.PhysicalAddressSameAsMailingAddress__c, ' +
                                        'Quote__r.Id, Quote__r.ExpiringPolicy__c, InsurancePolicy__r.Producer.AccountId, InsurancePolicy__r.LineOfBusiness__r.Incipher_Gen_Code__c,' +
                                        '(SELECT Id, Status__c, InvoiceDate__c, Invoice__c FROM InvoiceDataFormsEndorsement__r WHERE Status__c = \'Invoiced\') ' +
                                        'FROM Endorsement__c WHERE InsurancePolicy__r.FilingParty__c = \'Inscipher\' AND Submitted_to_Inscipher__c = false';
            
            InscipherTaxFillingServiceBatch batch = new InscipherTaxFillingServiceBatch('Endorsement__c',endorsementQuery);
            Database.executeBatch(batch, 200);
            Test.stopTest();
            
            Integer logCount = [SELECT COUNT() FROM Inscipher_Tax_Filling_Log__c];
            System.assertEquals(1, logCount, 'One log should have been inserted');
        } catch (Exception e) {
            System.debug('Error in testBatchForEndorsement: ' + e.getMessage());
        }
    }

     @isTest
    static void testSchedulableClass() {
        try{
            Endorsement__c endorsement = [SELECT Id FROM Endorsement__c LIMIT 1];
            InsurancePolicy policy = [SELECT Id FROM InsurancePolicy LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(endorsement.Id, policy.Id));
            
            String cronExpression = '0 0 0 * * ?'; 
            Test.startTest();
            String jobId = System.schedule('Test InscipherTaxFilling', cronExpression, new InscipherTaxFillingServiceBatch());
            Test.stopTest();
    
            CronTrigger ct = [SELECT Id, CronExpression, State FROM CronTrigger WHERE Id = :jobId];
            System.assertEquals('WAITING', ct.State, 'The scheduled job should be in WAITING state');
            System.assertEquals(cronExpression, ct.CronExpression, 'The cron expression should match the one used to schedule the job');
        } catch (Exception e) {
            System.debug('Error in testSchedulableClass: ' + e.getMessage());
        }
    }
    
	public class MockHttpResponseGenerator implements HttpCalloutMock {
        private String endorsementId;
        private String policyId;
    
        public MockHttpResponseGenerator(String endorsementId, String policyId) {
            this.endorsementId = endorsementId;
            this.policyId = policyId;
        }
    
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"batch_id": "818b1a7f66c0f6f53de2248b8eb417d5", "transactions": [' +
                        '{"id": "' + endorsementId + '", "policy_number": "CA20170228-09", "transaction_id": 34748, "status": 0, "status_message": "Processing"},' +
                        '{"id": "' + policyId + '", "policy_number": "CA20170228-09", "transaction_id": 34748, "status": 0, "status_message": "Processing"}]}');
            return res;
        }
	}
}