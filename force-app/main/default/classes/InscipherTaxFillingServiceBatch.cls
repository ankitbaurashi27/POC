/**
* @File Name : InscipherTaxFillingServiceBatch.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : January 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 12, 2025 |   | Initial Version
**/

public class InscipherTaxFillingServiceBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Schedulable{

    private String objectName;
    private String query;
    
    public InscipherTaxFillingServiceBatch() {}

    public InscipherTaxFillingServiceBatch(String objectName, String query) {
        this.objectName = objectName;
        this.query = query;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {   
            List<InscipherTaxFilingServiceWrapper> payloads = new List<InscipherTaxFilingServiceWrapper>();
            List<Inscipher_Tax_Filling_Log__c> inscipherLogs = new  List<Inscipher_Tax_Filling_Log__c>();
            
            // get physical address related to Agency / Producer
            Map<Id, Account> accountMap = getAgencyProducerAddress(objectName, scope);
    
            // get quotelineitems for policy / endorsement
            Map<Id, List<QuoteLineItem>> quoteLineItemMap  = getQuoteLineItems(objectName, scope);
    
            String policyId;
            String endorsementId;
            
            if(objectName == 'InsurancePolicy'){
                for(InsurancePolicy policy : (List<InsurancePolicy>) scope) {
                    if(policy.InvoiceIntakeForms__r.size() == 0){ continue; }
                    
                    policyId = '';
                    policyId = policy.Id;                
                    InscipherTaxFilingServiceWrapper wrapper = new InscipherTaxFilingServiceWrapper();
                    wrapper.Id = policyId;
                    wrapper.policy_number = policy.Name != null ? policy.Name : '';  
                    wrapper.policy_effective_date = policy.EffectiveDate__c != null ? String.valueOf(policy.EffectiveDate__c) : '';
                    wrapper.policy_expiration_date = policy.ExpirationDate__c != null ? String.valueOf(policy.ExpirationDate__c) : '';
                    wrapper.transaction_effective_date = policy.EffectiveDate__c != null ? String.valueOf(policy.EffectiveDate__c) : '';
                    wrapper.business_group_id = policy.ServicingOne80Branch__c != null ? String.valueOf(policy.ServicingOne80Branch__c) : '';
                    wrapper.insured_entity = policy.NameInsured != null && policy.NameInsured.Type != null ? policy.NameInsured.Type : '';
                    wrapper.retail_agency_license = policy.Tax_State__c != null ? policy.Tax_State__c  : ''; 
                    wrapper.transaction_type = policy.IsRenewedPolicy ? 'Renewal' : 'New business';
                    wrapper.policy_type = 'standard';
                    wrapper.transaction_line_of_business = null;
    
                    if(policy.IsRenewedPolicy){
                        wrapper.expiring_policy_number = policy.Quote__r.ExpiringPolicy__c;
                    }
    
                    for(InvoiceDataForm__c idf: policy.InvoiceIntakeForms__r){
                        if (policy.Tax_State__c == 'GA' || policy.Tax_State__c == 'HI' || policy.Tax_State__c == 'Idaho') {
                            wrapper.invoice_date = String.valueOf(idf.InvoiceDate__c); 
                        } else if (policy.Tax_State__c == null) {
                            wrapper.invoice_date = policy.EffectiveDate__c != null ? String.valueOf(policy.EffectiveDate__c) : '';
                        } 
                        wrapper.invoice_number = idf.Invoice__c;
                    }
                    
                    if (policy.Agency__c != null && accountMap.containsKey(policy.Agency__c)) { 
                        wrapper.physical_same_as_mailing = policy.Agency__r.PhysicalAddressSameAsMailingAddress__c ? 1 : 0;
    
                        Account agencyAccount = accountMap.get(policy.Agency__c);
                        if(agencyAccount.Addresses__r != null && !agencyAccount.Addresses__r.isEmpty()){
                            String physicalAddress = agencyAccount.Addresses__r[0].Address__c;
                            wrapper.physical_address = physicalAddress;
                            wrapper.physical_address2 = physicalAddress;
                            wrapper.physical_city = agencyAccount.Addresses__r[0].City;
                            wrapper.physical_state_code = agencyAccount.Addresses__r[0].StateCode;  
                            wrapper.physical_zip_code = agencyAccount.Addresses__r[0].PostalCode;
                        }
                    }
    
                    if (policy.Producer.AccountId != null && accountMap.containsKey(policy.Producer.AccountId)) { 
                        Account producerAccount = accountMap.get(policy.Producer.AccountId);
                        if(producerAccount.Addresses__r != null && !producerAccount.Addresses__r.isEmpty()){
                            String physicalAddress = producerAccount.Addresses__r != null ? producerAccount.Addresses__r[0].Address__c : '';
                            wrapper.retail_address = physicalAddress;
                            wrapper.retail_address2 = physicalAddress;
                            wrapper.retail_city = producerAccount.Addresses__r[0].City;
                            wrapper.retail_state = producerAccount.Addresses__r[0].StateCode;
                            wrapper.retail_zip = producerAccount.Addresses__r[0].PostalCode;
                        }
                        wrapper.retail_producer_name = producerAccount.Name != null ? producerAccount.Name : '';
                        wrapper.retail_agency_name = producerAccount.Name != null ? producerAccount.Name : '';
                        wrapper.retail_phone_number = producerAccount.Phone != null ? producerAccount.Phone : '';
                        wrapper.retail_email_address = producerAccount.EmailAddress__c != null ? producerAccount.EmailAddress__c : '';
                    }
    
                    if (policy.Quote__c != null && quoteLineItemMap.containsKey(policy.Quote__c)) {
                        Map<String, String> lobData = getLOBListAndCoverage(quoteLineItemMap.get(policy.Quote__c));
                        wrapper.transaction_line_of_business_list = lobData.get('lobList');
                        wrapper.transaction_line_of_business_coverage = lobData.get('lobCoverage');
                    }
    				wrapper.account_written_as = 'B';
                    wrapper.rpg = 0;
                    payloads.add(wrapper);
                    inscipherLogs.add(new Inscipher_Tax_Filling_Log__c(Insurance_Policy__c = policyId, Inscipher_Request__c = JSON.serialize(wrapper), Type__c = 'Tax Filling API'));
                }
            }
            else if(objectName == 'Endorsement__c'){
                for(Endorsement__c endorsement : (List<Endorsement__c>) scope) {
                    if(endorsement.InvoiceDataFormsEndorsement__r.size() == 0){ continue; }
                        
                    policyId = '';
                    endorsementId = endorsement.Id;
                    
                    InscipherTaxFilingServiceWrapper wrapper = new InscipherTaxFilingServiceWrapper();
                    wrapper.Id = endorsementId;
                    wrapper.policy_number = endorsement.InsurancePolicy__r.Name != null ? endorsement.InsurancePolicy__r.Name : '';
                    wrapper.policy_effective_date = endorsement.InsurancePolicy__r.EffectiveDate__c != null ? String.valueOf(endorsement.InsurancePolicy__r.EffectiveDate__c) : '';
                    wrapper.policy_expiration_date = endorsement.InsurancePolicy__r.ExpirationDate__c != null ? String.valueOf(endorsement.InsurancePolicy__r.ExpirationDate__c) : '';
                    wrapper.policy_type = 'standard';
                    wrapper.transaction_effective_date = endorsement.EffectiveDate__c != null ? String.valueOf(endorsement.EffectiveDate__c)  : '';
                    wrapper.business_group_id = endorsement.InsurancePolicy__r.ServicingOne80Branch__c != null ? String.valueOf(endorsement.InsurancePolicy__r.ServicingOne80Branch__c) : '';
                    wrapper.insured_entity = endorsement.InsurancePolicy__r.NameInsured != null && endorsement.InsurancePolicy__r.NameInsured.Type != null ? endorsement.InsurancePolicy__r.NameInsured.Type : '';
                    wrapper.transaction_type = endorsement.Type__c != null ? endorsement.Type__c : '';
                    wrapper.transaction_line_of_business = null;
                    wrapper.retail_agency_license = endorsement.InsurancePolicy__r.Tax_State__c != null ? endorsement.InsurancePolicy__r.Tax_State__c  : ''; 
                    
                    if(endorsement.InsurancePolicy__r.IsRenewedPolicy){
                        wrapper.expiring_policy_number = endorsement.Quote__r.ExpiringPolicy__c;
                    }
                    
                    for(InvoiceDataForm__c idf: endorsement.InvoiceDataFormsEndorsement__r){
                        if (endorsement.InsurancePolicy__r.Tax_State__c == 'GA' || endorsement.InsurancePolicy__r.Tax_State__c == 'HI' || endorsement.InsurancePolicy__r.Tax_State__c == 'Idaho') {
                            wrapper.invoice_date = String.valueOf(idf.InvoiceDate__c); 
                        } else if (endorsement.InsurancePolicy__r.Tax_State__c == null) {
                            wrapper.invoice_date = endorsement.InsurancePolicy__r.EffectiveDate__c != null ? String.valueOf(endorsement.InsurancePolicy__r.EffectiveDate__c) : '';
                        } 
                        wrapper.invoice_number = idf.Invoice__c;
                    }
                    
                    if (endorsement.InsurancePolicy__r.Agency__c != null && accountMap.containsKey(endorsement.InsurancePolicy__r.Agency__c)) { 
                        wrapper.physical_same_as_mailing = endorsement.InsurancePolicy__r.Agency__r.PhysicalAddressSameAsMailingAddress__c ? 1 : 0;
                        Account agencyAccount = accountMap.get(endorsement.InsurancePolicy__r.Agency__c);
                        if(agencyAccount.Addresses__r != null && !agencyAccount.Addresses__r.isEmpty()){
                            String physicalAddress = agencyAccount.Addresses__r[0].Address__c;
                            wrapper.physical_address = physicalAddress;
                            wrapper.physical_address2 = physicalAddress;
                            wrapper.physical_city = agencyAccount.Addresses__r[0].City;
                            wrapper.physical_state_code = agencyAccount.Addresses__r[0].StateCode;
                            wrapper.physical_zip_code = agencyAccount.Addresses__r[0].PostalCode;
                        }
                    }
                    
                    if (endorsement.InsurancePolicy__r.Producer.AccountId != null && accountMap.containsKey(endorsement.InsurancePolicy__r.Producer.AccountId)) { 
                        Account producerAccount = accountMap.get(endorsement.InsurancePolicy__r.Producer.AccountId);
                        if(producerAccount.Addresses__r != null && !producerAccount.Addresses__r.isEmpty()){
                            String physicalAddress = producerAccount.Addresses__r != null ? producerAccount.Addresses__r[0].Address__c : '';
                            wrapper.retail_address = physicalAddress;
                            wrapper.retail_address2 = physicalAddress;
                            wrapper.retail_city = producerAccount.Addresses__r[0].City;
                            wrapper.retail_state = producerAccount.Addresses__r[0].StateCode;
                            wrapper.retail_zip = producerAccount.Addresses__r[0].PostalCode;
                        }
                        wrapper.retail_producer_name = producerAccount.Name != null ? producerAccount.Name : '';
                        wrapper.retail_agency_name = producerAccount.Name != null ? producerAccount.Name : '';
                        wrapper.retail_phone_number = producerAccount.Phone != null ? producerAccount.Phone : '';
                        wrapper.retail_email_address = producerAccount.EmailAddress__c != null ? producerAccount.EmailAddress__c : '';
                    }
                    
                    if (endorsement.InsurancePolicy__r.Quote__c != null && quoteLineItemMap.containsKey(endorsement.InsurancePolicy__r.Quote__c)) {
                        Map<String, String> lobData = getLOBListAndCoverage(quoteLineItemMap.get(endorsement.InsurancePolicy__r.Quote__c));
                        wrapper.transaction_line_of_business_list = lobData.get('lobList');
                        wrapper.transaction_line_of_business_coverage = lobData.get('lobCoverage');
                    }
                    wrapper.account_written_as = 'B';
                    wrapper.rpg = 0;
                    payloads.add(wrapper); 
                    inscipherLogs.add(new Inscipher_Tax_Filling_Log__c(Endorsement__c = endorsementId, Inscipher_Request__c = JSON.serialize(wrapper), Type__c = 'Tax Filling API'));
                }
            }
         
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:InscipherTaxFilling');
            request.setMethod('POST');
            request.setHeader('content-type', 'application/json');
            request.setHeader('apiKey', System.Label.Incipher_Auth_Key);
            request.setBody(JSON.serialize(payloads));
            
			System.debug('Request ==> ' + JSON.serialize(payloads));
            HttpResponse response = http.send(request);
	
            if (response.getStatusCode() == 200) {
				Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                system.debug('success response ==> '+ responseMap);
                
                processTaxFillingResponse(responseMap, inscipherLogs);
            } else {
                System.debug('Failed to send data. Response: ' + response.getBody());
            }
        } catch (Exception ex) {
            System.debug('Error during callout: ' + ex.getMessage() + 'Stack trace: ' + ex.getStackTraceString());
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug('Batch process completed.');
    }

    public void execute(SchedulableContext sc) {	
        String insurnacePolicyQuery =   'SELECT Id, Name, Inscipher_Batch_Id__c, Agency__r.Name, Producer.AccountId, EffectiveDate__c, Tax_State__c,ServicingOne80Branch__c, IsRenewedPolicy, Agency__c, NameInsured.Type, ExpirationDate__c, Quote__c, Quote__r.ExpiringPolicy__c, Agency__r.PhysicalAddressSameAsMailingAddress__c,' +
            '(SELECT Id, Status__c, InvoiceDate__c, Invoice__c FROM InvoiceIntakeForms__r WHERE Status__c = \'Invoiced\'), ' +
            '(SELECT Id, ExpiringPolicy__c FROM IncumbentQuotes__r), ' +
            '(SELECT Id, Amount__c, FeeType__c FROM TaxesAndFeesInsurancePolicy__r WHERE RecordType.DeveloperName = \'Fee\')' + 
            'FROM InsurancePolicy WHERE FilingParty__c = \'Inscipher\' AND EffectiveDate__c >= 2025-01-01 AND Submitted_to_Inscipher__c = false';
        
        Database.executeBatch(new InscipherTaxFillingServiceBatch('InsurancePolicy', insurnacePolicyQuery), 50);
        
        String endorsementQuery =   'SELECT Id, NamedInsured__c , EffectiveDate__c, Type__c,  Inscipher_Batch_Id__c,  WrittenPremium__c, InsurancePolicy__r.EffectiveDate__c, InsurancePolicy__r.Id, InsurancePolicy__r.Name, InsurancePolicy__r.Tax_State__c, InsurancePolicy__r.ServicingOne80Branch__c, ' +
            'InsurancePolicy__r.IsRenewedPolicy, InsurancePolicy__r.NameInsured.Type, InsurancePolicy__r.ExpirationDate__c, InsurancePolicy__r.Quote__c, Quote__r.ExpiringPolicy__c, InsurancePolicy__r.Agency__c, InsurancePolicy__r.Agency__r.PhysicalAddressSameAsMailingAddress__c, ' +
            'Quote__r.Id, InsurancePolicy__r.Producer.AccountId, InsurancePolicy__r.LineOfBusiness__r.Incipher_Gen_Code__c,' +
            '(SELECT Id, Status__c, InvoiceDate__c, Invoice__c FROM InvoiceDataFormsEndorsement__r WHERE Status__c = \'Invoiced\'), ' +
            '(SELECT Id, Amount__c, FeeType__c FROM TaxesAndFeesEndorsement__r WHERE RecordType.DeveloperName = \'Fee\') ' +
            'FROM Endorsement__c WHERE InsurancePolicy__r.FilingParty__c = \'Inscipher\' AND Submitted_to_Inscipher__c = false AND EffectiveDate__c >= 2025-01-01';
        
        Database.executeBatch(new InscipherTaxFillingServiceBatch('Endorsement__c', endorsementQuery), 50);
    }

	private static Map<String, String> getLOBListAndCoverage(List<QuoteLineItem> quoteLineItems){
        String lobList = '';
        String lobCoverage = '';
        for(QuoteLineItem quoteLine : quoteLineItems){
            
            if(quoteLine.LineOfBusiness__c != null && quoteLine.LineOfBusiness__r.Incipher_Gen_Code__c != null){
                lobList += quoteLine.LineOfBusiness__r.Incipher_Gen_Code__c +'|';
            }
            
            lobCoverage = quoteLine.CalculatedPremium__c +'|';
        }
        
        if(lobList.endsWith('|')){
            lobList = lobList.substring(0, lobList.length() - 1);
        }
        if(lobCoverage.endsWith('|')){
            lobCoverage = lobCoverage.substring(0, lobCoverage.length() - 1);
        }
        
        return new Map<String, String>{
            'lobList' => lobList,
                'lobCoverage' => lobCoverage
        };
    }

	private static Map<Id, Account> getAgencyProducerAddress(String objectName, List<SObject> scope){
        Set<Id> accountIds = new Set<Id>();
        
        if(objectName == 'InsurancePolicy'){
            for (InsurancePolicy policy : (List<InsurancePolicy>) scope) {
                if (policy.Agency__c != null) {
                    accountIds.add(policy.Agency__c);
                }
                if(policy.Producer.AccountId != null){
                    accountIds.add(policy.Producer.AccountId);
                }
            }
        }else{
            for (Endorsement__c endorsement : (List<Endorsement__c>) scope) {
                if (endorsement.InsurancePolicy__r.Agency__c != null) {
                    accountIds.add(endorsement.InsurancePolicy__r.Agency__c);
                }
                if(endorsement.InsurancePolicy__r.Producer.AccountId != null){
                    accountIds.add(endorsement.InsurancePolicy__r.Producer.AccountId);
                }
            }
        }
        
        if(accountIds.isEmpty()){ return new Map<Id, Account>();}
        
        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, 
             Name, 
             Phone, 
             EmailAddress__c,
             (SELECT Id, AddressType, Address__c, Street, City, PostalCode, StateCode FROM Addresses__r WHERE AddressType = 'Physical')
             FROM Account 
             WHERE Id IN :accountIds]
        );
        
        return accountMap;
	}

	private static Map<Id, List<QuoteLineItem>> getQuoteLineItems(String objectName, List<Sobject> scope){
		Set<Id> quoteIds = new Set<Id>();
		Map<Id, List<QuoteLineItem>> quoteLineItemMap = new Map<Id, List<QuoteLineItem>>();

        if(objectName == 'InsurancePolicy'){
            for (InsurancePolicy policy : (List<InsurancePolicy>) scope) {
                if (policy.Quote__c != null) {
                    quoteIds.add(policy.Quote__c);
                }
            }
        }else{
            for (Endorsement__c endorsement : (List<Endorsement__c>) scope) {
                if (endorsement.InsurancePolicy__r.Quote__c != null) {
                    quoteIds.add(endorsement.InsurancePolicy__r.Quote__c);
                }
            }
        }

		if (!quoteIds.isEmpty()) {
			for (QuoteLineItem qli : [
					SELECT Id, LineOfBusiness__c, CalculatedPremium__c, LineOfBusiness__r.Incipher_Gen_Code__c, QuoteId
					FROM QuoteLineItem
					WHERE QuoteId IN :quoteIds
			]) {
				if (!quoteLineItemMap.containsKey(qli.QuoteId)) {
					quoteLineItemMap.put(qli.QuoteId, new List<QuoteLineItem>());
				}
				quoteLineItemMap.get(qli.QuoteId).add(qli);
			}
		}
		return quoteLineItemMap;
	}

	public static void processTaxFillingResponse(Map<String, Object> responseMap, List<Inscipher_Tax_Filling_Log__c> inscipherLogs){
        try{
            List<sObject> listOfSobjectToUpdate = new List<sObject>();
            String batchId = (String) responseMap.get('batch_id');
            List<Object> transactions = (List<Object>) responseMap.get('transactions');
    
            for(Object transactionObj : transactions){
                Map<String, Object> fetchedData = (Map<String, Object>) transactionObj;
                String resId = (String) fetchedData.get('id');
				String fillingStatus = (String) fetchedData.get('status_message');
                String objectName = Id.valueOf(resId)?.getSObjectType()?.getDescribe()?.getName();
                SObjectType objType = Schema.getGlobalDescribe().get(objectName);

                SObject objToUpdate = objType.newSObject(resId);
                objToUpdate.put('Submitted_to_Inscipher__c', true);
                objToUpdate.put('Date_Submitted__c', System.today());
                objToUpdate.put('Submitted_by__c', UserInfo.getUserId());
                objToUpdate.put('Inscipher_Batch_Id__c', batchId);
                objToUpdate.put('Filing_Status__c', fillingStatus);

                listOfSobjectToUpdate.add(objToUpdate);
            }
    
            if(!listOfSobjectToUpdate.isEmpty()){
                update listOfSobjectToUpdate;
            }
            
			if(!inscipherLogs.isEmpty()){
                insert inscipherLogs;   
            }
            
        } catch (Exception e) {
            System.debug('Error in processTaxFillingResponse: ' + e.getMessage() + 'Stack trace: ' + e.getStackTraceString());
            throw e;
        }
	}
}